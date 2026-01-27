using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using PCM_Backend.Data;
using PCM_Backend.Hubs;
using PCM_Backend.Models;

namespace PCM_Backend.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class MatchesController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IHubContext<PcmHub> _hubContext;

        public MatchesController(ApplicationDbContext context, IHubContext<PcmHub> hubContext)
        {
            _context = context;
            _hubContext = hubContext;
        }

        [HttpGet]
        public async Task<IActionResult> GetMatches([FromQuery] int? tournamentId = null)
        {
            var query = _context.Matches.AsQueryable();
            
            if (tournamentId.HasValue)
            {
                query = query.Where(m => m.TournamentId == tournamentId);
            }
            
            return Ok(await query.OrderByDescending(m => m.Date).Take(50).ToListAsync());
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetMatch(int id)
        {
            var match = await _context.Matches
                .Include(m => m.Tournament)
                .FirstOrDefaultAsync(m => m.Id == id);
                
            if (match == null) return NotFound("Match not found");

            // Get player names
            var playerIds = new[] { match.Team1_Player1Id, match.Team1_Player2Id, match.Team2_Player1Id, match.Team2_Player2Id }
                .Where(id => id.HasValue)
                .Select(id => id!.Value)
                .ToList();

            var players = await _context.Members
                .Where(m => playerIds.Contains(m.Id))
                .ToDictionaryAsync(m => m.Id, m => m.FullName);

            return Ok(new
            {
                Match = match,
                Players = players
            });
        }

        [HttpPost("{id}/result")]
        [Authorize(Roles = "Admin,Referee")]
        public async Task<IActionResult> UpdateResult(int id, [FromBody] MatchResultRequest request)
        {
            var match = await _context.Matches.FindAsync(id);
            if (match == null) return NotFound("Match not found");

            if (match.Status == MatchStatus.Finished)
                return BadRequest("Match already finished");

            match.Score1 = request.Score1;
            match.Score2 = request.Score2;
            match.Details = request.Details;
            match.WinningSide = request.Score1 > request.Score2 ? MatchWinningSide.Team1 : MatchWinningSide.Team2;
            match.Status = MatchStatus.Finished;

            // Update Rank DUPR if ranked match
            if (match.IsRanked)
            {
                var winnerIds = match.WinningSide == MatchWinningSide.Team1
                    ? new[] { match.Team1_Player1Id, match.Team1_Player2Id }
                    : new[] { match.Team2_Player1Id, match.Team2_Player2Id };

                var loserIds = match.WinningSide == MatchWinningSide.Team1
                    ? new[] { match.Team2_Player1Id, match.Team2_Player2Id }
                    : new[] { match.Team1_Player1Id, match.Team1_Player2Id };

                foreach (var winnerId in winnerIds.Where(id => id.HasValue))
                {
                    var winner = await _context.Members.FindAsync(winnerId);
                    if (winner != null) winner.RankLevel += 0.1;
                }

                foreach (var loserId in loserIds.Where(id => id.HasValue))
                {
                    var loser = await _context.Members.FindAsync(loserId);
                    if (loser != null) loser.RankLevel = Math.Max(1.0, loser.RankLevel - 0.05);
                }
            }

            // Check if tournament is finished
            if (match.TournamentId.HasValue)
            {
                var pendingMatches = await _context.Matches
                    .CountAsync(m => m.TournamentId == match.TournamentId && m.Status != MatchStatus.Finished);

                if (pendingMatches <= 1) // This was the last match
                {
                    var tournament = await _context.Tournaments.FindAsync(match.TournamentId);
                    if (tournament != null)
                    {
                        tournament.Status = TournamentStatus.Finished;

                        // Award prize to winner
                        var winnerId = match.WinningSide == MatchWinningSide.Team1 ? match.Team1_Player1Id : match.Team2_Player1Id;
                        if (winnerId.HasValue && tournament.PrizePool > 0)
                        {
                            var winner = await _context.Members.FindAsync(winnerId);
                            if (winner != null)
                            {
                                winner.WalletBalance += tournament.PrizePool;
                                _context.WalletTransactions.Add(new WalletTransaction
                                {
                                    MemberId = winner.Id,
                                    Amount = tournament.PrizePool,
                                    Type = TransactionType.Reward,
                                    Status = TransactionStatus.Completed,
                                    RelatedId = tournament.Id.ToString(),
                                    Description = $"Prize for winning {tournament.Name}",
                                    CreatedDate = DateTime.UtcNow
                                });
                            }
                        }
                    }
                }
            }

            await _context.SaveChangesAsync();

            // Notify via SignalR
            await _hubContext.Clients.All.SendAsync("UpdateMatchScore", new
            {
                MatchId = id,
                match.Score1,
                match.Score2,
                match.WinningSide
            });

            return Ok(match);
        }

        [HttpPost("{id}/start")]
        [Authorize(Roles = "Admin,Referee")]
        public async Task<IActionResult> StartMatch(int id)
        {
            var match = await _context.Matches.FindAsync(id);
            if (match == null) return NotFound("Match not found");

            match.Status = MatchStatus.InProgress;
            await _context.SaveChangesAsync();

            return Ok(match);
        }
    }

    public class MatchResultRequest
    {
        public int Score1 { get; set; }
        public int Score2 { get; set; }
        public string? Details { get; set; }
    }
}
