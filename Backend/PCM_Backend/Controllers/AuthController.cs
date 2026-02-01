using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using PCM_Backend.Data;
using PCM_Backend.Models;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace PCM_Backend.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly UserManager<IdentityUser> _userManager;
        private readonly SignInManager<IdentityUser> _signInManager;
        private readonly RoleManager<IdentityRole> _roleManager;
        private readonly IConfiguration _configuration;
        private readonly ApplicationDbContext _context;

        public AuthController(UserManager<IdentityUser> userManager,
            SignInManager<IdentityUser> signInManager,
            RoleManager<IdentityRole> roleManager,
            IConfiguration configuration,
            ApplicationDbContext context)
        {
            _userManager = userManager;
            _signInManager = signInManager;
            _roleManager = roleManager;
            _configuration = configuration;
            _context = context;
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginModel model)
        {
            Console.WriteLine($"[AUTH] Login attempt for user: {model.Username}");
            try
            {
                var user = await _userManager.FindByNameAsync(model.Username);
                if (user == null)
                {
                    Console.WriteLine($"[AUTH] User not found: {model.Username}");
                    return Unauthorized(new { message = "Tài khoản không tồn tại" });
                }

                var result = await _signInManager.CheckPasswordSignInAsync(user, model.Password, false);
                if (result.Succeeded)
                {
                    var authClaims = new List<Claim>
                    {
                        new Claim(ClaimTypes.Name, user.UserName!),
                        new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
                        new Claim(ClaimTypes.NameIdentifier, user.Id)
                    };

                    var userRoles = await _userManager.GetRolesAsync(user);
                    foreach (var role in userRoles)
                    {
                        authClaims.Add(new Claim(ClaimTypes.Role, role));
                    }

                    var token = GetToken(authClaims);

                    // Get Member info - Use Async
                    var member = await _context.Members.FirstOrDefaultAsync(m => m.UserId == user.Id);

                    Console.WriteLine($"[AUTH] Login successful for: {model.Username}");
                    return Ok(new
                    {
                        token = new JwtSecurityTokenHandler().WriteToken(token),
                        expiration = token.ValidTo,
                        user = member,
                        roles = userRoles
                    });
                }

                Console.WriteLine($"[AUTH] Invalid password for user: {model.Username}");
                return Unauthorized(new { message = "Mật khẩu không chính xác" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ERROR] Login exception: {ex.Message}");
                return StatusCode(500, new { message = "Lỗi hệ thống", detail = ex.Message });
            }
        }

        [HttpGet("force-create-admin")]
        [AllowAnonymous]
        public async Task<IActionResult> ForceCreateAdmin()
        {
            if (!await _roleManager.RoleExistsAsync("Admin"))
                await _roleManager.CreateAsync(new IdentityRole("Admin"));

            var user = await _userManager.FindByNameAsync("admin");
            if (user == null)
            {
                user = new IdentityUser { UserName = "admin", Email = "admin@pcm.com", EmailConfirmed = true };
                var result = await _userManager.CreateAsync(user, "Password123!");
                if (!result.Succeeded) return BadRequest(result.Errors);
            }

            if (!await _userManager.IsInRoleAsync(user, "Admin"))
            {
                await _userManager.AddToRoleAsync(user, "Admin");
            }

            // Create Member record if not exists
            var existingMember = _context.Members.FirstOrDefault(m => m.UserId == user.Id);
            if (existingMember == null)
            {
                var member = new Member
                {
                    UserId = user.Id,
                    FullName = "Administrator",
                    WalletBalance = 9999999
                };
                _context.Members.Add(member);
                await _context.SaveChangesAsync();
            }

            return Ok("Admin user created/verified: admin / Password123!");
        }

        [HttpGet("me")]
        public async Task<IActionResult> GetMe()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (userId == null) return Unauthorized();

            var member = _context.Members.FirstOrDefault(m => m.UserId == userId);

            var user = await _userManager.FindByIdAsync(userId);
            var roles = await _userManager.GetRolesAsync(user!);

            return Ok(new { user = member, roles = roles });
        }

        // Register for testing purposes
        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterModel model)
        {
            var user = new IdentityUser { UserName = model.Username, Email = model.Email };
            var result = await _userManager.CreateAsync(user, model.Password);

            if (result.Succeeded)
            {
                // Create Member
                var member = new Member
                {
                    FullName = model.FullName,
                    UserId = user.Id,
                    WalletBalance = 2000000 // Seed
                };
                _context.Members.Add(member);
                await _context.SaveChangesAsync();

                return Ok(new { Status = "Success", Message = "User created successfully!" });
            }
            return StatusCode(StatusCodes.Status500InternalServerError, new { Status = "Error", Message = "User creation failed! Please check user details and try again." });
        }

        private JwtSecurityToken GetToken(List<Claim> authClaims)
        {
            var authSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_configuration["Jwt:Key"] ?? "ThisIsASecretKeyForJWTTokenGeneration123456"));

            var token = new JwtSecurityToken(
                issuer: _configuration["Jwt:Issuer"],
                audience: _configuration["Jwt:Audience"],
                expires: DateTime.Now.AddHours(3),
                claims: authClaims,
                signingCredentials: new SigningCredentials(authSigningKey, SecurityAlgorithms.HmacSha256)
            );

            return token;
        }
    }

    public class LoginModel
    {
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
    }

    public class RegisterModel
    {
        public string Username { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string FullName { get; set; } = string.Empty;
    }
}
