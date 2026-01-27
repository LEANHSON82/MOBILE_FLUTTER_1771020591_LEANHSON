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
    public class NotificationsController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public NotificationsController(ApplicationDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> GetMyNotifications()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var member = await _context.Members.FirstOrDefaultAsync(m => m.UserId == userId);
            if (member == null) return NotFound("Member not found");

            var notifications = await _context.Notifications
                .Where(n => n.ReceiverId == member.Id)
                .OrderByDescending(n => n.CreatedDate)
                .Take(50)
                .ToListAsync();

            return Ok(notifications);
        }

        [HttpPut("{id}/read")]
        public async Task<IActionResult> MarkAsRead(int id)
        {
            var notification = await _context.Notifications.FindAsync(id);
            if (notification == null) return NotFound();

            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var member = await _context.Members.FirstOrDefaultAsync(m => m.UserId == userId);
            
            if (notification.ReceiverId != member?.Id) return Forbid();

            notification.IsRead = true;
            await _context.SaveChangesAsync();

            return Ok();
        }

        [HttpPut("read-all")]
        public async Task<IActionResult> MarkAllAsRead()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var member = await _context.Members.FirstOrDefaultAsync(m => m.UserId == userId);
            if (member == null) return NotFound();

            var unread = await _context.Notifications
                .Where(n => n.ReceiverId == member.Id && !n.IsRead)
                .ToListAsync();

            foreach (var n in unread) n.IsRead = true;
            await _context.SaveChangesAsync();

            return Ok();
        }
    }
}
