-- 012 – Make historical references not block deletes (robust version)
--
-- Several foreign keys had no ON DELETE action, so deleting a product,
-- table, customer, staff member or tax rate that appeared in any past
-- order/notification was rejected by the database while the app showed
-- "deleted". Records keep their name snapshots, so SET NULL preserves
-- history: order_items keep product_name, orders keep the table/customer
-- name in text columns.
--
-- Safe to re-run. For each (table, column, referenced table):
--   * skipped when the column doesn't exist in this database
--   * every existing FK on that column pointing at the same table is
--     dropped by its real name (found from pg_constraint)
--   * the delete-friendly FK is (re)created

do $$
declare
    rec record;
    fk record;
begin
    for rec in
        select * from (values
            ('order_items', 'product_id',  'products'),
            ('orders',      'table_id',    'tables'),
            ('orders',      'customer_id', 'customers'),
            ('orders',      'waiter_id',   'users'),
            ('products',    'tax_rate_id', 'tax_rates')
        ) as t(tbl, col, ref)
    loop
        -- Skip tables/columns that don't exist in this database.
        if not exists (
            select 1 from information_schema.columns
            where table_schema = 'public'
              and table_name = rec.tbl
              and column_name = rec.col
        ) then
            raise notice 'Skipping %.% (column missing)', rec.tbl, rec.col;
            continue;
        end if;

        -- Drop every existing FK on this column referencing the same table,
        -- whatever it happens to be named.
        for fk in
            select con.conname
            from pg_constraint con
            join pg_attribute att
              on att.attrelid = con.conrelid
             and att.attnum = any (con.conkey)
            where con.conrelid = format('public.%I', rec.tbl)::regclass
              and con.contype = 'f'
              and con.confrelid = format('public.%I', rec.ref)::regclass
              and att.attname = rec.col
        loop
            execute format(
                'alter table public.%I drop constraint %I',
                rec.tbl, fk.conname
            );
            raise notice 'Dropped %', fk.conname;
        end loop;

        execute format(
            'alter table public.%I add constraint %I_fkey
             foreign key (%I) references public.%I(id)
             on delete set null',
            rec.tbl,
            rec.tbl || '_' || rec.col,
            rec.col,
            rec.ref
        );
        raise notice 'Added %.% -> %( on delete set null)',
            rec.tbl, rec.col, rec.ref;
    end loop;
end $$;
