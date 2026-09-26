-- ============================================================================
-- 014_realtime_multiuser.sql — Extend Realtime to all multi-user tables
--
-- Migration 010 covered the original hot tables (orders, order_items, tables,
-- products, categories, notifications). The app now also live-syncs the
-- remaining shared entities: loyalty/history (customers), stock (inventory),
-- promos (discounts), gift-card balances (gift_cards), the floor plan
-- (floors), purchasing (purchase_orders), suppliers, and the shared activity
-- feed (audit_logs). Without publication membership those streams never
-- emit and terminals fall back to the 8s poll — realtime is the primary
-- path, polling only the safety net.
--
-- Run this in the Supabase SQL editor (idempotent — safe to re-run).
-- ============================================================================

-- FULL replica identity so UPDATE/DELETE events carry the whole row.
ALTER TABLE customers REPLICA IDENTITY FULL;
ALTER TABLE inventory REPLICA IDENTITY FULL;
ALTER TABLE discounts REPLICA IDENTITY FULL;
ALTER TABLE gift_cards REPLICA IDENTITY FULL;
ALTER TABLE floors REPLICA IDENTITY FULL;
ALTER TABLE purchase_orders REPLICA IDENTITY FULL;
ALTER TABLE suppliers REPLICA IDENTITY FULL;
ALTER TABLE audit_logs REPLICA IDENTITY FULL;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'customers',
    'inventory',
    'discounts',
    'gift_cards',
    'floors',
    'purchase_orders',
    'suppliers',
    'audit_logs',
    -- Re-check the originals too, in case 010 was skipped.
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
