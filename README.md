# DashTab POS

Commercial-grade multi-tenant Restaurant Management & POS SaaS Platform.

## Architecture

- **Backend**: ASP.NET Core .NET 9, PostgreSQL, Redis
- **Frontend**: Flutter (Desktop, Mobile, Web)
- **Architecture**: Clean Architecture + CQRS
- **Multi-tenancy**: Shared database with tenant isolation

## Project Structure

```
├── src/
│   ├── DashTab.Domain/          # Core business entities & interfaces
│   ├── DashTab.Application/     # Use cases, CQRS, DTOs
│   ├── DashTab.Infrastructure/  # EF Core, identity, services
│   └── DashTab.Api/             # REST API, controllers, middleware
├── tests/
├── dashtab_pos/                 # Flutter application
└── docker/                      # Docker Compose configs
```

## Getting Started

### Prerequisites
- .NET 9 SDK
- Flutter 3.x
- Docker & Docker Compose
- PostgreSQL 17

### Development
```bash
# Start backend services
docker compose -f docker/docker-compose.yml up -d

# Run API
cd src/DashTab.Api && dotnet run

# Run Flutter app
cd dashtab_pos && flutter run -d windows
```

## License
Proprietary - All rights reserved.
