using DashTab.Domain.Interfaces;

namespace DashTab.Infrastructure.Data;

public class UnitOfWork : IUnitOfWork
{
    private readonly DashTabDbContext _dbContext;

    public UnitOfWork(DashTabDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return await _dbContext.SaveChangesAsync(cancellationToken);
    }

    public void Dispose()
    {
        _dbContext.Dispose();
    }
}
