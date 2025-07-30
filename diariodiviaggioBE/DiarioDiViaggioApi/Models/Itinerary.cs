using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace DiarioDiViaggioApi.Models
{
    public class Itinerary
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public int TripId { get; set; }

        [ForeignKey("TripId")]
        public Trip Trip { get; set; }

        [Required]
        public DateTime Date { get; set; }

        [Required]
        [StringLength(200)]
        public string Title { get; set; }

        [StringLength(1000)]
        public string? Description { get; set; }

        [Required]
        public ItineraryActivityType ActivityType { get; set; }

        [StringLength(200)]
        public string? Location { get; set; }

        public ItineraryTimeSlot TimeSlot { get; set; } = ItineraryTimeSlot.Morning;

        [StringLength(500)]
        public string? Notes { get; set; }

        public bool IsCompleted { get; set; } = false;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }

    public enum ItineraryActivityType
    {
        Sightseeing = 0,
        Restaurant = 1,
        Transportation = 2,
        Accommodation = 3,
        Shopping = 4,
        Entertainment = 5,
        Outdoor = 6,
        Cultural = 7,
        Relaxation = 8,
        Business = 9,
        Other = 10
    }

    public enum ItineraryTimeSlot
    {
        Morning = 0,
        Afternoon = 1
    }
}
