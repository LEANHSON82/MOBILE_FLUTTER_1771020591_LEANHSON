using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using PCM_Backend.Data;
using PCM_Backend.Hubs;
using PCM_Backend.Models;
using System.Security.Claims;

namespace PCM_Backend.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class ChatController(ApplicationDbContext context, IHubContext<PcmHub> hubContext) : ControllerBase
    {
        private readonly ApplicationDbContext _context = context;
        private readonly IHubContext<PcmHub> _hubContext = hubContext;

        // GET: api/chat/tournament/{tournamentId} - Lấy lịch sử chat giải đấu
        [HttpGet("tournament/{tournamentId}")]
        public async Task<IActionResult> GetTournamentMessages(int tournamentId, int take = 50)
        {
            var messages = await _context.ChatMessages
                .Where(m => m.TournamentId == tournamentId)
                .OrderByDescending(m => m.CreatedDate)
                .Take(take)
                .Select(m => new
                {
                    m.Id,
                    m.SenderName,
                    m.Message,
                    Timestamp = m.CreatedDate.ToString("HH:mm"),
                    m.TournamentId,
                    m.CreatedDate
                })
                .ToListAsync();

            return Ok(messages.OrderBy(m => m.CreatedDate));
        }

        // POST: api/chat/tournament/{tournamentId} - Gửi tin nhắn vào giải đấu
        [HttpPost("tournament/{tournamentId}")]
        public async Task<IActionResult> SendTournamentMessage(int tournamentId, [FromBody] SendMessageRequest request)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var member = await _context.Members.FirstOrDefaultAsync(m => m.UserId == userId);
            if (member == null) return NotFound("Member not found");

            var message = new ChatMessage
            {
                TournamentId = tournamentId,
                SenderId = member.Id,
                SenderName = member.FullName,
                Message = request.Message,
                CreatedDate = DateTime.UtcNow
            };

            _context.ChatMessages.Add(message);
            await _context.SaveChangesAsync();

            // Broadcast qua SignalR
            await _hubContext.Clients.Group($"TournamentChat_{tournamentId}").SendAsync(
                "ReceiveChatMessage",
                new
                {
                    Username = member.FullName,
                    Message = request.Message,
                    Timestamp = message.CreatedDate.ToString("HH:mm"),
                    TournamentId = tournamentId
                }
            );

            return Ok(message);
        }

        // GET: api/chat/duel/{duelId} - Lấy lịch sử chat thách đấu
        [HttpGet("duel/{duelId}")]
        public async Task<IActionResult> GetDuelMessages(int duelId, int take = 50)
        {
            var messages = await _context.ChatMessages
                .Where(m => m.DuelId == duelId)
                .OrderByDescending(m => m.CreatedDate)
                .Take(take)
                .Select(m => new
                {
                    m.Id,
                    m.SenderName,
                    m.Message,
                    Timestamp = m.CreatedDate.ToString("HH:mm"),
                    m.DuelId,
                    m.CreatedDate
                })
                .ToListAsync();

            return Ok(messages.OrderBy(m => m.CreatedDate));
        }

        // POST: api/chat/duel/{duelId} - Gửi tin nhắn trong thách đấu
        [HttpPost("duel/{duelId}")]
        public async Task<IActionResult> SendDuelMessage(int duelId, [FromBody] SendMessageRequest request)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var member = await _context.Members.FirstOrDefaultAsync(m => m.UserId == userId);
            if (member == null) return NotFound("Member not found");

            var message = new ChatMessage
            {
                DuelId = duelId,
                SenderId = member.Id,
                SenderName = member.FullName,
                Message = request.Message,
                CreatedDate = DateTime.UtcNow
            };

            _context.ChatMessages.Add(message);
            await _context.SaveChangesAsync();

            // Broadcast qua SignalR
            await _hubContext.Clients.Group($"DuelChat_{duelId}").SendAsync(
                "ReceiveChatMessage",
                new
                {
                    Username = member.FullName,
                    Message = request.Message,
                    Timestamp = message.CreatedDate.ToString("HH:mm"),
                    DuelId = duelId
                }
            );

            return Ok(message);
        }
    }

    public class SendMessageRequest
    {
        public string Message { get; set; } = string.Empty;
    }
}
