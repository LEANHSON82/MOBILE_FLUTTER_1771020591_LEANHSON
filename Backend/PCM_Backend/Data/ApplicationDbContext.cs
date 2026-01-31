using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using PCM_Backend.Models;

namespace PCM_Backend.Data
{
    public class ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : IdentityDbContext(options)
    {
        public DbSet<Member> Members { get; set; } = null!;
        public DbSet<WalletTransaction> WalletTransactions { get; set; } = null!;
        public DbSet<News> News { get; set; } = null!;
        public DbSet<Court> Courts { get; set; } = null!;
        public DbSet<Booking> Bookings { get; set; } = null!;
        public DbSet<Tournament> Tournaments { get; set; } = null!;
        public DbSet<TournamentParticipant> TournamentParticipants { get; set; } = null!;
        public DbSet<Match> Matches { get; set; } = null!;
        public DbSet<Notification> Notifications { get; set; } = null!;
        public DbSet<TransactionCategory> TransactionCategories { get; set; } = null!;
        public DbSet<Duel> Duels { get; set; } = null!;
        public DbSet<ChatMessage> ChatMessages { get; set; } = null!;

        protected override void OnModelCreating(ModelBuilder builder)
        {
            base.OnModelCreating(builder);

            // Map tables with 591_ prefix
            builder.Entity<Member>().ToTable("591_Members");
            builder.Entity<WalletTransaction>().ToTable("591_WalletTransactions");
            builder.Entity<News>().ToTable("591_News");
            builder.Entity<Court>().ToTable("591_Courts");
            builder.Entity<Booking>().ToTable("591_Bookings");
            builder.Entity<Tournament>().ToTable("591_Tournaments");
            builder.Entity<TournamentParticipant>().ToTable("591_TournamentParticipants");
            builder.Entity<Match>().ToTable("591_Matches");
            builder.Entity<Notification>().ToTable("591_Notifications");
            builder.Entity<TransactionCategory>().ToTable("591_TransactionCategories");
            builder.Entity<Duel>().ToTable("591_Duels");
            builder.Entity<ChatMessage>().ToTable("591_ChatMessages");
        }
    }
}
