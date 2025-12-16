-- Add 'order_on_the_way' to allowed notification types
-- This fixes the check constraint violation when drivers mark orders as "on the way"

BEGIN;

-- Drop the old constraint
ALTER TABLE notifications 
DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Add new constraint with order_on_the_way included
ALTER TABLE notifications 
ADD CONSTRAINT notifications_type_check CHECK (
  type IN (
    'order_assigned', 
    'order_accepted', 
    'order_status_update',
    'order_on_the_way',  -- Added this missing type
    'order_delivered', 
    'order_cancelled',
    'order_rejected',
    'payment', 
    'system',
    'message'
  )
);

-- Add comment
COMMENT ON CONSTRAINT notifications_type_check ON notifications IS 
'Ensures notification type is one of the allowed values including order_on_the_way';

COMMIT;

