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
    public class BookingController(ApplicationDbContext context, IHubContext<PcmHub> hubContext) : ControllerBase
    {
        private readonly ApplicationDbContext _context = context;
        private readonly IHubContext<PcmHub> _hubContext = hubContext;

        [HttpGet("courts")]
        public async Task<IActionResult> GetCourts()
        {
            return Ok(await _context.Courts.Where(c => c.IsActive).ToListAsync());
        }

        [HttpGet("calendar")]
        public async Task<IActionResult> GetCalendar(DateTime from, DateTime to)
        {
            var bookings = await _context.Bookings
                .Include(b => b.Member)
                .Where(b => b.StartTime >= from && b.EndTime <= to && b.Status != BookingStatus.Cancelled)
                .ToListAsync();
            return Ok(bookings);
        }

        [HttpPost]
        public async Task<IActionResult> CreateBooking([FromBody] BookingRequest request)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var member = await _context.Members.FirstOrDefaultAsync(m => m.UserId == userId);
            if (member == null) return NotFound("Member not found");

            // Check intersection
            var conflict = await _context.Bookings.AnyAsync(b =>
                b.CourtId == request.CourtId &&
                b.Status != BookingStatus.Cancelled &&
                ((request.StartTime >= b.StartTime && request.StartTime < b.EndTime) ||
                 (request.EndTime > b.StartTime && request.EndTime <= b.EndTime)));

            if (conflict) return BadRequest("Slot already booked");

            // Calculate Price
            var court = await _context.Courts.FindAsync(request.CourtId);
            if (court == null) return BadRequest("Court not found");

            var duration = (request.EndTime - request.StartTime).TotalHours;
            var totalPrice = (decimal)duration * court.PricePerHour;

            if (member.WalletBalance < totalPrice) return BadRequest("Insufficient balance");

            // Create Booking
            var booking = new Booking
            {
                CourtId = request.CourtId,
                MemberId = member.Id,
                StartTime = request.StartTime,
                EndTime = request.EndTime,
                TotalPrice = totalPrice,
                Status = BookingStatus.Confirmed,
                CreatedDate = DateTime.UtcNow
            };

            // Deduct Money
            member.WalletBalance -= totalPrice;

            var transaction = new WalletTransaction
            {
                MemberId = member.Id,
                Amount = -totalPrice,
                Type = TransactionType.Payment,
                Status = TransactionStatus.Completed,
                Description = $"Booking Court {court.Name}",
                CreatedDate = DateTime.UtcNow
            };

            _context.Bookings.Add(booking);
            _context.WalletTransactions.Add(transaction);
            await _context.SaveChangesAsync();

            // Notify SignalR
            await _hubContext.Clients.All.SendAsync("UpdateCalendar", "New booking added");

            return Ok(booking);
        }

        [HttpPost("recurring")]
        public async Task<IActionResult> CreateRecurringBooking([FromBody] RecurringBookingRequest request)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var member = await _context.Members.FirstOrDefaultAsync(m => m.UserId == userId);
            if (member == null) return NotFound("Member not found");

            // Only VIP (Gold/Diamond) can book recurring
            if (member.Tier != MembershipTier.Gold && member.Tier != MembershipTier.Diamond)
                return BadRequest("Only Gold and Diamond members can book recurring schedules");

            var bookings = new List<Booking>();
            decimal totalPrice = 0;
            var court = await _context.Courts.FindAsync(request.CourtId);
            if (court == null) return NotFound("Court not found");

            var currentDate = request.StartDate;
            while (currentDate <= request.EndDate)
            {
                if (request.DaysOfWeek.Contains(currentDate.DayOfWeek))
                {
                    var start = currentDate.Date.Add(request.StartTime);
                    var end = currentDate.Date.Add(request.EndTime);

                    // Check conflict
                    var conflict = await _context.Bookings.AnyAsync(b =>
                        b.CourtId == request.CourtId &&
                        b.Status != BookingStatus.Cancelled &&
                        ((start >= b.StartTime && start < b.EndTime) ||
                         (end > b.StartTime && end <= b.EndTime)));

                    if (!conflict)
                    {
                        var price = (decimal)(end - start).TotalHours * court.PricePerHour;
                        totalPrice += price;
                        bookings.Add(new Booking
                        {
                            CourtId = request.CourtId,
                            MemberId = member.Id,
                            StartTime = start,
                            EndTime = end,
                            TotalPrice = price,
                            Status = BookingStatus.Confirmed,
                            IsRecurring = true,
                            RecurrenceRule = $"Weekly;{string.Join(',', request.DaysOfWeek)}",
                            CreatedDate = DateTime.UtcNow
                        });
                    }
                }
                currentDate = currentDate.AddDays(1);
            }

            if (bookings.Count == 0) return BadRequest("No available slots found for recurring booking");

            if (member.WalletBalance < totalPrice) return BadRequest("Insufficient balance for all recurring slots");

            // Process Payment
            member.WalletBalance -= totalPrice;
            var transaction = new WalletTransaction
            {
                MemberId = member.Id,
                Amount = -totalPrice,
                Type = TransactionType.Payment,
                Status = TransactionStatus.Completed,
                Description = $"Recurring Booking {court.Name} ({bookings.Count} slots)",
                CreatedDate = DateTime.UtcNow
            };

            _context.Bookings.AddRange(bookings);
            _context.WalletTransactions.Add(transaction);
            await _context.SaveChangesAsync();

            await _hubContext.Clients.All.SendAsync("UpdateCalendar", "Recurring booking added");

            return Ok(new { Count = bookings.Count, TotalPrice = totalPrice });
        }

        [HttpPost("cancel/{id}")]
        public async Task<IActionResult> CancelBooking(int id)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var member = await _context.Members.FirstOrDefaultAsync(m => m.UserId == userId);
            if (member == null) return NotFound("Member not found");

            var booking = await _context.Bookings
                .Include(b => b.Court)
                .FirstOrDefaultAsync(b => b.Id == id && b.MemberId == member.Id);

            if (booking == null) return NotFound("Booking not found");
            if (booking.Status == BookingStatus.Cancelled) return BadRequest("Booking already cancelled");
            if (booking.Status == BookingStatus.Completed) return BadRequest("Cannot cancel completed booking");

            // Calculate refund based on policy
            decimal refundAmount;
            var hoursUntilBooking = (booking.StartTime - DateTime.UtcNow).TotalHours;

            if (hoursUntilBooking >= 24)
            {
                refundAmount = booking.TotalPrice; // 100% refund
            }
            else if (hoursUntilBooking >= 0)
            {
                refundAmount = booking.TotalPrice * 0.5m; // 50% refund
            }
            else
            {
                return BadRequest("Cannot cancel past bookings");
            }

            // Update booking status
            booking.Status = BookingStatus.Cancelled;

            // Refund to wallet
            member.WalletBalance += refundAmount;

            // Create refund transaction
            var transaction = new WalletTransaction
            {
                MemberId = member.Id,
                Amount = refundAmount,
                Type = TransactionType.Refund,
                Status = TransactionStatus.Completed,
                RelatedId = booking.Id.ToString(),
                Description = $"Refund for cancelled booking - Court {booking.Court?.Name}",
                CreatedDate = DateTime.UtcNow
            };

            _context.WalletTransactions.Add(transaction);
            await _context.SaveChangesAsync();

            // Notify via SignalR
            await _hubContext.Clients.All.SendAsync("UpdateCalendar", "Booking cancelled");

            return Ok(new
            {
                Message = "Booking cancelled successfully",
                RefundAmount = refundAmount,
                RefundPercentage = hoursUntilBooking >= 24 ? 100 : 50,
                NewBalance = member.WalletBalance
            });
        }
    }

    public class BookingRequest
    {
        public int CourtId { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
    }

    public class RecurringBookingRequest
    {
        public int CourtId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public List<DayOfWeek> DaysOfWeek { get; set; } = [];
        public TimeSpan StartTime { get; set; }
        public TimeSpan EndTime { get; set; }
    }
}
