using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using SampleApp.WebApp.Data;
using SampleApp.WebApp.Models;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace SampleApp.WebApp.Pages;

public class IndexModel : PageModel
{
    private readonly AppDbContext _context;
    private readonly ILogger<IndexModel> _logger;

    public IndexModel(AppDbContext context, ILogger<IndexModel> logger)
    {
        _context = context;
        _logger = logger;
    }

    public IList<MyEntity> MyEntities { get;set; } = new List<MyEntity>();

    public async Task OnGetAsync()
    {
        MyEntities = await _context.MyEntities.ToListAsync();
    }
}
