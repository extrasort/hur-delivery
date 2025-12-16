-- =====================================================================================
-- HUR DELIVERY - CLEAN DATABASE SCRIPT
-- =====================================================================================
-- This script completely cleans the database by dropping all existing objects
-- Run this BEFORE applying the main migration if you want to start fresh
-- 
-- WARNING: THIS WILL DELETE ALL DATA!
-- 
-- IMPORTANT NOTES:
-- - PostGIS system objects are preserved (tables, views, functions)
-- - Supabase system objects are preserved (migrations tracking)
-- - All error handling is built-in (skips objects that can't be dropped)
-- - Safe to run even if PostGIS is enabled
-- =====================================================================================

-- =====================================================================================
-- 1. DISABLE ROW LEVEL SECURITY (to allow dropping)
-- =====================================================================================

DO $$ 
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT tablename 
    FROM pg_tables 
    WHERE schemaname = 'public'
      -- Exclude PostGIS system tables
      AND tablename NOT LIKE 'spatial_%'
      AND tablename NOT LIKE 'geography_%'
      AND tablename NOT LIKE 'geometry_%'
      AND tablename NOT LIKE 'raster_%'
      -- Exclude Supabase system tables
      AND tablename NOT IN ('schema_migrations', 'supabase_migrations', 'supabase_functions_migrations')
  LOOP
    BEGIN
      EXECUTE format('ALTER TABLE IF EXISTS %I DISABLE ROW LEVEL SECURITY', r.tablename);
    EXCEPTION
      WHEN insufficient_privilege THEN
        RAISE NOTICE 'Skipping table % (insufficient privileges)', r.tablename;
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not disable RLS on %: %', r.tablename, SQLERRM;
    END;
  END LOOP;
END $$;

-- =====================================================================================
-- 2. DROP ALL VIEWS
-- =====================================================================================

DROP VIEW IF EXISTS order_details CASCADE;
DROP VIEW IF EXISTS driver_stats CASCADE;
DROP VIEW IF EXISTS merchant_stats CASCADE;

-- Drop any other custom views (excluding PostGIS system views)
DO $$ 
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT table_name 
    FROM information_schema.views 
    WHERE table_schema = 'public'
      -- Exclude PostGIS system views
      AND table_name NOT IN (
        'geography_columns',
        'geometry_columns',
        'raster_columns',
        'raster_overviews',
        'spatial_ref_sys'
      )
      AND table_name NOT LIKE 'pg_%'
  LOOP
    BEGIN
      EXECUTE format('DROP VIEW IF EXISTS %I CASCADE', r.table_name);
      RAISE NOTICE 'Dropped view: %', r.table_name;
    EXCEPTION
      WHEN insufficient_privilege THEN
        RAISE NOTICE 'Skipping view % (insufficient privileges)', r.table_name;
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not drop view %: %', r.table_name, SQLERRM;
    END;
  END LOOP;
END $$;

-- =====================================================================================
-- 3. DROP ALL TRIGGERS
-- =====================================================================================

-- Drop specific triggers (with error handling for non-existent tables)
DO $$
BEGIN
  DROP TRIGGER IF EXISTS auto_assign_new_orders ON orders;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$
BEGIN
  DROP TRIGGER IF EXISTS update_users_timestamp ON users;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$
BEGIN
  DROP TRIGGER IF EXISTS update_orders_timestamp ON orders;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$
BEGIN
  DROP TRIGGER IF EXISTS update_system_settings_timestamp ON system_settings;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$
BEGIN
  DROP TRIGGER IF EXISTS audit_orders ON orders;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$
BEGIN
  DROP TRIGGER IF EXISTS audit_users ON users;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$
BEGIN
  DROP TRIGGER IF EXISTS create_earnings_trigger ON orders;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$
BEGIN
  DROP TRIGGER IF EXISTS update_users_updated_at ON users;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$
BEGIN
  DROP TRIGGER IF EXISTS update_orders_updated_at ON orders;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- Drop all remaining triggers automatically
DO $$ 
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT trigger_name, event_object_table
    FROM information_schema.triggers
    WHERE trigger_schema = 'public'
  LOOP
    BEGIN
      EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I CASCADE', r.trigger_name, r.event_object_table);
      RAISE NOTICE 'Dropped trigger: % on %', r.trigger_name, r.event_object_table;
    EXCEPTION
      WHEN undefined_table THEN
        RAISE NOTICE 'Skipping trigger % (table does not exist)', r.trigger_name;
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not drop trigger %: %', r.trigger_name, SQLERRM;
    END;
  END LOOP;
END $$;

-- =====================================================================================
-- 4. DROP ALL FUNCTIONS
-- =====================================================================================

-- Drop specific functions
DROP FUNCTION IF EXISTS find_next_available_driver(UUID, DECIMAL, DECIMAL) CASCADE;
DROP FUNCTION IF EXISTS get_ranked_available_drivers(UUID, DECIMAL, DECIMAL, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS auto_assign_order(UUID) CASCADE;
DROP FUNCTION IF EXISTS driver_accept_order(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS driver_reject_order(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS auto_reject_expired_orders() CASCADE;
DROP FUNCTION IF EXISTS repost_order_with_increased_fee(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS update_order_status(UUID, TEXT, UUID) CASCADE;
DROP FUNCTION IF EXISTS update_driver_location(UUID, DECIMAL, DECIMAL, DECIMAL, DECIMAL, DECIMAL) CASCADE;
DROP FUNCTION IF EXISTS admin_verify_user(UUID, UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS get_system_statistics() CASCADE;
DROP FUNCTION IF EXISTS cleanup_old_data() CASCADE;

-- Old functions that might exist
DROP FUNCTION IF EXISTS trigger_auto_assign_on_create() CASCADE;
DROP FUNCTION IF EXISTS trigger_update_timestamp() CASCADE;
DROP FUNCTION IF EXISTS trigger_audit_log() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS create_earnings_on_delivery() CASCADE;
DROP FUNCTION IF EXISTS update_user_online_status(UUID, BOOLEAN) CASCADE;
DROP FUNCTION IF EXISTS assign_order_to_driver(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS update_order_status(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS calculate_driver_earnings(UUID) CASCADE;
DROP FUNCTION IF EXISTS reject_order_and_reassign(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS check_and_reassign_orders() CASCADE;

-- Drop all remaining functions automatically (excluding PostGIS functions)
DO $$ 
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT routine_name, routine_schema
    FROM information_schema.routines
    WHERE routine_schema = 'public'
      AND routine_type = 'FUNCTION'
      -- Exclude PostGIS functions
      AND routine_name NOT LIKE 'st_%'
      AND routine_name NOT LIKE '_st_%'
      AND routine_name NOT LIKE 'postgis_%'
      AND routine_name NOT LIKE 'geography_%'
      AND routine_name NOT LIKE 'geometry_%'
      AND routine_name NOT LIKE 'raster_%'
      AND routine_name NOT LIKE 'box%'
      AND routine_name NOT LIKE 'gidx%'
      AND routine_name NOT LIKE 'pgis_%'
  LOOP
    BEGIN
      EXECUTE format('DROP FUNCTION IF EXISTS %I.%I CASCADE', r.routine_schema, r.routine_name);
      RAISE NOTICE 'Dropped function: %', r.routine_name;
    EXCEPTION
      WHEN insufficient_privilege THEN
        RAISE NOTICE 'Skipping function % (insufficient privileges)', r.routine_name;
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not drop function %: %', r.routine_name, SQLERRM;
    END;
  END LOOP;
END $$;

-- =====================================================================================
-- 5. DROP ALL POLICIES
-- =====================================================================================

DO $$ 
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
  LOOP
    BEGIN
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, r.schemaname, r.tablename);
      RAISE NOTICE 'Dropped policy: % on %', r.policyname, r.tablename;
    EXCEPTION
      WHEN undefined_table THEN
        RAISE NOTICE 'Skipping policy % (table does not exist)', r.policyname;
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not drop policy %: %', r.policyname, SQLERRM;
    END;
  END LOOP;
END $$;

-- =====================================================================================
-- 6. DROP ALL TABLES (in correct order to handle foreign keys)
-- =====================================================================================

-- Drop tables in order (children first)
DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS earnings CASCADE;
DROP TABLE IF EXISTS driver_locations CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS order_assignments CASCADE;
DROP TABLE IF EXISTS order_rejected_drivers CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS system_settings CASCADE;

-- Drop any remaining tables
DO $$ 
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT tablename 
    FROM pg_tables 
    WHERE schemaname = 'public'
      -- Exclude PostGIS system tables
      AND tablename NOT LIKE 'spatial_%'
      AND tablename NOT LIKE 'geography_%'
      AND tablename NOT LIKE 'geometry_%'
      AND tablename NOT LIKE 'raster_%'
      -- Exclude Supabase system tables
      AND tablename NOT IN ('schema_migrations', 'supabase_migrations', 'supabase_functions_migrations')
  LOOP
    BEGIN
      EXECUTE format('DROP TABLE IF EXISTS %I CASCADE', r.tablename);
      RAISE NOTICE 'Dropped table: %', r.tablename;
    EXCEPTION
      WHEN insufficient_privilege THEN
        RAISE NOTICE 'Skipping table % (insufficient privileges)', r.tablename;
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not drop table %: %', r.tablename, SQLERRM;
    END;
  END LOOP;
END $$;

-- =====================================================================================
-- 7. DROP ALL SEQUENCES
-- =====================================================================================

DO $$ 
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT sequence_name 
    FROM information_schema.sequences 
    WHERE sequence_schema = 'public'
  LOOP
    BEGIN
      EXECUTE format('DROP SEQUENCE IF EXISTS %I CASCADE', r.sequence_name);
      RAISE NOTICE 'Dropped sequence: %', r.sequence_name;
    EXCEPTION
      WHEN insufficient_privilege THEN
        RAISE NOTICE 'Skipping sequence % (insufficient privileges)', r.sequence_name;
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not drop sequence %: %', r.sequence_name, SQLERRM;
    END;
  END LOOP;
END $$;

-- =====================================================================================
-- 8. DROP ALL TYPES/ENUMS
-- =====================================================================================

DO $$ 
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT typname 
    FROM pg_type 
    WHERE typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
      AND typtype = 'e'
      -- Exclude PostGIS types
      AND typname NOT LIKE 'geography%'
      AND typname NOT LIKE 'geometry%'
      AND typname NOT LIKE 'raster%'
      AND typname NOT LIKE 'box%'
  LOOP
    BEGIN
      EXECUTE format('DROP TYPE IF EXISTS %I CASCADE', r.typname);
      RAISE NOTICE 'Dropped type: %', r.typname;
    EXCEPTION
      WHEN insufficient_privilege THEN
        RAISE NOTICE 'Skipping type % (insufficient privileges)', r.typname;
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not drop type %: %', r.typname, SQLERRM;
    END;
  END LOOP;
END $$;

-- =====================================================================================
-- 9. REMOVE FROM REALTIME PUBLICATION (if exists)
-- =====================================================================================

-- Remove orders from realtime publication
DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE orders;
  RAISE NOTICE 'Removed orders from realtime publication';
EXCEPTION
  WHEN undefined_object THEN 
    RAISE NOTICE 'Publication supabase_realtime does not exist';
  WHEN undefined_table THEN 
    RAISE NOTICE 'Table orders does not exist or not in publication';
  WHEN OTHERS THEN 
    RAISE NOTICE 'Could not remove orders from publication: %', SQLERRM;
END $$;

-- Remove order_assignments from realtime publication
DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE order_assignments;
  RAISE NOTICE 'Removed order_assignments from realtime publication';
EXCEPTION
  WHEN undefined_object THEN NULL;
  WHEN undefined_table THEN NULL;
  WHEN OTHERS THEN 
    RAISE NOTICE 'Could not remove order_assignments from publication: %', SQLERRM;
END $$;

-- Remove notifications from realtime publication
DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE notifications;
  RAISE NOTICE 'Removed notifications from realtime publication';
EXCEPTION
  WHEN undefined_object THEN NULL;
  WHEN undefined_table THEN NULL;
  WHEN OTHERS THEN 
    RAISE NOTICE 'Could not remove notifications from publication: %', SQLERRM;
END $$;

-- Remove driver_locations from realtime publication
DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE driver_locations;
  RAISE NOTICE 'Removed driver_locations from realtime publication';
EXCEPTION
  WHEN undefined_object THEN NULL;
  WHEN undefined_table THEN NULL;
  WHEN OTHERS THEN 
    RAISE NOTICE 'Could not remove driver_locations from publication: %', SQLERRM;
END $$;

-- Remove users from realtime publication
DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE users;
  RAISE NOTICE 'Removed users from realtime publication';
EXCEPTION
  WHEN undefined_object THEN NULL;
  WHEN undefined_table THEN NULL;
  WHEN OTHERS THEN 
    RAISE NOTICE 'Could not remove users from publication: %', SQLERRM;
END $$;

-- =====================================================================================
-- 10. DROP STORAGE BUCKETS (Optional - Uncomment if needed)
-- =====================================================================================

-- Note: This requires direct storage API calls or dashboard
-- You may need to manually delete the 'files' bucket from Supabase Dashboard

-- =====================================================================================
-- 11. CLEAN UP AUTH USERS (Optional - BE VERY CAREFUL!)
-- =====================================================================================

-- Uncomment ONLY if you want to delete all auth users
-- WARNING: This will log out all users and delete their accounts!

/*
DO $$ 
BEGIN
  -- Delete all users from auth.users (except service role)
  DELETE FROM auth.users 
  WHERE email NOT LIKE '%@supabase%';
  
  RAISE NOTICE 'All auth users deleted';
END $$;
*/

-- =====================================================================================
-- 12. RESET STORAGE SCHEMA (Optional - BE VERY CAREFUL!)
-- =====================================================================================

-- Uncomment ONLY if you want to delete all uploaded files
-- WARNING: This will delete all files in storage!

/*
DO $$ 
BEGIN
  -- Delete all objects from storage
  DELETE FROM storage.objects;
  
  -- Delete all buckets
  DELETE FROM storage.buckets WHERE name != 'supabase';
  
  RAISE NOTICE 'All storage objects and buckets deleted';
END $$;
*/

-- =====================================================================================
-- VERIFICATION
-- =====================================================================================

-- Check what's left in the database
DO $$ 
DECLARE
  table_count INTEGER;
  function_count INTEGER;
  view_count INTEGER;
  trigger_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO table_count 
  FROM pg_tables 
  WHERE schemaname = 'public' 
    -- Exclude PostGIS system tables
    AND tablename NOT LIKE 'spatial_%'
    AND tablename NOT LIKE 'geography_%'
    AND tablename NOT LIKE 'geometry_%'
    AND tablename NOT LIKE 'raster_%'
    -- Exclude Supabase system tables
    AND tablename NOT IN ('schema_migrations', 'supabase_migrations', 'supabase_functions_migrations');
  
  SELECT COUNT(*) INTO function_count 
  FROM information_schema.routines 
  WHERE routine_schema = 'public'
    -- Exclude PostGIS functions
    AND routine_name NOT LIKE 'st_%'
    AND routine_name NOT LIKE '_st_%'
    AND routine_name NOT LIKE 'postgis_%';
  
  SELECT COUNT(*) INTO view_count 
  FROM information_schema.views 
  WHERE table_schema = 'public'
    -- Exclude PostGIS views
    AND table_name NOT LIKE 'geography_%'
    AND table_name NOT LIKE 'geometry_%';
  
  SELECT COUNT(*) INTO trigger_count
  FROM information_schema.triggers
  WHERE trigger_schema = 'public';
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'DATABASE CLEANUP COMPLETED';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Remaining application objects:';
  RAISE NOTICE '  - Tables: %', table_count;
  RAISE NOTICE '  - Functions: %', function_count;
  RAISE NOTICE '  - Views: %', view_count;
  RAISE NOTICE '  - Triggers: %', trigger_count;
  RAISE NOTICE '';
  RAISE NOTICE 'Note: PostGIS system objects are preserved.';
  RAISE NOTICE '';
  
  IF table_count = 0 AND function_count = 0 AND view_count = 0 AND trigger_count = 0 THEN
    RAISE NOTICE '✅ Database is completely clean!';
    RAISE NOTICE 'You can now run the main migration.';
  ELSE
    RAISE NOTICE '⚠️  Some objects remain. Check manually if needed.';
  END IF;
  
  RAISE NOTICE '========================================';
END $$;

-- Show remaining tables (if any)
SELECT 
  'Remaining Table: ' || tablename as info
FROM pg_tables 
WHERE schemaname = 'public'
  -- Exclude PostGIS system tables
  AND tablename NOT LIKE 'spatial_%'
  AND tablename NOT LIKE 'geography_%'
  AND tablename NOT LIKE 'geometry_%'
  AND tablename NOT LIKE 'raster_%'
  -- Exclude Supabase system tables
  AND tablename NOT IN ('schema_migrations', 'supabase_migrations', 'supabase_functions_migrations');

-- Show remaining functions (if any)
SELECT 
  'Remaining Function: ' || routine_name as info
FROM information_schema.routines 
WHERE routine_schema = 'public'
  -- Exclude PostGIS functions
  AND routine_name NOT LIKE 'st_%'
  AND routine_name NOT LIKE '_st_%'
  AND routine_name NOT LIKE 'postgis_%';

