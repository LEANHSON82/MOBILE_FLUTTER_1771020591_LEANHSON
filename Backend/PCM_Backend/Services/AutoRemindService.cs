using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.AspNetCore.SignalR;
using PCM_Backend.Data;
using PCM_Backend.Models;
using PCM_Backend.Hubs;
using Microsoft.EntityFrameworkCore;

namespace PCM_Backend.Services
{
    public class AutoRemindService : BackgroundService
    {
        private readonly IServiceProvider _services;
        private readonly ILogger<AutoRemindService> _logger;

        public AutoRemindService(IServiceProvider services, ILogger<AutoRemindService> logger)
        {
            _services = services;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                _logger.LogInformation("Auto-Remind Service running...");

                try
                {
                    using (var scope = _services.CreateScope())
                    {
                        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
                        var hubContext = scope.ServiceProvider.GetRequiredService<IHubContext<PcmHub>>();

                        // Remind for bookings tomorrow
                        var tomorrow = DateTime.UtcNow.Date.AddDays(1);
                        var dayAfterTomorrow = tomorrow.AddDays(1);

                        var upcomingBookings = await context.Bookings
                            .Include(b => b.Member)
                            .Include(b => b.Court)
                            .Where(b => b.StartTime >= tomorrow && 
                                       b.StartTime < dayAfterTomorrow && 
                                       b.Status == BookingStatus.Confirmed)
                            .ToListAsync(stoppingToken);

                        foreach (var booking in upcomingBookings)
                        {
                            // Check if notification already sent today
                            var existingNotification = await context.Notifications
                                .AnyAsync(n => n.ReceiverId == booking.MemberId && 
                                              n.Message.Contains($"Booking #{booking.Id}") &&
                                              n.CreatedDate.Date == DateTime.UtcNow.Date, stoppingToken);

                            if (!existingNotification)
                            {
                                var notification = new Notification
                                {
                                    ReceiverId = booking.MemberId,
                                    Message = $"Nhắc nhở: Bạn có lịch đặt sân {booking.Court?.Name} vào ngày mai lúc {booking.StartTime:HH:mm}. (Booking #{booking.Id})",
                                    Type = "Info",
                                    IsRead = false,
                                    CreatedDate = DateTime.UtcNow
                                };

                                context.Notifications.Add(notification);
                                _logger.LogInformation($"Created reminder for Booking #{booking.Id}, Member #{booking.MemberId}");
                            }
                        }

                        // Remind for matches tomorrow
                        var upcomingMatches = await context.Matches
                            .Include(m => m.Tournament)
                            .Where(m => m.Date >= tomorrow && 
                                       m.Date < dayAfterTomorrow && 
                                       m.Status == MatchStatus.Scheduled)
                            .ToListAsync(stoppingToken);

                        foreach (var match in upcomingMatches)
                        {
                            var playerIds = new[] { match.Team1_Player1Id, match.Team1_Player2Id, 
                                                   match.Team2_Player1Id, match.Team2_Player2Id }
                                .Where(id => id.HasValue)
                                .Select(id => id!.Value)
                                .ToList();

                            foreach (var playerId in playerIds)
                            {
                                var existingNotification = await context.Notifications
                                    .AnyAsync(n => n.ReceiverId == playerId && 
                                                  n.Message.Contains($"Match #{match.Id}") &&
                                                  n.CreatedDate.Date == DateTime.UtcNow.Date, stoppingToken);

                                if (!existingNotification)
                                {
                                    var notification = new Notification
                                    {
                                        ReceiverId = playerId,
                                        Message = $"Nhắc nhở: Bạn có trận đấu {match.RoundName} vào ngày mai lúc {match.StartTime}. (Match #{match.Id})",
                                        Type = "Info",
                                        IsRead = false,
                                        CreatedDate = DateTime.UtcNow
                                    };

                                    context.Notifications.Add(notification);
                                    _logger.LogInformation($"Created match reminder for Match #{match.Id}, Player #{playerId}");
                                }
                            }
                        }

                        await context.SaveChangesAsync(stoppingToken);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in Auto-Remind Service");
                }

                // Run every hour
                await Task.Delay(TimeSpan.FromHours(1), stoppingToken);
            }
        }
    }
}
