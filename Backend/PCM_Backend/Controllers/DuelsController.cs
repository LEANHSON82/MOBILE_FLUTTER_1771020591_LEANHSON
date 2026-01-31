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
    public class DuelsController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IHubContext<PcmHub> _hubContext;

        public DuelsController(ApplicationDbContext context, IHubContext<PcmHub> hubContext)
        {
            _context = context;
            _hubContext = hubContext;
        }

        // GET: api/duels - Danh sách kèo đang mở
        [HttpGet]
        public async Task<IActionResult> GetOpenDuels()
        {
            var duels = await _context.Duels
                .Include(d => d.Challenger)
                .Where(d => d.Status == DuelStatus.Open)
                .OrderByDescending(d => d.CreatedDate)
                .Select(d => new
                {
                    d.Id,
                    d.ChallengerId,
                    ChallengerName = d.Challenger!.FullName,
                    ChallengerAvatar = d.Challenger.AvatarUrl,
                    ChallengerRank = d.Challenger.RankLevel,
                    d.ChallengerPartnerId,
                    d.BetAmount,
                    d.Type,
                    d.Status,
                    d.ScheduledTime,
                    d.Message,
                    d.CreatedDate
                })
                .ToListAsync();

            return Ok(duels);
        }

        // GET: api/duels/my - Kèo của tôi (đã tạo hoặc tham gia)
        [HttpGet("my")]
        public async Task<IActionResult> GetMyDuels()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var member = await _context.Members.FirstOrDefaultAsync(m => m.UserId == userId);
            if (member == null) return NotFound("Member not found");

            var duels = await _context.Duels
                .Include(d => d.Challenger)
                .Where(d => d.ChallengerId == member.Id || d.OpponentId == member.Id)
                .OrderByDescending(d => d.CreatedDate)
                .ToListAsync();

            // Load opponent names
            var result = new List<object>();
            foreach (var d in duels)
            {
                var opponent = d.OpponentId.HasValue 
                    ? await _context.Members.FindAsync(d.OpponentId.Value) 
                    : null;

                result.Add(new
                {
                    d.Id,
                    d.ChallengerId,
                    ChallengerName = d.Challenger?.FullName,
                    ChallengerAvatar = d.Challenger?.AvatarUrl,
                    d.OpponentId,
                    OpponentName = opponent?.FullName,
                    OpponentAvatar = opponent?.AvatarUrl,
                    d.BetAmount,
                    d.Type,
                    d.Status,
                    d.ScheduledTime,
                    d.WinningSide,
                    d.Result,
                    d.Message,
                    d.CreatedDate
                });
            }

            return Ok(result);
        }

        // POST: api/duels - Tạo kèo mới
        [HttpPost]
        public async Task<IActionResult> CreateDuel([FromBody] CreateDuelRequest request)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var member = await _context.Members.FirstOrDefaultAsync(m => m.UserId == userId);
            if (member == null) return NotFound("Member not found");

            // Kiểm tra số dư
            if (member.WalletBalance < request.BetAmount)
                return BadRequest("Số dư ví không đủ để đặt kèo");

            // Trừ tiền cược
            member.WalletBalance -= request.BetAmount;

            var duel = new Duel
            {
                ChallengerId = member.Id,
                ChallengerPartnerId = request.ChallengerPartnerId,
                BetAmount = request.BetAmount,
                Type = request.Type,
                Status = DuelStatus.Open,
                ScheduledTime = request.ScheduledTime,
                Message = request.Message,
                CreatedDate = DateTime.UtcNow
            };

            _context.Duels.Add(duel);

            // Ghi transaction
            _context.WalletTransactions.Add(new WalletTransaction
            {
                MemberId = member.Id,
                Amount = -request.BetAmount,
                Type = TransactionType.Payment,
                Status = TransactionStatus.Completed,
                RelatedId = $"Duel_{duel.Id}",
                Description = $"Đặt kèo thách đấu {request.BetAmount:N0}đ",
                CreatedDate = DateTime.UtcNow
            });

            await _context.SaveChangesAsync();

            return Ok(new { duel.Id, Message = "Tạo kèo thành công", NewBalance = member.WalletBalance });
        }

        // POST: api/duels/{id}/accept - Chấp nhận kèo
        [HttpPost("{id}/accept")]
        public async Task<IActionResult> AcceptDuel(int id)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var member = await _context.Members.FirstOrDefaultAsync(m => m.UserId == userId);
            if (member == null) return NotFound("Member not found");

            var duel = await _context.Duels.FindAsync(id);
            if (duel == null) return NotFound("Duel not found");

            if (duel.Status != DuelStatus.Open)
                return BadRequest("Kèo này không còn mở");

            if (duel.ChallengerId == member.Id)
                return BadRequest("Bạn không thể chấp nhận kèo của chính mình");

            // Kiểm tra số dư
            if (member.WalletBalance < duel.BetAmount)
                return BadRequest("Số dư ví không đủ để chấp nhận kèo");

            // Trừ tiền cược
            member.WalletBalance -= duel.BetAmount;
            duel.OpponentId = member.Id;
            duel.Status = DuelStatus.Accepted;

            // Ghi transaction
            _context.WalletTransactions.Add(new WalletTransaction
            {
                MemberId = member.Id,
                Amount = -duel.BetAmount,
                Type = TransactionType.Payment,
                Status = TransactionStatus.Completed,
                RelatedId = $"Duel_{duel.Id}",
                Description = $"Chấp nhận kèo thách đấu {duel.BetAmount:N0}đ",
                CreatedDate = DateTime.UtcNow
            });

            // Thông báo cho người tạo kèo
            var challenger = await _context.Members.FindAsync(duel.ChallengerId);
            if (challenger != null)
            {
                var noti = new Notification
                {
                    ReceiverId = challenger.Id,
                    Message = $"{member.FullName} đã chấp nhận kèo thách đấu {duel.BetAmount:N0}đ của bạn!",
                    Type = "Success",
                    IsRead = false,
                    CreatedDate = DateTime.UtcNow
                };
                _context.Notifications.Add(noti);
                await _hubContext.Clients.User(challenger.UserId).SendAsync("ReceiveNotification", noti.Message);
            }

            await _context.SaveChangesAsync();

            return Ok(new { Message = "Đã chấp nhận kèo", NewBalance = member.WalletBalance });
        }

        // POST: api/duels/{id}/cancel - Hủy kèo
        [HttpPost("{id}/cancel")]
        public async Task<IActionResult> CancelDuel(int id)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var member = await _context.Members.FirstOrDefaultAsync(m => m.UserId == userId);
            if (member == null) return NotFound("Member not found");

            var duel = await _context.Duels.FindAsync(id);
            if (duel == null) return NotFound("Duel not found");

            if (duel.ChallengerId != member.Id)
                return BadRequest("Chỉ người tạo kèo mới có thể hủy");

            if (duel.Status != DuelStatus.Open)
                return BadRequest("Chỉ có thể hủy kèo đang mở");

            // Hoàn tiền
            member.WalletBalance += duel.BetAmount;
            duel.Status = DuelStatus.Cancelled;

            // Ghi transaction
            _context.WalletTransactions.Add(new WalletTransaction
            {
                MemberId = member.Id,
                Amount = duel.BetAmount,
                Type = TransactionType.Refund,
                Status = TransactionStatus.Completed,
                RelatedId = $"Duel_{duel.Id}",
                Description = $"Hoàn tiền hủy kèo thách đấu",
                CreatedDate = DateTime.UtcNow
            });

            await _context.SaveChangesAsync();

            return Ok(new { Message = "Đã hủy kèo và hoàn tiền", NewBalance = member.WalletBalance });
        }

        // POST: api/duels/{id}/result - Cập nhật kết quả (Admin/Referee)
        [HttpPost("{id}/result")]
        [Authorize(Roles = "Admin,Referee")]
        public async Task<IActionResult> UpdateResult(int id, [FromBody] DuelResultRequest request)
        {
            var duel = await _context.Duels.FindAsync(id);
            if (duel == null) return NotFound("Duel not found");

            if (duel.Status != DuelStatus.Accepted && duel.Status != DuelStatus.InProgress)
                return BadRequest("Kèo chưa được chấp nhận hoặc đã kết thúc");

            duel.Status = DuelStatus.Finished;
            duel.WinningSide = request.WinningSide;
            duel.Result = request.Result;

            // Chia thưởng: người thắng nhận tổng tiền cược (x2)
            var totalPrize = duel.BetAmount * 2;
            int winnerId = request.WinningSide == 1 ? duel.ChallengerId : (duel.OpponentId ?? 0);

            var winner = await _context.Members.FindAsync(winnerId);
            if (winner != null)
            {
                winner.WalletBalance += totalPrize;

                _context.WalletTransactions.Add(new WalletTransaction
                {
                    MemberId = winnerId,
                    Amount = totalPrize,
                    Type = TransactionType.Reward,
                    Status = TransactionStatus.Completed,
                    RelatedId = $"Duel_{duel.Id}",
                    Description = $"Thắng kèo thách đấu - Nhận {totalPrize:N0}đ",
                    CreatedDate = DateTime.UtcNow
                });

                // Thông báo
                var noti = new Notification
                {
                    ReceiverId = winnerId,
                    Message = $"Chúc mừng! Bạn đã thắng kèo thách đấu và nhận thưởng {totalPrize:N0}đ!",
                    Type = "Success",
                    IsRead = false,
                    CreatedDate = DateTime.UtcNow
                };
                _context.Notifications.Add(noti);
                await _hubContext.Clients.User(winner.UserId).SendAsync("ReceiveNotification", noti.Message);
            }

            await _context.SaveChangesAsync();

            return Ok(new { Message = "Đã cập nhật kết quả kèo", WinnerId = winnerId, Prize = totalPrize });
        }
    }

    public class CreateDuelRequest
    {
        public decimal BetAmount { get; set; }
        public DuelType Type { get; set; }
        public int? ChallengerPartnerId { get; set; }
        public DateTime? ScheduledTime { get; set; }
        public string? Message { get; set; }
    }

    public class DuelResultRequest
    {
        public int WinningSide { get; set; } // 1 = Challenger, 2 = Opponent
        public string? Result { get; set; }
    }
}
