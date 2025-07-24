using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiarioDiViaggioApi.Migrations
{
    /// <inheritdoc />
    public partial class UpdateTripItemImageToDatabase : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ImagePath",
                table: "TripItems");

            migrationBuilder.AddColumn<byte[]>(
                name: "ImageData",
                table: "TripItems",
                type: "bytea",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ImageData",
                table: "TripItems");

            migrationBuilder.AddColumn<string>(
                name: "ImagePath",
                table: "TripItems",
                type: "text",
                nullable: true);
        }
    }
}
