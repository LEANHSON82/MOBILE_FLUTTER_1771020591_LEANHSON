using Microsoft.AspNetCore.SignalR;
using System.Threading.Tasks;

namespace PCM_Backend.Hubs
{
    public class PcmHub : Hub
    {
        // Client listens to: ReceiveNotification, UpdateCalendar, UpdateMatchScore
        
        public async Task JoinMatchGroup(string matchId)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"Match_{matchId}");
        }

        public async Task LeaveMatchGroup(string matchId)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"Match_{matchId}");
        }
    }
}
