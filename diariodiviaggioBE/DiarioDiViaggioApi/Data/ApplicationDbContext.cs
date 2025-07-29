using Microsoft.EntityFrameworkCore;
using DiarioDiViaggioApi.Models;

namespace DiarioDiViaggioApi.Data;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<User> Users { get; set; }
    public DbSet<Trip> Trips { get; set; }
    public DbSet<TripShare> TripShares { get; set; }
    public DbSet<TripItem> TripItems { get; set; }
    public DbSet<Luggage> Luggages { get; set; }
    public DbSet<LuggageItem> LuggageItems { get; set; }
    public DbSet<RefreshToken> RefreshTokens { get; set; }
    public DbSet<PasswordResetToken> PasswordResetTokens { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Configure unique constraints
        modelBuilder.Entity<User>()
            .HasIndex(u => u.Email)
            .IsUnique();

        modelBuilder.Entity<User>()
            .HasIndex(u => u.Username)
            .IsUnique();

        modelBuilder.Entity<Trip>()
            .HasIndex(t => t.ShareCode)
            .IsUnique();

        // Configure relationships
        modelBuilder.Entity<Trip>()
            .HasOne(t => t.Owner)
            .WithMany(u => u.Trips)
            .HasForeignKey(t => t.OwnerId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<TripShare>()
            .HasOne(ts => ts.Trip)
            .WithMany(t => t.SharedWithUsers)
            .HasForeignKey(ts => ts.TripId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<TripShare>()
            .HasOne(ts => ts.User)
            .WithMany(u => u.SharedTrips)
            .HasForeignKey(ts => ts.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        // Configure PasswordResetToken relationship
        modelBuilder.Entity<PasswordResetToken>()
            .HasOne(prt => prt.User)
            .WithMany(u => u.PasswordResetTokens)
            .HasForeignKey(prt => prt.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<PasswordResetToken>()
            .HasIndex(prt => prt.Token)
            .IsUnique();
    }
}
