using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PCM_Backend.Migrations
{
    /// <inheritdoc />
    public partial class AddDuels : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "591_Duels",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ChallengerId = table.Column<int>(type: "int", nullable: false),
                    ChallengerPartnerId = table.Column<int>(type: "int", nullable: true),
                    OpponentId = table.Column<int>(type: "int", nullable: true),
                    OpponentPartnerId = table.Column<int>(type: "int", nullable: true),
                    BetAmount = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    Type = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    ScheduledTime = table.Column<DateTime>(type: "datetime2", nullable: true),
                    WinningSide = table.Column<int>(type: "int", nullable: true),
                    Result = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    Message = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    CreatedDate = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_591_Duels", x => x.Id);
                    table.ForeignKey(
                        name: "FK_591_Duels_591_Members_ChallengerId",
                        column: x => x.ChallengerId,
                        principalTable: "591_Members",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_591_Duels_ChallengerId",
                table: "591_Duels",
                column: "ChallengerId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "591_Duels");
        }
    }
}
