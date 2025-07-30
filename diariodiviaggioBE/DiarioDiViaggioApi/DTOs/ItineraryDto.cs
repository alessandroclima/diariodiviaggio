using DiarioDiViaggioApi.Models;
using System.ComponentModel.DataAnnotations;

namespace DiarioDiViaggioApi.DTOs
{
    public class CreateItineraryDto
    {
        [Required]
        public int TripId { get; set; }

        [Required]
        public DateTime Date { get; set; }

        [Required]
        [StringLength(200)]
        public string Title { get; set; } = string.Empty;

        [StringLength(1000)]
        public string? Description { get; set; }

        [Required]
        public ItineraryActivityType ActivityType { get; set; }

        [StringLength(200)]
        public string? Location { get; set; }

        public ItineraryTimeSlot TimeSlot { get; set; } = ItineraryTimeSlot.Morning;

        [StringLength(500)]
        public string? Notes { get; set; }
    }

    public class UpdateItineraryDto
    {
        [Required]
        [StringLength(200)]
        public string Title { get; set; } = string.Empty;

        [StringLength(1000)]
        public string? Description { get; set; }

        [Required]
        public ItineraryActivityType ActivityType { get; set; }

        [StringLength(200)]
        public string? Location { get; set; }

        public ItineraryTimeSlot TimeSlot { get; set; } = ItineraryTimeSlot.Morning;

        [StringLength(500)]
        public string? Notes { get; set; }

        public bool IsCompleted { get; set; }
    }

    public class ItineraryDto
    {
        public int Id { get; set; }
        public int TripId { get; set; }
        public DateTime Date { get; set; }
        public string Title { get; set; } = string.Empty;
        public string? Description { get; set; }
        public ItineraryActivityType ActivityType { get; set; }
        public string ActivityTypeName => ActivityType.ToString();
        public string? Location { get; set; }
        public ItineraryTimeSlot TimeSlot { get; set; }
        public string TimeSlotName => TimeSlot.ToString();
        public string? Notes { get; set; }
        public bool IsCompleted { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }

    public class ItineraryCalendarDto
    {
        public DateTime Date { get; set; }
        public List<ItineraryDto> Activities { get; set; } = new();
        public bool HasActivities => Activities.Any();
    }

    public class TripItineraryCalendarDto
    {
        public int TripId { get; set; }
        public string TripTitle { get; set; } = string.Empty;
        public DateTime StartDate { get; set; }
        public DateTime? EndDate { get; set; }
        public List<ItineraryCalendarDto> Calendar { get; set; } = new();
    }
}
