# Monitor Pending Orders Edge Function

This edge function monitors pending orders and ensures they are assigned or rejected within 30 seconds.

## How It Works

1. **Checks every second** (when called via pg_cron or external scheduler)
2. **Identifies orders that need attention:**
   - Orders created >= 30 seconds ago with no driver assigned
   - Orders with `driver_assigned_at` >= 30 seconds ago (driver hasn't accepted)

3. **For orders with expired assignments:**
   - Removes the current driver from the order
   - Adds driver to rejected list (reason: 'timeout')
   - Attempts to find next available driver

4. **For unassigned orders:**
   - Calls `auto_assign_order()` to find and assign a driver
   - If no driver found, order is marked as rejected

## Setup

### 1. Deploy the Function

```bash
supabase functions deploy monitor-pending-orders
```

### 2. Set Up Scheduling

**⚠️ Note:** `pg_cron` may not be available or properly configured in your Supabase instance due to privilege restrictions. Use one of the alternatives below:

#### Option A: External Cron Service (Recommended)

Use a free service like [cron-job.org](https://cron-job.org):

1. Sign up for free
2. Create cron job:
   - **URL:** `https://YOUR_PROJECT_REF.supabase.co/functions/v1/monitor-pending-orders`
   - **Schedule:** Every 1 second
   - **Method:** POST
   - **Headers:**
     - `Authorization: Bearer YOUR_SERVICE_ROLE_KEY`
     - `Content-Type: application/json`
   - **Body:** `{}`

#### Option B: Database Trigger (Automatic)

The migration `20251104020000_add_order_monitoring_trigger.sql` creates a trigger that automatically checks pending orders when orders are created/updated. This works alongside the edge function for comprehensive coverage.

#### Option C: Application-Level Polling

Call from your Flutter app every 5 seconds:

```dart
Timer.periodic(const Duration(seconds: 5), (timer) async {
  try {
    await supabase.functions.invoke('monitor-pending-orders');
  } catch (e) {
    print('Error: $e');
  }
});
```

See `setup-alternatives.md` for more options.

### 3. Alternative: External Scheduler

If pg_cron is not available, use an external service like:
- **Cron-job.org** (free)
- **EasyCron** (free tier)
- Your own server with a cron job
- **Vercel Cron** (if using Vercel)
- **GitHub Actions** (scheduled workflows)

Example cron job:
```bash
* * * * * * curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/monitor-pending-orders \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json"
```

## Manual Testing

You can manually trigger the function:

```bash
curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/monitor-pending-orders \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json"
```

## Response Format

```json
{
  "success": true,
  "checked": 5,
  "assigned": 2,
  "rejected": 1,
  "results": [
    {
      "order_id": "uuid",
      "status": "assigned",
      "message": "Order assigned to new driver"
    }
  ],
  "timestamp": "2025-11-04T00:00:00.000Z",
  "message": "Processed 5 orders: 2 assigned, 1 rejected"
}
```

## Important Notes

1. **driver_assigned_at is always set** when `auto_assign_order()` assigns a driver
2. **30-second threshold** is enforced for both assignment and acceptance
3. **Race conditions prevented** using `FOR UPDATE SKIP LOCKED`
4. **No drivers available** → Order is automatically marked as rejected

## Monitoring

Check the Supabase Edge Function logs to monitor execution:
```bash
supabase functions logs monitor-pending-orders
```

