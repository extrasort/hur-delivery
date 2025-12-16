-- Migration: Fix notification types to allow order_rejected
-- This fixes the constraint violation when drivers reject orders

-- Drop the old constraint
ALTER TABLE notifications 
DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Add new constraint with order_rejected included
ALTER TABLE notifications 
ADD CONSTRAINT notifications_type_check CHECK (
  type IN (
    'order_assigned', 
    'order_accepted', 
    'order_status_update', 
    'order_delivered', 
    'order_cancelled',
    'order_rejected',  -- Added this type
    'payment', 
    'system'
  )
);

-- Add comment
COMMENT ON CONSTRAINT notifications_type_check ON notifications IS 
'Ensures notification type is one of the allowed values including order_rejected';

