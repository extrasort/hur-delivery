# Auto-Reject Orders Edge Function

This Supabase Edge Function automatically rejects orders that have timed out (30 seconds without driver response) and reassigns them to the next available driver.

## Setup

### 1. Deploy the Function

```bash
supabase functions deploy auto-reject-orders
```

### 2. Set up Scheduled Execution

You need to call this function every 5 seconds. Here are your options:

#### Option A: External Cron Service (Recommended for Production)

Use a service like **Cron-job.org** (free):

1. Go to https://cron-job.org
2. Create a free account
3. Create a new cron job:
   - **URL:** `https://YOUR_PROJECT_REF.supabase.co/functions/v1/auto-reject-orders`
   - **Schedule:** Every 5 seconds (configure custom interval)
   - **Method:** POST
   - **Headers:** 
     - `Authorization: Bearer YOUR_ANON_KEY`
     - `Content-Type: application/json`

#### Option B: Your Own Server

If you have a server with crontab access:

```bash
# Add to crontab (runs every 5 seconds)
* * * * * curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/auto-reject-orders -H "Authorization: Bearer YOUR_ANON_KEY"
* * * * * sleep 5; curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/auto-reject-orders -H "Authorization: Bearer YOUR_ANON_KEY"
* * * * * sleep 10; curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/auto-reject-orders -H "Authorization: Bearer YOUR_ANON_KEY"
* * * * * sleep 15; curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/auto-reject-orders -H "Authorization: Bearer YOUR_ANON_KEY"
* * * * * sleep 20; curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/auto-reject-orders -H "Authorization: Bearer YOUR_ANON_KEY"
* * * * * sleep 25; curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/auto-reject-orders -H "Authorization: Bearer YOUR_ANON_KEY"
* * * * * sleep 30; curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/auto-reject-orders -H "Authorization: Bearer YOUR_ANON_KEY"
* * * * * sleep 35; curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/auto-reject-orders -H "Authorization: Bearer YOUR_ANON_KEY"
* * * * * sleep 40; curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/auto-reject-orders -H "Authorization: Bearer YOUR_ANON_KEY"
* * * * * sleep 45; curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/auto-reject-orders -H "Authorization: Bearer YOUR_ANON_KEY"
* * * * * sleep 50; curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/auto-reject-orders -H "Authorization: Bearer YOUR_ANON_KEY"
* * * * * sleep 55; curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/auto-reject-orders -H "Authorization: Bearer YOUR_ANON_KEY"
```

#### Option C: GitHub Actions (Free)

Create `.github/workflows/auto-reject.yml`:

```yaml
name: Auto-Reject Expired Orders

on:
  schedule:
    # Runs every minute (GitHub Actions doesn't support sub-minute intervals)
    - cron: '* * * * *'
  workflow_dispatch:

jobs:
  auto-reject:
    runs-on: ubuntu-latest
    steps:
      - name: Call Edge Function (12 times with 5 second intervals)
        run: |
          for i in {1..12}; do
            curl -X POST \
              https://${{ secrets.SUPABASE_PROJECT_REF }}.supabase.co/functions/v1/auto-reject-orders \
              -H "Authorization: Bearer ${{ secrets.SUPABASE_ANON_KEY }}" \
              -H "Content-Type: application/json"
            
            if [ $i -lt 12 ]; then
              sleep 5
            fi
          done
```

Add these secrets to your GitHub repository:
- `SUPABASE_PROJECT_REF`: Your Supabase project reference
- `SUPABASE_ANON_KEY`: Your Supabase anon key

## Testing

### Manual Test

```bash
curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/auto-reject-orders \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json"
```

Expected response:
```json
{
  "success": true,
  "rejectedCount": 0,
  "timestamp": "2025-09-30T12:00:00.000Z",
  "message": "Successfully processed 0 expired orders"
}
```

### Create a Test Timeout

```sql
-- Create an order and assign to a driver
INSERT INTO orders (merchant_id, customer_name, customer_phone, ...)
VALUES (...);

-- Manually set the assigned_at to 35 seconds ago
UPDATE orders
SET driver_assigned_at = NOW() - INTERVAL '35 seconds'
WHERE id = 'your-order-id';

-- Call the function (it should auto-reject this order)
SELECT auto_reject_expired_orders();
```

## Monitoring

### View Logs

```bash
supabase functions logs auto-reject-orders
```

### Check Function Status

```bash
supabase functions list
```

## Troubleshooting

### Function not running

1. Check deployment:
   ```bash
   supabase functions list
   ```

2. Check logs:
   ```bash
   supabase functions logs auto-reject-orders --tail
   ```

3. Test manually:
   ```bash
   curl -X POST https://YOUR_PROJECT_REF.supabase.co/functions/v1/auto-reject-orders \
     -H "Authorization: Bearer YOUR_ANON_KEY"
   ```

### Permission errors

Make sure you're using the `SUPABASE_SERVICE_ROLE_KEY` in the function (it's automatically available as an environment variable).

### Database function errors

Check if the database function exists:
```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_name = 'auto_reject_expired_orders';
```

## Performance

- **Execution time:** ~100-500ms depending on number of expired orders
- **Cost:** Supabase Edge Functions are free for up to 500,000 invocations/month
- **At 5-second intervals:** ~518,400 invocations/month (within free tier!)

## Security

- Function uses service role key (full access)
- CORS enabled for all origins (function is idempotent and safe)
- All database operations use RLS policies

## Notes

- The function is idempotent (safe to call multiple times)
- It only processes orders that are truly expired (>30 seconds)
- Each rejected driver is tracked to prevent reassignment
- The function automatically tries to find the next available driver

