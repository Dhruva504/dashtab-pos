-- 011 – Branch scoping for orders, tables, floors and inventory
--
-- Each location (branch) has its own floors/tables/orders/inventory.
-- A nullable branch_id is added: NULL means "shared / legacy row" which
-- every branch can see, so pre-existing data stays visible after upgrade.

alter table public.floors
    add column if not exists branch_id uuid references public.branches(id) on delete set null;
alter table public.tables
    add column if not exists branch_id uuid references public.branches(id) on delete set null;
alter table public.orders
    add column if not exists branch_id uuid references public.branches(id) on delete set null;
alter table public.inventory
    add column if not exists branch_id uuid references public.branches(id) on delete set null;

create index if not exists idx_floors_branch   on public.floors(branch_id);
create index if not exists idx_tables_branch   on public.tables(branch_id);
create index if not exists idx_orders_branch   on public.orders(branch_id);
create index if not exists idx_inventory_branch on public.inventory(branch_id);

-- Keep updated_at ticking for the altered tables (idempotent).
drop trigger if exists trg_floors_updated on public.floors;
create trigger trg_floors_updated before update on public.floors
    for each row execute function public.set_updated_at();
drop trigger if exists trg_tables_updated on public.tables;
create trigger trg_tables_updated before update on public.tables
    for each row execute function public.set_updated_at();
drop trigger if exists trg_orders_updated on public.orders;
create trigger trg_orders_updated before update on public.orders
    for each row execute function public.set_updated_at();
drop trigger if exists trg_inventory_updated on public.inventory;
create trigger trg_inventory_updated before update on public.inventory
    for each row execute function public.set_updated_at();
