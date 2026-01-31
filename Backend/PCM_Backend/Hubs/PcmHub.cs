using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.Authorization;

namespace PCM_Backend.Hubs
{
    [Authorize]
    public class PcmHub : Hub
    {
        // Client listens to: ReceiveNotification, UpdateCalendar, UpdateMatchScore, ReceiveChatMessage

        // === Match Groups ===
        public async Task JoinMatchGroup(string matchId)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"Match_{matchId}");
        }

        public async Task LeaveMatchGroup(string matchId)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"Match_{matchId}");
        }

        // === Tournament Chat Groups ===
        public async Task JoinTournamentChat(int tournamentId)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"TournamentChat_{tournamentId}");
            await Clients.Group($"TournamentChat_{tournamentId}").SendAsync("UserJoined", Context.User?.Identity?.Name ?? "Unknown", $"đã tham gia phòng chat");
        }

        public async Task LeaveTournamentChat(int tournamentId)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"TournamentChat_{tournamentId}");
            await Clients.Group($"TournamentChat_{tournamentId}").SendAsync("UserLeft", Context.User?.Identity?.Name ?? "Unknown", $"đã rời phòng chat");
        }

        public async Task SendMessageToTournament(int tournamentId, string message)
        {
            var username = Context.User?.Identity?.Name ?? "Anonymous";
            var timestamp = DateTime.UtcNow;
            
            await Clients.Group($"TournamentChat_{tournamentId}").SendAsync(
                "ReceiveChatMessage",
                new
                {
                    Username = username,
                    Message = message,
                    Timestamp = timestamp.ToString("HH:mm"),
                    TournamentId = tournamentId
                }
            );
        }

        // === Duel Chat (1v1) ===
        public async Task JoinDuelChat(int duelId)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"DuelChat_{duelId}");
        }

        public async Task LeaveDuelChat(int duelId)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"DuelChat_{duelId}");
        }

        public async Task SendMessageToDuel(int duelId, string message)
        {
            var username = Context.User?.Identity?.Name ?? "Anonymous";
            
            await Clients.Group($"DuelChat_{duelId}").SendAsync(
                "ReceiveChatMessage",
                new
                {
                    Username = username,
                    Message = message,
                    Timestamp = DateTime.UtcNow.ToString("HH:mm"),
                    DuelId = duelId
                }
            );
        }

        public override async Task OnConnectedAsync()
        {
            // Optional: Log connection
            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            // Optional: Cleanup
            await base.OnDisconnectedAsync(exception);
        }
    }
}
