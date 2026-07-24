using DashTab.Application.Common.Interfaces;

namespace DashTab.Infrastructure.Services;

public class DateTimeProvider : IDateTimeProvider
{
    public DateTime UtcNow => DateTime.UtcNow;
}
