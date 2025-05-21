using Microsoft.EntityFrameworkCore;
using SampleApp.WebApp.Models;

namespace SampleApp.WebApp.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options)
            : base(options)
        {
        }

        public DbSet<MyEntity> MyEntities { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // You can add any model configurations here if needed
            // For example:
            // modelBuilder.Entity<MyEntity>().ToTable("MyEntities");

            modelBuilder.Entity<MyEntity>().HasData(
                new MyEntity { Id = 1, Name = "Sample Entity 1" },
                new MyEntity { Id = 2, Name = "Sample Entity 2" },
                new MyEntity { Id = 3, Name = "Demo Item Alpha" }
            );
        }
    }
}