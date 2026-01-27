using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PCM_Backend.Data;
using PCM_Backend.Models;
using System.Security.Claims;

namespace PCM_Backend.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class TournamentsController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public TournamentsController(ApplicationDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> GetTournaments([FromQuery] string? status = null)
        {
            var query = _context.Tournaments.AsQueryable();
            
            if (!string.IsNullOrEmpty(status) && Enum.TryParse<TournamentStatus>(status, true, out var statusEnum))
            {
                query = query.Where(t => t.Status == statusEnum);
            }
            
            return Ok(await query.OrderByDescending(t => t.StartDate).ToListAsync());
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetTournament(int id)
        {
            var tournament = await _context.Tournaments.FindAsync(id);
            if (tournament == null) return NotFound("Tournament not found");

            var participants = await _context.TournamentParticipants
                .Include(p => p.Member)
                .Where(p => p.TournamentId == id)
                .Select(p => new
                {
                    p.Id,
                    p.MemberId,
                    MemberName = p.Member!.FullName,
                    p.TeamName,
                    p.PaymentStatus
                })
                .ToListAsync();

            var matches = await _context.Matches
                .Where(m => m.TournamentId == id)
                .OrderBy(m => m.RoundName)
                .ThenBy(m => m.Date)
                .ToListAsync();

            return Ok(new
            {
                Tournament = tournament,
                Participants = participants,
                Matches = matches
            });
        }

        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> CreateTournament([FromBody] CreateTournamentRequest request)
        {
            var tournament = new Tournament
            {
                Name = request.Name,
                StartDate = request.StartDate,
                EndDate = request.EndDate,
                Format = request.Format,
                EntryFee = request.EntryFee,
                PrizePool = request.PrizePool,
                Status = TournamentStatus.Registering,
                Settings = request.Settings
            };

            _context.Tournaments.Add(tournament);
            await _context.SaveChangesAsync();

            return Ok(tournament);
        }

        [HttpPost("{id}/join")]
        public async Task<IActionResult> JoinTournament(int id, [FromBody] JoinRequest request)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var member = await _context.Members.FirstOrDefaultAsync(m => m.UserId == userId);
            if (member == null) return NotFound("Member not found");

            var tournament = await _context.Tournaments.FindAsync(id);
            if (tournament == null) return NotFound("Tournament not found");

            if (tournament.Status != TournamentStatus.Registering && tournament.Status != TournamentStatus.Open)
                return BadRequest("Tournament not open for registration");

            // Check if already registered
            var existing = await _context.TournamentParticipants
                .AnyAsync(p => p.TournamentId == id && p.MemberId == member.Id);
            if (existing) return BadRequest("Already registered");

            if (member.WalletBalance < tournament.EntryFee)
                return BadRequest("Insufficient balance");

            // Deduct Fee
            member.WalletBalance -= tournament.EntryFee;
            member.TotalSpent += tournament.EntryFee;
            
            var transaction = new WalletTransaction
            {
                MemberId = member.Id,
                Amount = -tournament.EntryFee,
                Type = TransactionType.Payment,
                Status = TransactionStatus.Completed,
                RelatedId = tournament.Id.ToString(),
                Description = $"Join Tournament {tournament.Name}",
                CreatedDate = DateTime.UtcNow
            };

            var participant = new TournamentParticipant
            {
                TournamentId = id,
                MemberId = member.Id,
                TeamName = request.TeamName,
                PaymentStatus = true
            };

            _context.WalletTransactions.Add(transaction);
            _context.TournamentParticipants.Add(participant);
            await _context.SaveChangesAsync();

            return Ok(participant);
        }

        [HttpPost("{id}/generate-schedule")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GenerateSchedule(int id)
        {
            var tournament = await _context.Tournaments.FindAsync(id);
            if (tournament == null) return NotFound("Tournament not found");

            var participants = await _context.TournamentParticipants
                .Where(p => p.TournamentId == id && p.PaymentStatus)
                .Include(p => p.Member)
                .ToListAsync();

            if (participants.Count < 2) return BadRequest("Need at least 2 participants");

            // Clear existing matches
            var existingMatches = await _context.Matches.Where(m => m.TournamentId == id).ToListAsync();
            _context.Matches.RemoveRange(existingMatches);

            var matches = new List<Match>();
            var random = new Random();
            var shuffled = participants.OrderBy(_ => random.Next()).ToList();

            if (tournament.Format == TournamentFormat.RoundRobin)
            {
                // Round Robin: Everyone plays everyone
                for (int i = 0; i < shuffled.Count; i++)
                {
                    for (int j = i + 1; j < shuffled.Count; j++)
                    {
                        matches.Add(new Match
                        {
                            TournamentId = id,
                            RoundName = "Group Stage",
                            Date = tournament.StartDate.AddDays(matches.Count / 4),
                            StartTime = TimeSpan.FromHours(9 + (matches.Count % 8)),
                            Team1_Player1Id = shuffled[i].MemberId,
                            Team2_Player1Id = shuffled[j].MemberId,
                            Status = MatchStatus.Scheduled,
                            IsRanked = true
                        });
                    }
                }
            }
            else // Knockout
            {
                // Knockout: Single elimination bracket
                int round = 1;
                var roundName = shuffled.Count <= 2 ? "Final" :
                               shuffled.Count <= 4 ? "Semi Final" :
                               shuffled.Count <= 8 ? "Quarter Final" : $"Round {round}";

                for (int i = 0; i < shuffled.Count - 1; i += 2)
                {
                    matches.Add(new Match
                    {
                        TournamentId = id,
                        RoundName = roundName,
                        Date = tournament.StartDate,
                        StartTime = TimeSpan.FromHours(9 + i),
                        Team1_Player1Id = shuffled[i].MemberId,
                        Team2_Player1Id = i + 1 < shuffled.Count ? shuffled[i + 1].MemberId : null,
                        Status = MatchStatus.Scheduled,
                        IsRanked = true
                    });
                }
            }

            tournament.Status = TournamentStatus.DrawCompleted;
            _context.Matches.AddRange(matches);
            await _context.SaveChangesAsync();

            return Ok(new { Message = "Schedule generated", MatchCount = matches.Count });
        }
    }

    public class CreateTournamentRequest
    {
        public string Name { get; set; } = string.Empty;
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public TournamentFormat Format { get; set; }
        public decimal EntryFee { get; set; }
        public decimal PrizePool { get; set; }
        public string? Settings { get; set; }
    }

    public class JoinRequest
    {
        public string? TeamName { get; set; }
    }
}

