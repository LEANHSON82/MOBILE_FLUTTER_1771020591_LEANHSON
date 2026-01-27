using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PCM_Backend.Data;
using PCM_Backend.Models;
using Microsoft.AspNetCore.SignalR;
using System.Security.Claims;

namespace PCM_Backend.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class WalletController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IHubContext<PCM_Backend.Hubs.PcmHub> _hubContext;

        public WalletController(ApplicationDbContext context, IHubContext<PCM_Backend.Hubs.PcmHub> hubContext)
        {
            _context = context;
            _hubContext = hubContext;
        }

        [HttpGet("transactions")]
        public async Task<IActionResult> GetTransactions()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var member = await _context.Members.FirstOrDefaultAsync(m => m.UserId == userId);
            if (member == null) return NotFound("Member not found");

            var transactions = await _context.WalletTransactions
                .Where(t => t.MemberId == member.Id)
                .OrderByDescending(t => t.CreatedDate)
                .ToListAsync();

            return Ok(transactions);
        }

        [HttpGet("admin/pending")]
        [Authorize(Roles = "Admin,Treasurer")]
        public async Task<IActionResult> GetPendingDeposits()
        {
            var transactions = await _context.WalletTransactions
                .Include(t => t.Member)
                .Where(t => t.Status == TransactionStatus.Pending && t.Type == TransactionType.Deposit)
                .OrderByDescending(t => t.CreatedDate)
                .Select(t => new
                {
                    t.Id,
                    t.MemberId,
                    MemberName = t.Member!.FullName,
                    t.Amount,
                    t.Description,
                    t.CreatedDate
                })
                .ToListAsync();

            return Ok(transactions);
        }

        [HttpPost("deposit")]
        public async Task<IActionResult> Deposit([FromBody] DepositRequest request)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var member = await _context.Members.FirstOrDefaultAsync(m => m.UserId == userId);
            if (member == null) return NotFound("Member not found");

            var transaction = new WalletTransaction
            {
                MemberId = member.Id,
                Amount = request.Amount,
                Type = TransactionType.Deposit,
                Status = TransactionStatus.Pending,
                Description = "Deposit Request",
                CreatedDate = DateTime.UtcNow
            };

            _context.WalletTransactions.Add(transaction);
            await _context.SaveChangesAsync();

            return Ok(transaction);
        }

        [HttpPut("approve/{id}")]
        [Authorize(Roles = "Admin,Treasurer")]
        public async Task<IActionResult> ApproveDeposit(int id)
        {
            var transaction = await _context.WalletTransactions.FindAsync(id);
            if (transaction == null) return NotFound("Transaction not found");

            if (transaction.Status != TransactionStatus.Pending || transaction.Type != TransactionType.Deposit)
                return BadRequest("Invalid transaction state");

            var member = await _context.Members.FindAsync(transaction.MemberId);
            if (member == null) return NotFound("Member not found");

            // Execute logic
            member.WalletBalance += transaction.Amount;
            transaction.Status = TransactionStatus.Completed;

            // Create Notification
            var noti = new Notification
            {
                ReceiverId = member.Id,
                Message = $"Yêu cầu nạp {transaction.Amount:N0}đ đã được duyệt!",
                Type = "Success",
                IsRead = false,
                CreatedDate = DateTime.UtcNow
            };
            _context.Notifications.Add(noti);
            await _context.SaveChangesAsync();

            // Send SignalR
            await _hubContext.Clients.User(member.UserId).SendAsync("ReceiveNotification", noti.Message);

            return Ok(new { Message = "Deposit approved", NewBalance = member.WalletBalance });
        }
    }

    public class DepositRequest
    {
        public decimal Amount { get; set; }
    }
}
