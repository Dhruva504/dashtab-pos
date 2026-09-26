# DashTab POS

Commercial-grade multi-tenant Restaurant Management & POS SaaS Platform.

## Architecture (Supabase-First)

- **Supabase** — owns the platform (Auth, PostgreSQL DB, Realtime, Storage, Row Level Security).
- **ASP.NET Core (.NET 9)** — lightweight Business Logic Layer (Backend-for-Frontend) for reports, analytics, invoices, notifications, integrations, and future services.
- **Flutter** — presentation layer (Desktop, Mobile, Web), talks directly to Supabase for all operational CRUD.

```text
                    Flutter
                       │
        ┌──────────────┴──────────────┐
        │                             │
        ▼                             ▼
 Supabase SDK                    ASP.NET Core
 (Auth / DB / Realtime /        (Business Services)
  Storage / RLS)
        │                             │
        └─────────────┬───────────────┘
                      ▼
          Supabase PostgreSQL
```

## Project Structure

```
├── src/
│   ├── DashTab.Domain/          # Core business entities
│   ├── DashTab.Application/     # Business services (reports, analytics, invoices...)
│   ├── DashTab.Infrastructure/  # EF Core, data access
│   └── DashTab.Api/             # REST API, controllers, middleware
├── supabase/
│   └── migrations/              # Schema, RLS policies, seed data
├── dashtab_pos/                 # Flutter application (Supabase-first)
└── docker/                      # Docker Compose (local Postgres/Redis)
```

## Key Principles

- **Supabase owns CRUD & Auth.** Flutter interacts directly with Supabase via the SDK. No HTTP proxy for operational data.
- **ASP.NET owns business logic.** Reports, analytics, invoice generation, notifications, and forecasting run server-side.
- **RLS enforces tenant isolation.** Every business table has `tenant_id`; Row Level Security scopes all queries at the database level.
- **Backend validates Supabase JWTs.** The ASP.NET API signs requests with the Supabase JWT secret and uses `ICurrentUserService` to scope business queries to the caller's tenant.

## Getting Started

### Prerequisites
- .NET 9 SDK
- Flutter 3.x
- Docker & Docker Compose
- A Supabase project (URL, anon key, JWT secret, service-role key)

### 1. Supabase Setup
1. Create a Supabase project.
2. Run the SQL migrations in `supabase/migrations/` (schema → RLS → seed → verification).
3. Configure Auth providers (email/password).
4. Create Storage buckets for product images and invoice PDFs.
5. Note the `supabaseUrl` and `supabaseAnonKey`.

### 2. Flutter
1. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `dashtab_pos/lib/core/config/supabase_config.dart`.
2. Run:
```bash
cd dashtab_pos && flutter pub get && flutter run -d windows
```

### 3. ASP.NET Backend
1. Update `src/DashTab.Api/appsettings.json`:
   - `ConnectionStrings:DefaultConnection` → Supabase Postgres connection string.
   - `Supabase:JwtSecret` → Supabase JWT secret.
   - `Supabase:ServiceRoleKey` → Supabase service-role key (never expose to Flutter).
2. Run:
```bash
cd src/DashTab.Api && dotnet run
```

### Development (local DB)
```bash
docker compose -f docker/docker-compose.yml up -d
cd src/DashTab.Api && dotnet run
```

## Deployment
See `render.yaml` for the Render web service config. The API is deployed via Docker to Render; the Flutter app is built for your target platforms.

## License
Proprietary - All rights reserved.
