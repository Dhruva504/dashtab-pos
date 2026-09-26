-- ============================================================
-- DashTab POS – Views & Triggers (Phase 3)
-- Order number generation, kitchen ticket view, dashboard views
-- ============================================================

-- ─── Order Number Generation ─────────────────────────────────
-- Generates a sequential order number per tenant per day.
-- Format: {YYYYMMDD}-{NNN} e.g. 20250805-001
create or replace function public.generate_order_number()
returns trigger
language plpgsql
as $$
declare
    seq int;
    date_str text;
begin
    date_str := to_char(now(), 'YYYYMMDD');
    -- Count today's orders for this tenant to generate sequence
    select count(*) + 1 into seq
    from public.orders
    where tenant_id = new.tenant_id
      and created_at::date = current_date;

    new.order_number := date_str || '-' || lpad(seq::text, 3, '0');
    return new;
end;
$$;

create trigger trg_generate_order_number
    before insert on public.orders
    for each row
    when (new.order_number is null or new.order_number = '')
    execute function public.generate_order_number();

-- ─── Kitchen Ticket View ─────────────────────────────────────
-- Read-only view for kitchen display. Shows items that need
-- preparation (status = 1 = SentToKitchen).
create or replace view public.v_kitchen_tickets as
select
    oi.id as item_id,
    oi.order_id,
    o.order_number,
    o.order_type,
    t.name as table_name,
    p.name as product_name,
    oi.quantity,
    oi.notes,
    oi.status as item_status,
    oi.sent_to_kitchen_at,
    oi.tenant_id
from public.order_items oi
join public.orders o on o.id = oi.order_id
join public.products p on p.id = oi.product_id
left join public.tables t on t.id = o.table_id
where oi.status = 1 -- SentToKitchen
  and o.status not in (4, 5) -- Not Closed or Cancelled
order by oi.sent_to_kitchen_at asc;

-- ─── Active Orders View ──────────────────────────────────────
-- Shows open orders with table info for the floor plan.
create or replace view public.v_active_orders as
select
    o.id,
    o.order_number,
    o.order_type,
    o.status,
    o.table_id,
    t.name as table_name,
    o.customer_id,
    c.name as customer_name,
    o.waiter_id,
    u.full_name as waiter_name,
    o.subtotal,
    o.tax_amount,
    o.discount_amount,
    o.total,
    o.created_at,
    o.tenant_id
from public.orders o
left join public.tables t on t.id = o.table_id
left join public.customers c on c.id = o.customer_id
left join public.users u on u.id = o.waiter_id
where o.status in (0, 1, 2, 3) -- Open, SentToKitchen, PartiallyServed, Served
order by o.created_at desc;

-- ─── Daily Sales Summary View ────────────────────────────────
-- Aggregated daily sales for reports.
create or replace view public.v_daily_sales as
select
    date(closed_at) as sale_date,
    tenant_id,
    count(*) as order_count,
    coalesce(sum(total), 0) as total_revenue,
    coalesce(sum(tax_amount), 0) as total_tax,
    coalesce(sum(discount_amount), 0) as total_discounts,
    coalesce(avg(total), 0) as avg_ticket_size
from public.orders
where status in (4, 6) -- Closed or Paid
  and closed_at is not null
group by date(closed_at), tenant_id;

-- ─── Product Sales View ──────────────────────────────────────
-- Aggregated product sales for reports.
create or replace view public.v_product_sales as
select
    oi.product_id,
    oi.product_name,
    oi.tenant_id,
    count(*) as order_count,
    sum(oi.quantity) as quantity_sold,
    sum(oi.total) as total_revenue
from public.order_items oi
join public.orders o on o.id = oi.order_id
where o.status in (4, 6) -- Closed or Paid
group by oi.product_id, oi.product_name, oi.tenant_id;

-- ─── Table Status Update Trigger ─────────────────────────────
-- Automatically marks a table as occupied when an order is
-- created for it, and frees it when the order is closed.
create or replace function public.update_table_status()
returns trigger
language plpgsql
as $$
begin
    if tg_op = 'INSERT' and new.table_id is not null then
        update public.tables
        set status = 1, -- Occupied
            updated_at = now()
        where id = new.table_id;
    elsif tg_op = 'UPDATE' and new.status in (4, 5) and old.status not in (4, 5) then
        -- Order closed or cancelled - free the table
        if new.table_id is not null then
            update public.tables
            set status = 0, -- Free
                updated_at = now()
            where id = new.table_id;
        end if;
    end if;
    return new;
end;
$$;

create trigger trg_update_table_status
    after insert or update on public.orders
    for each row
    execute function public.update_table_status();