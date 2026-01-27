using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Identity;

namespace PCM_Backend.Models
{
    // 591_Members
    public class Member
    {
        [Key]
        public int Id { get; set; }
        public string FullName { get; set; } = string.Empty;
        public DateTime JoinDate { get; set; } = DateTime.UtcNow;
        public double RankLevel { get; set; }
        public bool IsActive { get; set; } = true;

        // Identity Link
        public string UserId { get; set; } = string.Empty;
        [ForeignKey("UserId")]
        public virtual IdentityUser? User { get; set; }

        // Advanced
        [Column(TypeName = "decimal(18,2)")]
        public decimal WalletBalance { get; set; }
        public MembershipTier Tier { get; set; } = MembershipTier.Standard;
        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalSpent { get; set; }
        public string? AvatarUrl { get; set; }
    }

    public enum MembershipTier { Standard, Silver, Gold, Diamond }

    // 591_WalletTransactions
    public class WalletTransaction
    {
        [Key]
        public int Id { get; set; }
        public int MemberId { get; set; }
        [ForeignKey("MemberId")]
        public virtual Member? Member { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal Amount { get; set; }
        public TransactionType Type { get; set; }
        public TransactionStatus Status { get; set; }
        public string? RelatedId { get; set; }
        public string? Description { get; set; }
        public DateTime CreatedDate { get; set; } = DateTime.UtcNow;
    }

    public enum TransactionType { Deposit, Withdraw, Payment, Refund, Reward }
    public enum TransactionStatus { Pending, Completed, Rejected, Failed }

    // 591_News
    public class News
    {
        [Key]
        public int Id { get; set; }
        public string Title { get; set; } = string.Empty;
        public string Content { get; set; } = string.Empty;
        public bool IsPinned { get; set; }
        public DateTime CreatedDate { get; set; } = DateTime.UtcNow;
        public string? ImageUrl { get; set; }
    }

    // 591_Courts
    public class Court
    {
        [Key]
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public bool IsActive { get; set; } = true;
        public string? Description { get; set; }
        [Column(TypeName = "decimal(18,2)")]
        public decimal PricePerHour { get; set; }
    }

    // 591_Bookings
    public class Booking
    {
        [Key]
        public int Id { get; set; }
        public int CourtId { get; set; }
        [ForeignKey("CourtId")]
        public virtual Court? Court { get; set; }

        public int MemberId { get; set; }
        [ForeignKey("MemberId")]
        public virtual Member? Member { get; set; }

        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalPrice { get; set; }

        public int? TransactionId { get; set; } // Link to wallet transaction

        // Advanced
        public bool IsRecurring { get; set; }
        public string? RecurrenceRule { get; set; }
        public int? ParentBookingId { get; set; }
        public DateTime CreatedDate { get; set; } = DateTime.UtcNow;
        public BookingStatus Status { get; set; }
    }

    public enum BookingStatus { PendingPayment, Confirmed, Cancelled, Completed, Holding }

    // 591_Tournaments
    public class Tournament
    {
        [Key]
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public TournamentFormat Format { get; set; }
        [Column(TypeName = "decimal(18,2)")]
        public decimal EntryFee { get; set; }
        [Column(TypeName = "decimal(18,2)")]
        public decimal PrizePool { get; set; }
        public TournamentStatus Status { get; set; }
        public string? Settings { get; set; } // JSON
    }

    public enum TournamentFormat { RoundRobin, Knockout, Hybrid }
    public enum TournamentStatus { Open, Registering, DrawCompleted, Ongoing, Finished }

    // 591_TournamentParticipants
    public class TournamentParticipant
    {
        [Key]
        public int Id { get; set; }
        public int TournamentId { get; set; }
        [ForeignKey("TournamentId")]
        public virtual Tournament? Tournament { get; set; }

        public int MemberId { get; set; }
        [ForeignKey("MemberId")]
        public virtual Member? Member { get; set; }

        public string? TeamName { get; set; }
        public bool PaymentStatus { get; set; }
    }

    // 591_Matches
    public class Match
    {
        [Key]
        public int Id { get; set; }
        public int? TournamentId { get; set; }
        [ForeignKey("TournamentId")]
        public virtual Tournament? Tournament { get; set; }

        public string RoundName { get; set; } = string.Empty;
        public DateTime Date { get; set; }
        public TimeSpan StartTime { get; set; }

        // Participants (simplified)
        public int? Team1_Player1Id { get; set; }
        public int? Team1_Player2Id { get; set; }
        public int? Team2_Player1Id { get; set; }
        public int? Team2_Player2Id { get; set; }

        public int Score1 { get; set; }
        public int Score2 { get; set; }
        public string? Details { get; set; } // JSON details
        public MatchWinningSide? WinningSide { get; set; }
        public bool IsRanked { get; set; }
        public MatchStatus Status { get; set; }
    }

    public enum MatchWinningSide { Team1, Team2 }
    public enum MatchStatus { Scheduled, InProgress, Finished }

    // 591_Notifications
    public class Notification
    {
        [Key]
        public int Id { get; set; }
        public int ReceiverId { get; set; } // MemberId
        public string Message { get; set; } = string.Empty;
        public string Type { get; set; } = "Info";
        public string? LinkUrl { get; set; }
        public bool IsRead { get; set; }
        public DateTime CreatedDate { get; set; } = DateTime.UtcNow;
    }

    // 591_TransactionCategories (Dùng cho thu chi nội bộ khác)
    public class TransactionCategory
    {
        [Key]
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public CategoryType Type { get; set; }
    }

    public enum CategoryType { Income, Expense }
}

