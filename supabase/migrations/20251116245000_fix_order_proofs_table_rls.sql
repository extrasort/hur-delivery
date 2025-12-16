-- Fix RLS policies for order_proofs table
-- This resolves 403 errors when drivers insert proof records after upload

-- Ensure RLS is enabled
ALTER TABLE order_proofs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to recreate them
DROP POLICY IF EXISTS "order_proofs_table_select" ON order_proofs;
DROP POLICY IF EXISTS "order_proofs_table_insert" ON order_proofs;
DROP POLICY IF EXISTS "order_proofs_table_update" ON order_proofs;
DROP POLICY IF EXISTS "order_proofs_table_delete" ON order_proofs;

-- Policy 1: SELECT - Merchants, drivers, and admins can view proof records
CREATE POLICY "order_proofs_table_select"
ON order_proofs FOR SELECT
TO authenticated
USING (
  -- Driver who uploaded it
  driver_id = auth.uid()
  OR
  -- Merchant of the order
  EXISTS (
    SELECT 1 FROM orders o
    WHERE o.id = order_proofs.order_id
      AND o.merchant_id = auth.uid()
  )
  OR
  -- Admin users
  EXISTS (
    SELECT 1 FROM users u
    WHERE u.id = auth.uid() AND u.role = 'admin'
  )
);

-- Policy 2: INSERT - Authenticated users (drivers) can insert proof records
CREATE POLICY "order_proofs_table_insert"
ON order_proofs FOR INSERT
TO authenticated
WITH CHECK (
  -- User must be authenticated
  auth.uid() IS NOT NULL
  AND
  -- Driver ID must match authenticated user
  driver_id = auth.uid()
);

-- Policy 3: UPDATE - Only the driver who uploaded can update
CREATE POLICY "order_proofs_table_update"
ON order_proofs FOR UPDATE
TO authenticated
USING (driver_id = auth.uid())
WITH CHECK (driver_id = auth.uid());

-- Policy 4: DELETE - Only admins can delete proof records
CREATE POLICY "order_proofs_table_delete"
ON order_proofs FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users u
    WHERE u.id = auth.uid() AND u.role = 'admin'
  )
);

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON order_proofs TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON order_proofs TO service_role;

COMMENT ON TABLE order_proofs IS 'Stores metadata for order proof images uploaded by drivers';

