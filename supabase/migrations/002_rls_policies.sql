-- ============================================================
-- DashTab POS – Row Level Security Policies (Phase 3)
-- Tenant isolation via auth.jwt()->>'tenant_id'
-- ============================================================

-- Enable RLS on all business tables
alter table public.tenants        enable row level security;
alter table public.users          enable row level security;
alter table public.categories     enable row level security;
alter table public.products       enable row level security;
alter table public.floors         enable row level security;
alter table public.tables         enable row level security;
alter table public.customers      enable row level security;
alter table public.orders         enable row level security;
alter table public.order_items    enable row level security;
alter table public.payment_methods enable row level security;
alter table public.payments       enable row level security;
alter table public.inventory      enable row level security;
alter table public.discounts      enable row level security;
alter table public.audit_logs     enable row level security;
alter table public.tax_rates      enable row level security;

-- ─── Helper function to get current tenant_id from JWT ───────
-- SAFE: Returns NULL when the JWT has no tenant_id claim.
-- RLS policies then match `tenant_id = NULL` (no rows), so a user
-- without a tenant_id claim cannot see or modify any tenant's data.
-- The old fallback (auth.jwt()->>'sub') was a SECURITY BUG: it treated
-- a user's own id as their tenant_id, potentially exposing data.
--
-- tenant_id is stored in app_metadata (which Supabase includes in the JWT).
-- It may appear at the top level OR nested under app_metadata. We check both.
create or replace function public.current_tenant_id()
returns uuid
language sql stable
as $$
    select coalesce(
        nullif(auth.jwt()->>'tenant_id', '')::uuid,
        nullif(auth.jwt() -> 'app_metadata' ->> 'tenant_id', '')::uuid
    );
$$;

-- ─── Tenants ─────────────────────────────────────────────────
-- Users can read their own tenant row
create policy "tenant_select_own" on public.tenants
    for select using (id = public.current_tenant_id());

-- ─── Users ───────────────────────────────────────────────────
create policy "users_select_own_tenant" on public.users
    for select using (tenant_id = public.current_tenant_id());

create policy "users_insert_own_tenant" on public.users
    for insert with check (tenant_id = public.current_tenant_id());

create policy "users_update_own_tenant" on public.users
    for update using (tenant_id = public.current_tenant_id());

create policy "users_delete_own_tenant" on public.users
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Categories ──────────────────────────────────────────────
create policy "categories_select" on public.categories
    for select using (tenant_id = public.current_tenant_id());

create policy "categories_insert" on public.categories
    for insert with check (tenant_id = public.current_tenant_id());

create policy "categories_update" on public.categories
    for update using (tenant_id = public.current_tenant_id());

create policy "categories_delete" on public.categories
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Products ────────────────────────────────────────────────
create policy "products_select" on public.products
    for select using (tenant_id = public.current_tenant_id());

create policy "products_insert" on public.products
    for insert with check (tenant_id = public.current_tenant_id());

create policy "products_update" on public.products
    for update using (tenant_id = public.current_tenant_id());

create policy "products_delete" on public.products
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Floors ──────────────────────────────────────────────────
create policy "floors_select" on public.floors
    for select using (tenant_id = public.current_tenant_id());

create policy "floors_insert" on public.floors
    for insert with check (tenant_id = public.current_tenant_id());

create policy "floors_update" on public.floors
    for update using (tenant_id = public.current_tenant_id());

create policy "floors_delete" on public.floors
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Tables ──────────────────────────────────────────────────
create policy "tables_select" on public.tables
    for select using (tenant_id = public.current_tenant_id());

create policy "tables_insert" on public.tables
    for insert with check (tenant_id = public.current_tenant_id());

create policy "tables_update" on public.tables
    for update using (tenant_id = public.current_tenant_id());

create policy "tables_delete" on public.tables
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Customers ───────────────────────────────────────────────
create policy "customers_select" on public.customers
    for select using (tenant_id = public.current_tenant_id());

create policy "customers_insert" on public.customers
    for insert with check (tenant_id = public.current_tenant_id());

create policy "customers_update" on public.customers
    for update using (tenant_id = public.current_tenant_id());

create policy "customers_delete" on public.customers
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Orders ──────────────────────────────────────────────────
create policy "orders_select" on public.orders
    for select using (tenant_id = public.current_tenant_id());

create policy "orders_insert" on public.orders
    for insert with check (tenant_id = public.current_tenant_id());

create policy "orders_update" on public.orders
    for update using (tenant_id = public.current_tenant_id());

create policy "orders_delete" on public.orders
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Order Items ─────────────────────────────────────────────
create policy "order_items_select" on public.order_items
    for select using (tenant_id = public.current_tenant_id());

create policy "order_items_insert" on public.order_items
    for insert with check (tenant_id = public.current_tenant_id());

create policy "order_items_update" on public.order_items
    for update using (tenant_id = public.current_tenant_id());

create policy "order_items_delete" on public.order_items
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Payment Methods ─────────────────────────────────────────
create policy "payment_methods_select" on public.payment_methods
    for select using (tenant_id = public.current_tenant_id());

create policy "payment_methods_insert" on public.payment_methods
    for insert with check (tenant_id = public.current_tenant_id());

create policy "payment_methods_update" on public.payment_methods
    for update using (tenant_id = public.current_tenant_id());

create policy "payment_methods_delete" on public.payment_methods
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Payments ────────────────────────────────────────────────
create policy "payments_select" on public.payments
    for select using (tenant_id = public.current_tenant_id());

create policy "payments_insert" on public.payments
    for insert with check (tenant_id = public.current_tenant_id());

create policy "payments_update" on public.payments
    for update using (tenant_id = public.current_tenant_id());

create policy "payments_delete" on public.payments
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Inventory ───────────────────────────────────────────────
create policy "inventory_select" on public.inventory
    for select using (tenant_id = public.current_tenant_id());

create policy "inventory_insert" on public.inventory
    for insert with check (tenant_id = public.current_tenant_id());

create policy "inventory_update" on public.inventory
    for update using (tenant_id = public.current_tenant_id());

create policy "inventory_delete" on public.inventory
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Discounts ───────────────────────────────────────────────
create policy "discounts_select" on public.discounts
    for select using (tenant_id = public.current_tenant_id());

create policy "discounts_insert" on public.discounts
    for insert with check (tenant_id = public.current_tenant_id());

create policy "discounts_update" on public.discounts
    for update using (tenant_id = public.current_tenant_id());

create policy "discounts_delete" on public.discounts
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Tax Rates ───────────────────────────────────────────────
create policy "tax_rates_select" on public.tax_rates
    for select using (tenant_id = public.current_tenant_id());

create policy "tax_rates_insert" on public.tax_rates
    for insert with check (tenant_id = public.current_tenant_id());

create policy "tax_rates_update" on public.tax_rates
    for update using (tenant_id = public.current_tenant_id());

create policy "tax_rates_delete" on public.tax_rates
    for delete using (tenant_id = public.current_tenant_id());

-- ─── Audit Logs (insert-only from app) ───────────────────────
create policy "audit_logs_insert" on public.audit_logs
    for insert with check (tenant_id = public.current_tenant_id());

create policy "audit_logs_select" on public.audit_logs
    for select using (tenant_id = public.current_tenant_id());

-- ─── Kitchen ticket view (derived, read-only) ────────────────
create or replace view public.kitchen_tickets as
select
    oi.id as order_item_id,
    oi.order_id,
    oi.product_id,
    oi.product_name,
    oi.quantity,
    oi.notes,
    oi.status as item_status,
    oi.sent_to_kitchen_at,
    o.order_number,
    o.status as order_status,
    o.table_id,
    t.name as table_name,
    o.tenant_id
from public.order_items oi
join public.orders o on o.id = oi.order_id
left join public.tables t on t.id = o.table_id
where oi.status = 1; -- SentToKitchen

-- ─── Inventory adjustment function ───────────────────────────
create or replace function public.adjust_inventory(
    p_item_id uuid,
    p_quantity numeric
)
returns void
language plpgsql
security definer
as $$
begin
    update public.inventory
    set quantity = quantity + p_quantity,
        updated_at = now()
    where id = p_item_id
      and tenant_id = public.current_tenant_id();
end;
$$;

-- ─── Auto-set tenant_id on insert (from JWT) ─────────────────
-- Only sets tenant_id if not already provided (e.g., service-role
-- operations can explicitly set tenant_id for seeding).
create or replace function public.set_tenant_id()
returns trigger
language plpgsql
as $$
begin
    if new.tenant_id is null then
        new.tenant_id := public.current_tenant_id();
    end if;
    return new;
end;
$$;

-- Apply auto tenant_id trigger to business tables
create trigger trg_set_tenant_categories before insert on public.categories
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_products before insert on public.products
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_floors before insert on public.floors
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_tables before insert on public.tables
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_customers before insert on public.customers
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_orders before insert on public.orders
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_order_items before insert on public.order_items
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_payments before insert on public.payments
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_inventory before insert on public.inventory
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_payment_methods before insert on public.payment_methods
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_discounts before insert on public.discounts
    for each row execute function public.set_tenant_id();
create trigger trg_set_tenant_users before insert on public.users
    for each row execute function public.set_tenant_id();
