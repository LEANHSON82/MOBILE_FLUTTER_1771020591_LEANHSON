using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using PCM_Backend.Data;
using PCM_Backend.Models;

namespace PCM_Backend.Services
{
    public static class DataSeeder
    {
        public static async Task SeedData(IServiceProvider serviceProvider)
        {
            using var scope = serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var userManager = scope.ServiceProvider.GetRequiredService<UserManager<IdentityUser>>();
            var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole>>();

            context.Database.EnsureCreated();

            // 1. Roles
            string[] roles = { "Admin", "Treasurer", "Referee", "Member" };
            foreach (var role in roles)
            {
                if (!await roleManager.RoleExistsAsync(role))
                    await roleManager.CreateAsync(new IdentityRole(role));
            }

            // 2. Admin, Treasurer, Referee
            var adminUser = await EnsureUser(userManager, "admin", "Admin User", "Admin");
            await EnsureUser(userManager, "treasurer", "Treasurer User", "Treasurer");
            await EnsureUser(userManager, "referee", "Referee User", "Referee");

            // Ensure Admin has Member record (fix for Wallet/Notifications)
            if (adminUser != null && !context.Members.Any(m => m.UserId == adminUser.Id))
            {
                context.Members.Add(new Member
                {
                    FullName = "System Admin",
                    UserId = adminUser.Id,
                    WalletBalance = 0,
                    Tier = MembershipTier.Diamond,
                    IsActive = true,
                    TotalSpent = 0,
                    JoinDate = DateTime.UtcNow,
                    AvatarUrl = "https://ui-avatars.com/api/?name=Admin&background=random"
                });
                await context.SaveChangesAsync();
            }

            // 3. Members (Expand to 50 users)
            if (context.Members.Count() < 50)
            {
                for (int i = 1; i <= 50; i++)
                {
                    var username = $"member{i}";
                    var user = await EnsureUser(userManager, username, $"Member {i}", "Member");

                    if (user != null && !context.Members.Any(m => m.UserId == user.Id))
                    {
                        var member = new Member
                        {
                            FullName = $"Member {i}",
                            UserId = user.Id,
                            RankLevel = 2.5 + (new Random().NextDouble() * 4.0), // 2.5 to 6.5
                            WalletBalance = new Random().Next(500000, 20000000),
                            Tier = (MembershipTier)(i % 4), // Rotate tiers
                            TotalSpent = i * 150000,
                            JoinDate = DateTime.UtcNow.AddDays(-new Random().Next(1, 365)),
                            IsActive = true,
                            AvatarUrl = $"https://api.dicebear.com/7.x/avataaars/png?seed={username}" // Mock avatar
                        };
                        context.Members.Add(member);

                        // Seed initial transaction for deposit
                        context.WalletTransactions.Add(new WalletTransaction
                        {
                            MemberId = member.Id, // Will be set after save, but we are adding to context
                            Member = member,
                            Amount = member.WalletBalance,
                            Type = TransactionType.Deposit,
                            Status = TransactionStatus.Completed,
                            Description = "Initial Deposit",
                            CreatedDate = DateTime.UtcNow
                        });
                    }
                }
                await context.SaveChangesAsync();
            }

            // 4. Courts
            if (context.Courts.Count() < 5)
            {
                context.Courts.AddRange(
                    new Court { Name = "Sân 1 (VIP)", PricePerHour = 150000, Description = "Sân chuẩn quốc tế, mái che", IsActive = true },
                    new Court { Name = "Sân 2 (VIP)", PricePerHour = 150000, Description = "Sân chuẩn quốc tế, mái che", IsActive = true },
                    new Court { Name = "Sân 3", PricePerHour = 100000, Description = "Sân tiêu chuẩn", IsActive = true },
                    new Court { Name = "Sân 4", PricePerHour = 100000, Description = "Sân tiêu chuẩn", IsActive = true },
                    new Court { Name = "Sân 5", PricePerHour = 80000, Description = "Sân tập luyện", IsActive = true },
                    new Court { Name = "Sân 6", PricePerHour = 80000, Description = "Sân tập luyện", IsActive = true },
                    new Court { Name = "Sân 7", PricePerHour = 50000, Description = "Sân ngoài trời", IsActive = true }
                );
                await context.SaveChangesAsync();
            }

            // 5. Tournaments
            if (context.Tournaments.Count() < 3)
            {
                var t1 = new Tournament
                {
                    Name = "Summer Open 2025",
                    StartDate = DateTime.UtcNow.AddMonths(-6),
                    EndDate = DateTime.UtcNow.AddMonths(-5),
                    Format = TournamentFormat.Knockout,
                    EntryFee = 200000,
                    PrizePool = 5000000,
                    Status = TournamentStatus.Finished
                };

                var t2 = new Tournament
                {
                    Name = "Winter Cup 2025",
                    StartDate = DateTime.UtcNow.AddDays(-10),
                    EndDate = DateTime.UtcNow.AddDays(10),
                    Format = TournamentFormat.RoundRobin,
                    EntryFee = 300000,
                    PrizePool = 10000000,
                    Status = TournamentStatus.Ongoing
                };

                var t3 = new Tournament
                {
                    Name = "Spring Championship 2026",
                    StartDate = DateTime.UtcNow.AddMonths(2),
                    EndDate = DateTime.UtcNow.AddMonths(3),
                    Format = TournamentFormat.Knockout,
                    EntryFee = 500000,
                    PrizePool = 20000000,
                    Status = TournamentStatus.Open
                };

                var t4 = new Tournament
                {
                    Name = "Weekend Friendly",
                    StartDate = DateTime.UtcNow.AddDays(5),
                    EndDate = DateTime.UtcNow.AddDays(6),
                    Format = TournamentFormat.RoundRobin,
                    EntryFee = 50000,
                    PrizePool = 1000000,
                    Status = TournamentStatus.Registering
                };

                context.Tournaments.AddRange(t1, t2, t3, t4);
                await context.SaveChangesAsync();

                // Seed Matches for Finished Tournament (Summer Open 2025)
                // We need members to participate
                var members = await context.Members.Take(8).ToListAsync();
                if (members.Count >= 8)
                {
                    // Create participants
                    foreach (var m in members)
                    {
                        context.TournamentParticipants.Add(new TournamentParticipant { TournamentId = t1.Id, MemberId = m.Id, PaymentStatus = true, TeamName = m.FullName });
                    }
                    await context.SaveChangesAsync();

                    // Quarter Finals
                    // Simplified: just add some matches
                    context.Matches.Add(new Match
                    {
                        TournamentId = t1.Id,
                        RoundName = "Quarter Final 1",
                        Date = t1.StartDate.AddDays(1),
                        StartTime = new TimeSpan(8, 0, 0),
                        Team1_Player1Id = members[0].Id,
                        Team2_Player1Id = members[1].Id,
                        Score1 = 2,
                        Score2 = 0,
                        WinningSide = MatchWinningSide.Team1,
                        Details = "11-5, 11-8",
                        Status = MatchStatus.Finished
                    });

                    context.Matches.Add(new Match
                    {
                        TournamentId = t1.Id,
                        RoundName = "Quarter Final 2",
                        Date = t1.StartDate.AddDays(1),
                        StartTime = new TimeSpan(9, 0, 0),
                        Team1_Player1Id = members[2].Id,
                        Team2_Player1Id = members[3].Id,
                        Score1 = 1,
                        Score2 = 2,
                        WinningSide = MatchWinningSide.Team2,
                        Details = "11-9, 5-11, 10-12",
                        Status = MatchStatus.Finished
                    });
                }

                // Seed Matches for Ongoing Tournament (Winter Cup)
                var members2 = await context.Members.Skip(8).Take(4).ToListAsync();
                if (members2.Count >= 4)
                {
                    foreach (var m in members2)
                    {
                        context.TournamentParticipants.Add(new TournamentParticipant { TournamentId = t2.Id, MemberId = m.Id, PaymentStatus = true, TeamName = m.FullName });
                    }
                    await context.SaveChangesAsync();

                    context.Matches.Add(new Match
                    {
                        TournamentId = t2.Id,
                        RoundName = "Group A - Match 1",
                        Date = DateTime.UtcNow.AddDays(-1),
                        StartTime = new TimeSpan(18, 0, 0),
                        Team1_Player1Id = members2[0].Id,
                        Team2_Player1Id = members2[1].Id,
                        Score1 = 2,
                        Score2 = 1,
                        WinningSide = MatchWinningSide.Team1,
                        Details = "11-2, 8-11, 11-9",
                        Status = MatchStatus.Finished
                    });

                    context.Matches.Add(new Match
                    {
                        TournamentId = t2.Id,
                        RoundName = "Group A - Match 2",
                        Date = DateTime.UtcNow.Date,
                        StartTime = new TimeSpan(19, 0, 0),
                        Team1_Player1Id = members2[2].Id,
                        Team2_Player1Id = members2[3].Id,
                        Status = MatchStatus.Scheduled
                    });
                }
                await context.SaveChangesAsync();
            }

            // 6. News
            if (!context.News.Any())
            {
                context.News.AddRange(
                    new News { Title = "Khai trương sân mới", Content = "Chào mừng sân số 5, 6, 7 đi vào hoạt động với giá ưu đãi!", CreatedDate = DateTime.UtcNow.AddDays(-10), IsPinned = true, ImageUrl = "https://picsum.photos/seed/court/400/200" },
                    new News { Title = "Giải đấu Mùa Đông", Content = "Winter Cup đang diễn ra hết sức sôi động. Hãy đến xem và cổ vũ!", CreatedDate = DateTime.UtcNow.AddDays(-2), IsPinned = false, ImageUrl = "https://picsum.photos/seed/winter/400/200" },
                    new News { Title = "Bảo trì hệ thống", Content = "Hệ thống đặt sân sẽ bảo trì từ 2h-4h sáng ngày mai.", CreatedDate = DateTime.UtcNow.AddDays(-1), IsPinned = false, ImageUrl = "https://picsum.photos/seed/maintenance/400/200" },
                    new News { Title = "Kết quả Summer Open", Content = "Chúc mừng Member 1 đã vô địch giải Summer Open 2025!", CreatedDate = DateTime.UtcNow.AddMonths(-5), IsPinned = false, ImageUrl = "https://picsum.photos/seed/winner/400/200" },
                    new News { Title = "Thay đổi giá sân", Content = "Từ tháng sau giá sân giờ vàng sẽ tăng nhẹ 10%.", CreatedDate = DateTime.UtcNow.AddDays(-20), IsPinned = false }
                );
                await context.SaveChangesAsync();
            }

            // 7. Bookings (Random bookings for next 7 days)
            if (context.Bookings.Count() < 5)
            {
                var members = await context.Members.Take(5).ToListAsync();
                var courts = await context.Courts.Take(3).ToListAsync();
                var random = new Random();

                foreach (var court in courts)
                {
                    for (int d = 0; d < 7; d++)
                    {
                        // Random 1-2 bookings per day per court
                        if (random.Next(0, 2) == 1)
                        {
                            var hour = random.Next(7, 20);
                            var booking = new Booking
                            {
                                CourtId = court.Id,
                                MemberId = members[random.Next(members.Count)].Id,
                                StartTime = DateTime.UtcNow.Date.AddDays(d).AddHours(hour),
                                EndTime = DateTime.UtcNow.Date.AddDays(d).AddHours(hour + 1),
                                TotalPrice = court.PricePerHour,
                                Status = BookingStatus.Confirmed,
                                IsRecurring = false
                            };
                            context.Bookings.Add(booking);

                            // Add Transaction for Booking
                            context.WalletTransactions.Add(new WalletTransaction
                            {
                                MemberId = booking.MemberId,
                                Amount = -booking.TotalPrice,
                                Type = TransactionType.Payment,
                                Status = TransactionStatus.Completed,
                                Description = $"Booking {court.Name} - {booking.StartTime:dd/MM HH:mm}",
                                CreatedDate = DateTime.UtcNow
                            });
                        }
                    }
                }
                await context.SaveChangesAsync();
            }

            // 8. Pending Transaction (For testing Admin Wallet)
            if (!context.WalletTransactions.Any(t => t.Status == TransactionStatus.Pending))
            {
                var member = await context.Members.FirstOrDefaultAsync();
                if (member != null)
                {
                    context.WalletTransactions.Add(new WalletTransaction
                    {
                        MemberId = member.Id,
                        Amount = 500000,
                        Type = TransactionType.Deposit,
                        Status = TransactionStatus.Pending,
                        Description = "Nạp tiền chờ duyệt (Test)",
                        CreatedDate = DateTime.UtcNow
                    });
                    await context.SaveChangesAsync();
                }
            }
        }

        private static async Task<IdentityUser?> EnsureUser(UserManager<IdentityUser> userManager, string username, string fullName, string role)
        {
            var user = await userManager.FindByNameAsync(username);
            if (user == null)
            {
                user = new IdentityUser { UserName = username, Email = $"{username}@pcm.com", EmailConfirmed = true };
                var result = await userManager.CreateAsync(user, "Password123!");
                if (result.Succeeded)
                {
                    await userManager.AddToRoleAsync(user, role);
                    return user;
                }
            }
            return user;
        }
    }
}
