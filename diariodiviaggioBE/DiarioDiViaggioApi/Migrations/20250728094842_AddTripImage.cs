using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiarioDiViaggioApi.Migrations
{
    /// <inheritdoc />
    public partial class AddTripImage : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<byte[]>(
                name: "TripImage",
                table: "Trips",
                type: "bytea",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "TripImage",
                table: "Trips");
        }
    }
}
