using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace DiarioDiViaggioApi.Migrations
{
    /// <inheritdoc />
    public partial class UpdateItineraryTimeSlots : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "EndTime",
                table: "Itineraries");

            migrationBuilder.DropColumn(
                name: "StartTime",
                table: "Itineraries");

            migrationBuilder.AddColumn<int>(
                name: "TimeSlot",
                table: "Itineraries",
                type: "integer",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "TimeSlot",
                table: "Itineraries");

            migrationBuilder.AddColumn<TimeSpan>(
                name: "EndTime",
                table: "Itineraries",
                type: "interval",
                nullable: true);

            migrationBuilder.AddColumn<TimeSpan>(
                name: "StartTime",
                table: "Itineraries",
                type: "interval",
                nullable: true);
        }
    }
}
