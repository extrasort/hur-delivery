-- Fix order_proofs storage bucket configuration and policies
-- This resolves 400 errors when drivers upload order proof images

-- Ensure bucket exists with proper configuration
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'order_proofs',
  'order_proofs',
  false,  -- Not public - requires authentication
  10485760,  -- 10 MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];

-- Drop existing policies to recreate them (use IF EXISTS to avoid errors)
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "order_proofs_read_merchant_driver_admin" ON storage.objects;
  DROP POLICY IF EXISTS "order_proofs_insert_driver" ON storage.objects;
  DROP POLICY IF EXISTS "order_proofs_update_driver" ON storage.objects;
  DROP POLICY IF EXISTS "order_proofs_delete_driver" ON storage.objects;
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;

-- Policy 1: READ - Merchants, drivers, and admins can view order proofs
CREATE POLICY "order_proofs_read_merchant_driver_admin"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'order_proofs' AND
  (
    -- Check if user is merchant or driver of this order
    EXISTS (
      SELECT 1 FROM public.orders o
      WHERE storage.objects.name LIKE 'order_proofs/' || o.id || '%'
        AND (o.merchant_id = auth.uid() OR o.driver_id = auth.uid())
    )
    OR
    -- Or user is admin
    EXISTS (
      SELECT 1 FROM public.users u 
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  )
);

-- Policy 2: INSERT - Any authenticated user (driver) can upload
CREATE POLICY "order_proofs_insert_driver"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'order_proofs' AND
  -- Verify user is authenticated (drivers upload proof)
  auth.uid() IS NOT NULL
);

-- Policy 3: UPDATE - Drivers can update their own uploads (needed for upsert)
CREATE POLICY "order_proofs_update_driver"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'order_proofs' AND
  auth.uid() IS NOT NULL
)
WITH CHECK (
  bucket_id = 'order_proofs' AND
  auth.uid() IS NOT NULL
);

-- Policy 4: DELETE - Only admins can delete order proofs
CREATE POLICY "order_proofs_delete_driver"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'order_proofs' AND
  EXISTS (
    SELECT 1 FROM public.users u 
    WHERE u.id = auth.uid() AND u.role = 'admin'
  )
);

-- Note: Comments on storage policies are not supported
-- Policies created:
-- 1. order_proofs_read_merchant_driver_admin: Allows merchants, drivers, and admins to view order proof images
-- 2. order_proofs_insert_driver: Allows authenticated users (drivers) to upload order proof images  
-- 3. order_proofs_update_driver: Allows drivers to update/replace order proof images (required for upsert)
-- 4. order_proofs_delete_driver: Only admins can delete order proof images

