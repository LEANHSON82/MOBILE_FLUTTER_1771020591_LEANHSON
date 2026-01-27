using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PCM_Backend.Data;
using PCM_Backend.Models;

namespace PCM_Backend.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class MembersController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public MembersController(ApplicationDbContext context)
        {
            _context = context;
        }

        /// <summary>
        /// Get all members with optional search and pagination
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetMembers(
            [FromQuery] string? search = null,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20)
        {
            var query = _context.Members.AsQueryable();

            if (!string.IsNullOrEmpty(search))
            {
                query = query.Where(m => m.FullName.Contains(search));
            }

            var total = await query.CountAsync();
            var members = await query
                .OrderByDescending(m => m.RankLevel)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(m => new
                {
                    m.Id,
                    m.FullName,
                    m.RankLevel,
                    m.Tier,
                    m.AvatarUrl,
                    m.IsActive,
                    m.JoinDate
                })
                .ToListAsync();

            return Ok(new
            {
                Data = members,
                Total = total,
                Page = page,
                PageSize = pageSize,
                TotalPages = (int)Math.Ceiling((double)total / pageSize)
            });
        }

        /// <summary>
        /// Get member profile with match history
        /// </summary>
        [HttpGet("{id}/profile")]
        public async Task<IActionResult> GetMemberProfile(int id)
        {
            var member = await _context.Members
                .Where(m => m.Id == id)
                .Select(m => new
                {
                    m.Id,
                    m.FullName,
                    m.RankLevel,
                    m.Tier,
                    m.WalletBalance,
                    m.TotalSpent,
                    m.AvatarUrl,
                    m.IsActive,
                    m.JoinDate
                })
                .FirstOrDefaultAsync();

            if (member == null) return NotFound("Member not found");

            // Get match history
            var matches = await _context.Matches
                .Where(m => m.Team1_Player1Id == id || m.Team1_Player2Id == id ||
                           m.Team2_Player1Id == id || m.Team2_Player2Id == id)
                .OrderByDescending(m => m.Date)
                .Take(10)
                .Select(m => new
                {
                    m.Id,
                    m.TournamentId,
                    m.RoundName,
                    m.Date,
                    m.Score1,
                    m.Score2,
                    m.WinningSide,
                    m.Status
                })
                .ToListAsync();

            // Get recent bookings
            var bookings = await _context.Bookings
                .Include(b => b.Court)
                .Where(b => b.MemberId == id)
                .OrderByDescending(b => b.StartTime)
                .Take(5)
                .Select(b => new
                {
                    b.Id,
                    CourtName = b.Court!.Name,
                    b.StartTime,
                    b.EndTime,
                    b.Status
                })
                .ToListAsync();

            return Ok(new
            {
                Member = member,
                RecentMatches = matches,
                RecentBookings = bookings
            });
        }
    }
}
