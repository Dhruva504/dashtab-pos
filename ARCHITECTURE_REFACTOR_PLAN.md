# DashTab POS – Architecture Refactor Plan

## 1. Executive Summary

The goal of this refactor is to transition DashTab POS from a **CRUD-proxy architecture** (where ASP.NET Core sits between Flutter and Supabase for every operation) to a **Supabase-first architecture**. ASP.NET Core will be retained as a lightweight **Business Logic Layer (Backend-for-Frontend)** that handles only operations that should not run on the client — reports, analytics, invoices, notifications, integrations, and future services.

**Guiding Principle:**
- **Supabase** owns the platform (Auth, DB, Storage, Realtime, RLS).
- **ASP.NET Core** owns business logic.
- **Flutter** owns presentation.

---

## 2. Current Architecture vs Target Architecture

### Current (CRUD Proxy)

```text
Flutter
   │
   ▼
ASP.NET Core (Controllers + MediatR + EF Core + Repository)
   │
   ▼
Supabase PostgreSQL
```

### Target (Supabase-First)

```
text
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

---

## 3. Endpoint Mapping: Keep / Move / Review

### 3.1 KEEP in ASP.NET (Business Logic Layer)

These endpoints provide real business value and should remain in the backend. They aggregate data, enforce business rules, and return optimized responses.

| Endpoint | Current Status | Keep Reason |
|----------|---------------|-------------|
| `GET /api/reports/daily-sales` | ✅ Keep | Aggregation, analytics, optimized response |
| `GET /api/reports/product-sales` | ✅ Keep | Aggregation, analytics, optimized response |
| `POST /api/report/daily-sales` *(new)* | ➕ Add | Aggregated daily sales dashboard payload |
| `POST /api/report/monthly-sales` *(new)* | ➕ Add | Monthly sales aggregation |
| `POST /api/invoice` *(new)* | ➕ Add | GST invoice generation + PDF storage in Supabase Storage |
| `POST /api/analytics/dashboard` *(new)* | ➕ Add | Dashboard metrics (today's sales, avg ticket, popular products, peak hours, staff performance) |
| `POST /api/notification/send` *(new)* | ➕ Add | Notification service (WhatsApp, Email, SMS) |
| `POST /api/forecast` *(new)* | ➕ Add | Sales forecasting |
| `POST /api/sync` *(new)* | ➕ Add | Offline data sync / reconciliation |

### 3.2 MOVE to Supabase (Operational CRUD)

These endpoints are pure CRUD operations that Flutter should perform directly against Supabase.

| Endpoint | Current Status | Move Reason |
|----------|---------------|-------------|
| `POST /api/auth/login` | ❌ Remove | Supabase Auth handles login, JWT, refresh tokens, sessions |
| `GET /api/floors` | ❌ Remove | Direct Supabase query + Realtime |
| `GET /api/menu/categories` | ❌ Remove | Direct Supabase query |
| `POST /api/menu/categories` | ❌ Remove | Direct Supabase insert |
| `POST /api/menu/products` | ❌ Remove | Direct Supabase insert |
| `POST /api/orders` | ❌ Remove | Direct Supabase insert + Realtime |
| `GET /api/orders/active` | ❌ Remove | Direct Supabase query |
| `PUT /api/orders/{id}/items/{itemId}/status` | ❌ Remove | Direct Supabase update + Realtime (kitchen display) |
| `GET /api/payments/methods` | ❌ Remove | Lookup table query (cash & card) |
| `POST /api/payments` | ❌ Remove | Direct Supabase insert (records cash/card payment). **Note:** When a payment gateway is integrated (e.g., Razorpay, Stripe), a backend endpoint will be reintroduced for gateway processing. |
| `GET /api/users` | ❌ Remove | Direct Supabase query (RLS filtered) |
| `POST /api/users` | ❌ Remove | Direct Supabase insert (RLS enforced) |

### 3.3 REVIEW (Ownership Not Obvious)

| Endpoint | Analysis | Recommendation |
|----------|----------|----------------|
| `GET /api/kitchen/tickets` | Kitchen tickets are derived from `order_items` with a status field. With RLS + Realtime, Flutter can subscribe to a filtered query. Ticket number generation can be a Supabase view/trigger. | **Move to Supabase** — Create a `v_kitchen_tickets` view + Realtime subscription. This removes the CRUD proxy while maintaining real-time kitchen display updates. |

---

## 4. Supabase Responsibilities

### 4.1 Authentication
- Email/password sign-in (Supabase Auth)
- Session restoration & refresh
- JWT + refresh token management
- User profile management

### 4.2 Data (PostgreSQL)
- All business tables: `products`, `categories`, `tables`, `floors`, `orders`, `order_items`, `customers`, `employees`, `inventory`, `discounts`, `settings`, `payments`, `payment_methods`, `kitchen_ticket_view`
- Row Level Security (RLS) on every tenant-scoped table

### 4.3 Storage
- Product images
- Invoice PDFs
- Receipts

### 4.4 Realtime
- Order status changes → kitchen display
- Table status changes → floor plan
- Menu changes → POS menu

---

## 5. ASP.NET Backend Refactor

### 5.1 Remove

| File | Reason |
|------|--------|
| `Controllers/AuthController.cs` | Supabase Auth replaces custom login |
| `Controllers/FloorsController.cs` | CRUD → Supabase |
| `Controllers/MenuController.cs` | CRUD → Supabase |
| `Controllers/OrdersController.cs` | CRUD → Supabase |
| `Controllers/PaymentsController.cs` | CRUD → Supabase (reintroduce when gateway added) |
| `Controllers/UsersController.cs` | CRUD → Supabase |
| `Controllers/KitchenController.cs` | View + Realtime → Supabase |
| `Application/Features/Auth/**` | Custom JWT auth removed |
| `Application/Features/Floors/**` | CRUD removed |
| `Application/Features/Menu/**` | CRUD removed |
| `Application/Features/Orders/**` | CRUD removed |
| `Application/Features/Payments/**` | CRUD removed |
| `Application/Features/Users/**` | CRUD removed |
| `Application/Features/Kitchen/**` | CRUD removed |
| `Infrastructure/Services/JwtTokenService.cs` | Custom JWT generation removed |
| `Middleware/TenantMiddleware.cs` | RLS enforces tenant isolation (keep only for server-side service-account context) |
| `Domain/Interfaces/IRepository.cs`, `IUnitOfWork.cs` | Remove unless needed for business services |
| `Infrastructure/Data/Repositories/**` | Remove unless needed for business services |

### 5.2 Keep

| File | Reason |
|------|--------|
| `Controllers/ReportsController.cs` | Business value — aggregation |
| `Middleware/GlobalExceptionMiddleware.cs` | Error handling |
| `Infrastructure/Data/DashTabDbContext.cs` | For business-service queries (reporting) |
| `Domain/Entities/**` | Domain model for business services |

### 5.3 Add — Business Services

```
src/DashTab.Application/Services/
  InvoiceService.cs          # GST invoice generation, PDF, store in Supabase Storage
  AnalyticsService.cs        # Dashboard metrics, popular products, peak hours
  ReportService.cs           # Daily/monthly sales reports
  TaxService.cs              # GST calculation
  NotificationService.cs     # WhatsApp, Email, SMS
  IntegrationService.cs      # Payment gateways, Swiggy, Zomato, accounting, ERP
  ForecastService.cs         # Sales forecasting
  AdminService.cs            # Admin utilities
```

### 5.4 Proposed New Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/report/daily-sales` | POST | Aggregated daily sales payload |
| `/api/report/monthly-sales` | POST | Monthly sales aggregation |
| `/api/invoice` | POST | Generate GST invoice, store PDF in Supabase Storage, return URL |
| `/api/analytics/dashboard` | POST | Dashboard metrics (today's sales, avg ticket, popular products, peak hours, staff performance) |
| `/api/notification/send` | POST | Send WhatsApp/Email/SMS notifications |
| `/api/forecast` | POST | Sales forecasting |
| `/api/sync` | POST | Offline data sync / reconciliation |

### 5.5 Auth for Backend

- Remove custom JWT generation.
- Backend endpoints will be protected by **Supabase JWT validation** (using the same Supabase JWT secret) or a **service-role key** for server-to-server calls.
- Never expose the service-role key in Flutter.

---

## 6. Flutter Refactor

### 6.1 Add Supabase Dependencies

```
yaml
dependencies:
  supabase_flutter: ^2.0.0
```

### 6.2 Supabase Client Initialization

Create `lib/core/supabase/supabase_client.dart`:

```
dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class SupabaseClientProvider {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  static Supabase get client => Supabase.instance.client;
}
```

### 6.3 Dedicated Supabase Service Layer

```
lib/data/services/
  supabase_auth_service.dart      # signIn, signOut, session restore, onAuthStateChange
  supabase_product_service.dart   # CRUD products
  supabase_category_service.dart  # CRUD categories
  supabase_table_service.dart     # floors + tables + realtime
  supabase_order_service.dart     # orders + order_items + realtime
  supabase_inventory_service.dart # inventory CRUD
  supabase_customer_service.dart  # customer CRUD
  supabase_employee_service.dart  # employee CRUD
  supabase_payment_service.dart   # payment methods + record payments
  supabase_settings_service.dart  # settings CRUD
```

### 6.4 Refactored Flutter Providers

| Provider | Current (Dio → ASP.NET) | New (Supabase SDK) |
|----------|------------------------|--------------------|
| `auth_provider.dart` | `POST /auth/login` via Dio | `supabase.auth.signInWithPassword()` |
| `menu_api_provider.dart` | `GET /menu/categories` via Dio | `supabase.from('categories').select('*, products(*)')` |
| `floor_provider.dart` | `GET /floors` via Dio | `supabase.from('floors').select('*, tables(*)')` |
| `order_provider.dart` | `POST /orders` via Dio | `supabase.from('orders').insert(...)` |
| `kitchen_provider.dart` | `GET /kitchen/tickets` via Dio | `supabase.from('v_kitchen_tickets').stream(...)` |
| `payment_provider.dart` | `GET /payments/methods`, `POST /payments` | `supabase.from('payment_methods').select()` / `supabase.from('payments').insert(...)` |
| `reports_provider.dart` | `GET /reports/daily-sales` via Dio | `POST /api/report/daily-sales` via Dio (keep backend call) |

### 6.5 Real-time Subscriptions

- **Kitchen display:** Subscribe to `order_items` changes (status = sent_to_kitchen).
- **Floor plan:** Subscribe to `tables` status changes.
- **Menu:** Subscribe to `products`/`categories` changes.

---

## 7. Row Level Security (RLS) Policy Scripts

Create `supabase/migrations/` with RLS policies for every tenant-scoped table.

### 7.1 Example: Products Table

```
sql
-- Enable RLS
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Tenant isolation policy
CREATE POLICY "tenant_isolation_products" ON products
  FOR ALL
  USING (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid)
  WITH CHECK (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid);
```

### 7.2 Tables Requiring RLS

| Table | Policy |
|-------|--------|
| `products` | `tenant_id = auth.jwt()->>'tenant_id'` |
| `categories` | `tenant_id = auth.jwt()->>'tenant_id'` |
| `floors` | `tenant_id = auth.jwt()->>'tenant_id'` |
| `tables` | `tenant_id = auth.jwt()->>'tenant_id'` |
| `orders` | `tenant_id = auth.jwt()->>'tenant_id'` |
| `order_items` | `tenant_id = auth.jwt()->>'tenant_id'` |
| `customers` | `tenant_id = auth.jwt()->>'tenant_id'` |
| `employees` | `tenant_id = auth.jwt()->>'tenant_id'` |
| `inventory` | `tenant_id = auth.jwt()->>'tenant_id'` |
| `discounts` | `tenant_id = auth.jwt()->>'tenant_id'` |
| `settings` | `tenant_id = auth.jwt()->>'tenant_id'` |
| `payments` | `tenant_id = auth.jwt()->>'tenant_id'` |
| `payment_methods` | `tenant_id = auth.jwt()->>'tenant_id'` |

### 7.3 Kitchen Ticket View

```
sql
CREATE OR REPLACE VIEW v_kitchen_tickets AS
SELECT
  oi.id AS item_id,
  o.id AS order_id,
  o.order_number,
  t.name AS table_name,
  p.name AS product_name,
  oi.quantity,
  oi.notes,
  oi.status,
  oi.tenant_id
FROM order_items oi
JOIN orders o ON o.id = oi.order_id
JOIN products p ON p.id = oi.product_id
LEFT JOIN tables t ON t.id = o.table_id
WHERE oi.status IN (0, 1); -- pending, sent_to_kitchen
```

---

## 8. Migration Strategy

### Phase 1: Supabase Setup
- Initialize Supabase project.
- Create schema (tables, RLS policies, views).
- Seed payment methods (cash, card) and default settings.

### Phase 2: Flutter Auth Migration
- Add `supabase_flutter` dependency.
- Create `SupabaseClientProvider`.
- Create `SupabaseAuthService`.
- Update `AuthNotifier` to use Supabase Auth.
- Remove Dio-based auth calls.

### Phase 3: Flutter CRUD Migration
- Create Supabase service layer for products, categories, tables, orders, inventory, customers, employees, settings.
- Update providers to use Supabase services.
- Remove Dio calls for CRUD.

### Phase 4: Realtime
- Add realtime subscriptions for kitchen display, floor plan, and orders.

### Phase 5: Backend Cleanup
- Remove obsolete CRUD controllers and application features.
- Remove custom JWT auth.
- Remove tenant middleware and repository pattern (where no longer needed).

### Phase 6: Backend Business Services
- Add `InvoiceService`, `AnalyticsService`, `ReportService`, `NotificationService`, `IntegrationService`, `ForecastService`.
- Add new business endpoints.
- Protect with Supabase JWT validation.

### Phase 7: RLS Verification
- Create test users for multiple tenants.
- Verify complete tenant isolation.
- Verify service-role access works for backend operations.

### Phase 8: Testing & Deployment
- Test authentication, realtime, CRUD, reports, invoices, tenant isolation.
- Update deployment guide.
- Deploy.

---

## 9. Deployment Guide

### 9.1 Supabase
1. Create a Supabase project.
2. Run `supabase/migrations/` SQL scripts.
3. Configure Auth providers (email/password).
4. Configure Storage buckets (product images, invoices).
5. Get `supabaseUrl` and `supabaseAnonKey` for Flutter.

### 9.2 Flutter
1. Update `AppConfig` with Supabase URL and anon key.
2. Build & deploy (Android, iOS, Web, Windows).

### 9.3 ASP.NET Backend
1. Update `appsettings.json` with Supabase connection string (for business services).
2. Configure Supabase JWT validation for backend endpoints.
3. Deploy to Render (existing `render.yaml`).

---

## 10. List of All Modified Files

### Flutter
| File | Change |
|------|--------|
| `pubspec.yaml` | Add `supabase_flutter` |
| `lib/core/config/app_config.dart` | Add Supabase URL & anon key |
| `lib/core/supabase/supabase_client.dart` | **New** — Supabase client init |
| `lib/data/services/supabase_auth_service.dart` | **New** |
| `lib/data/services/supabase_product_service.dart` | **New** |
| `lib/data/services/supabase_category_service.dart` | **New** |
| `lib/data/services/supabase_table_service.dart` | **New** |
| `lib/data/services/supabase_order_service.dart` | **New** |
| `lib/data/services/supabase_inventory_service.dart` | **New** |
| `lib/data/services/supabase_customer_service.dart` | **New** |
| `lib/data/services/supabase_employee_service.dart` | **New** |
| `lib/data/services/supabase_payment_service.dart` | **New** |
| `lib/data/services/supabase_settings_service.dart` | **New** |
| `lib/features/auth/providers/auth_provider.dart` | Refactor to Supabase Auth |
| `lib/features/menu/providers/menu_api_provider.dart` | Refactor to Supabase |
| `lib/features/floor_plan/providers/floor_provider.dart` | Refactor to Supabase |
| `lib/features/pos/providers/order_provider.dart` | Refactor to Supabase |
| `lib/features/kitchen/providers/kitchen_provider.dart` | Refactor to Supabase + Realtime |
| `lib/features/payment/providers/payment_provider.dart` | Refactor to Supabase |
| `lib/features/reports/providers/reports_provider.dart` | Keep backend call (updated endpoint) |

### ASP.NET Backend
| File | Change |
|------|--------|
| `Controllers/AuthController.cs` | ❌ Remove |
| `Controllers/FloorsController.cs` | ❌ Remove |
| `Controllers/KitchenController.cs` | ❌ Remove |
| `Controllers/MenuController.cs` | ❌ Remove |
| `Controllers/OrdersController.cs` | ❌ Remove |
| `Controllers/PaymentsController.cs` | ❌ Remove |
| `Controllers/UsersController.cs` | ❌ Remove |
| `Controllers/ReportsController.cs` | ✅ Keep (expand) |
| `Controllers/ReportController.cs` | ➕ New (daily/monthly sales) |
| `Controllers/InvoiceController.cs` | ➕ New |
| `Controllers/AnalyticsController.cs` | ➕ New |
| `Controllers/NotificationController.cs` | ➕ New |
| `Controllers/ForecastController.cs` | ➕ New |
| `Controllers/SyncController.cs` | ➕ New |
| `Application/Features/Auth/**` | ❌ Remove |
| `Application/Features/Floors/**` | ❌ Remove |
| `Application/Features/Menu/**` | ❌ Remove |
| `Application/Features/Orders/**` | ❌ Remove |
| `Application/Features/Payments/**` | ❌ Remove |
| `Application/Features/Users/**` | ❌ Remove |
| `Application/Features/Kitchen/**` | ❌ Remove |
| `Application/Features/Reports/**` | ✅ Keep (expand) |
| `Application/Services/InvoiceService.cs` | ➕ New |
| `Application/Services/AnalyticsService.cs` | ➕ New |
| `Application/Services/ReportService.cs` | ➕ New |
| `Application/Services/TaxService.cs` | ➕ New |
| `Application/Services/NotificationService.cs` | ➕ New |
| `Application/Services/IntegrationService.cs` | ➕ New |
| `Application/Services/ForecastService.cs` | ➕ New |
| `Application/Services/AdminService.cs` | ➕ New |
| `Infrastructure/Services/JwtTokenService.cs` | ❌ Remove |
| `Middleware/TenantMiddleware.cs` | ❌ Remove (or repurpose) |
| `Program.cs` | Refactor auth to Supabase JWT validation |

### Supabase
| File | Change |
|------|--------|
| `supabase/migrations/001_schema.sql` | ➕ New — tables |
| `supabase/migrations/002_rls_policies.sql` | ➕ New — RLS |
| `supabase/migrations/003_views.sql` | ➕ New — kitchen ticket view |
| `supabase/migrations/004_seed.sql` | ➕ New — payment methods, settings |

---

## 11. Architecture Decision Records (ADRs)

### ADR-001: Supabase-First Architecture
**Decision:** Flutter communicates directly with Supabase for all operational CRUD, auth, storage, and realtime. ASP.NET is retained only for business logic.
**Reason:** Removes unnecessary HTTP calls, DTO mapping, serialization, and controller boilerplate. Improves performance and development speed. Supabase provides auth, RLS, realtime, and storage out of the box.

### ADR-002: Keep Reports & Analytics in ASP.NET
**Decision:** Reports, analytics, invoice generation, and notifications remain in ASP.NET.
**Reason:** These require complex aggregation, business rules, and server-side processing. Returning optimized payloads avoids executing many queries on the client.

### ADR-003: Move Authentication to Supabase Auth
**Decision:** Remove custom JWT implementation. Use Supabase Auth for login, logout, session restore, and refresh.
**Reason:** Avoids duplicating authentication logic. Supabase handles JWT, refresh tokens, sessions, and security best practices.

### ADR-004: RLS for Tenant Isolation
**Decision:** Every business table includes `tenant_id`. RLS policies enforce tenant isolation at the database level.
**Reason:** Eliminates the need for manual tenant filtering in Flutter and backend middleware. Provides defense-in-depth security.

### ADR-005: Remove Repository Pattern for CRUD
**Decision:** Remove `IRepository<T>`, `Repository<T>`, and `IUnitOfWork` for simple CRUD operations.
**Reason:** Flutter now talks directly to Supabase. The repository layer added abstraction without value. Retain only where business services need it.

### ADR-006: Kitchen Tickets via Supabase View + Realtime
**Decision:** Kitchen tickets are derived from `order_items` via a view and streamed to Flutter via Realtime.
**Reason:** Removes the CRUD proxy for kitchen display while maintaining real-time updates. Ticket number generation is handled by a Supabase trigger.

### ADR-007: Payment Recording in Supabase (for now)
**Decision:** Since payment methods are only cash and card (no gateway integration), payment recording is a direct Supabase insert.
**Reason:** It's a simple DB write. When a payment gateway (e.g., Razorpay, Stripe) is integrated, a backend endpoint will be reintroduced for gateway processing.

---

## 12. Performance & Security Goals

### Performance
- **Reduce:** HTTP calls, DTO mapping, serialization, controller boilerplate, CRUD duplication.
- **Increase:** Development speed, maintainability, readability, reliability.

### Security
- Supabase Authentication (JWT, refresh tokens).
- Row Level Security (tenant isolation).
- Secure Storage (never expose service-role keys in Flutter).
- Least-privilege access.
- Backend service accounts only when required.

---

## 13. Future Integrations (Keep in ASP.NET)

- Payment gateways (Razorpay, Stripe)
- WhatsApp
- Email
- SMS
- Printer integrations
- GST APIs
- Swiggy
- Zomato
- OpenAI
- Accounting software
- ERP integrations
- Webhook processing
- Background jobs
- Cron jobs
