-- ============================================================================
-- 010_realtime.sql — Enable Supabase Realtime (Postgres Changes)
--
-- The Flutter client subscribes with `from(table).stream(primaryKey: ['id'])`.
-- That only works when each table is a member of the `supabase_realtime`
-- publication; without this migration the streams never emit and clients
-- fall back to slow polling.
-- ============================================================================

-- Replica identity FULL so UPDATE/DELETE events carry the full row payload
-- (needed for streams that filter on non-PK columns and for debugging).
ALTER TABLE orders REPLICA IDENTITY FULL;
ALTER TABLE order_items REPLICA IDENTITY FULL;
ALTER TABLE tables REPLICA IDENTITY FULL;
ALTER TABLE products REPLICA IDENTITY FULL;
ALTER TABLE categories REPLICA IDENTITY FULL;
ALTER TABLE notifications REPLICA IDENTITY FULL;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'orders',
    'order_items',
    'tables',
    'products',
    'categories',
    'notifications'
  ]
  LOOP
    -- Idempotent: only add if not already in the publication.
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;
