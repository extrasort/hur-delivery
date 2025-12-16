# Wayl Payment Integration

This integration allows merchants to top up their wallets using Wayl payment gateway, supporting Visa, Mastercard, Zain Cash, Qi Card, and other payment methods.

## Setup Instructions

### 1. Environment Variables

Set the following environment variables in your Supabase project:

```bash
WAYL_MERCHANT_TOKEN=K5XpGRHx/SutpUHR1/J+xQ==:xnW683RPDcI+XHyCetQkhvyz/NnEwOFwDH/J39TX8YcxH9XCn0kRkrTrCY9+PZz09sbpXNYsCgfh+EzV2R+0ZYIK/f3Df5QEHfwjxPLBpn1LhUMEDuGoOfNuWnckHNaeuFDzXxrJ7kV8BhdBR4Dc/DbtF+1gdpobXjgsn1Eho5E=
WAYL_SECRET=K5XpGRHx/SutpUHR1/J+xQ==:xnW683RPDcI+XHyCetQkhvyz/NnEwOFwDH/J39TX8YcxH9XCn0kRkrTrCY9+PZz09sbpXNYsCgfh+EzV2R+0ZYIK/f3Df5QEHfwjxPLBpn1LhUMEDuGoOfNuWnckHNaeuFDzXxrJ7kV8BhdBR4Dc/DbtF+1gdpobXjgsn1Eho5E=
```

**Note:** In production, you should use different values for `WAYL_SECRET` if Wayl provides a separate webhook secret. For now, we're using the merchant token as the secret.

### 2. Database Migration

Run the migration to create the `pending_topups` table:

```bash
supabase migration up 20251105000000_add_wayl_payment_support
```

Or apply it manually via Supabase dashboard SQL editor.

### 3. Deploy Edge Function

Deploy the Wayl payment Edge Function:

```bash
supabase functions deploy wayl-payment
```

### 4. Webhook Setup

**Important:** According to Wayl's API documentation, the webhook URL is set **per payment link** when creating it. Our code already does this automatically by including `webhookUrl` in the link creation request.

The webhook URL format is:
```
https://YOUR_PROJECT_REF.supabase.co/functions/v1/wayl-payment/webhook
```

**No additional configuration needed in Wayl dashboard** - the webhook URL is sent with each payment link creation request.

**How it works:**
- When creating a payment link via `POST /api/v1/links`, we include `webhookUrl` in the request body
- Wayl stores this URL and calls it automatically when payment status changes
- The webhook includes a signature header `x-wayl-signature-256` for security

### 5. Testing the Integration

1. Open the app and go to Wallet screen
2. Click "شحن المحفظة" (Top Up Wallet)
3. Enter an amount
4. Select "دفع إلكتروني - Online Checkout" payment method
5. Complete the payment on Wayl's payment page
6. Verify that the wallet balance is updated after payment completion

## How It Works

1. **Create Payment Link**: When a merchant selects Wayl payment method:
   - The app calls the `wayl-payment` Edge Function
   - The function creates a payment link via Wayl API **with the webhook URL included**
   - A pending topup record is stored in the database
   - The payment URL is returned to the app

2. **Payment Processing**: 
   - User is redirected to Wayl's payment page
   - User completes payment using Visa/Mastercard/Zain Cash/Qi Card
   - User is redirected back to the app

3. **Webhook Callback**:
   - Wayl automatically sends a webhook to the URL we specified when creating the link
   - The function verifies the webhook signature using `WAYL_SECRET`
   - If payment is completed, it calls `complete_wayl_topup()` function
   - The wallet balance is updated automatically
   - A transaction record is created

## Webhook URL Configuration

The webhook URL is automatically included in each payment link creation. According to Wayl's API documentation:

- **webhookUrl**: A service endpoint that will receive the order and payment details when the payment is completed
- This URL is sent with each `POST /api/v1/links` request
- Wayl will call this URL automatically when payment status changes

**No manual configuration needed** - the webhook URL is set programmatically when creating each payment link.

## Testing with Scalar API Platform

You can test the webhook setup using Wayl's Scalar API platform at https://api.thewayl.com:

1. Go to **Links → Create a Link**
2. In the request body, include:
   ```json
   {
     "referenceId": "test123",
     "total": 1000,
     "lineItems": [{"name": "Test", "quantity": 1, "price": 1000}],
     "webhookUrl": "https://YOUR_PROJECT_REF.supabase.co/functions/v1/wayl-payment/webhook",
     "redirectionUrl": "https://your-domain.com/success"
   }
   ```
3. For testing webhooks, you can use https://webhook.site to get a temporary webhook URL first

## Database Schema

### `pending_topups` Table

Tracks pending Wayl payment links:

- `id`: Unique identifier
- `merchant_id`: Reference to merchant user
- `amount`: Top-up amount
- `wayl_reference_id`: Unique reference ID for Wayl
- `wayl_link_id`: Wayl payment link ID
- `wayl_link_url`: Payment URL
- `status`: `pending`, `completed`, `failed`, or `cancelled`
- `payment_method`: Always `wayl`
- `webhook_data`: Stores webhook payload for debugging
- `created_at`, `completed_at`, `updated_at`: Timestamps

## API Endpoints

### Create Payment Link

**Endpoint:** `POST /functions/v1/wayl-payment`

**Request Body:**
```json
{
  "merchant_id": "uuid",
  "amount": 50000,
  "notes": "Optional notes"
}
```

**Response:**
```json
{
  "success": true,
  "payment_url": "https://link.thewayl.com/pay?id=...",
  "reference_id": "hur_uuid_timestamp_random",
  "wayl_link_id": "wayl_link_id",
  "pending_topup_id": "uuid"
}
```

**Note:** The webhook URL (`https://YOUR_PROJECT_REF.supabase.co/functions/v1/wayl-payment/webhook`) is automatically included in the link creation request sent to Wayl API.

### Webhook Handler

**Endpoint:** `POST /functions/v1/wayl-payment/webhook`

**Headers:**
- `x-wayl-signature-256`: Webhook signature for verification

**Note:** This endpoint is called automatically by Wayl when payment status changes. No manual setup needed - the URL is provided when creating each link.

## Troubleshooting

### Payment link not created
- Check Edge Function logs in Supabase dashboard
- Verify `WAYL_MERCHANT_TOKEN` is set correctly
- Check Wayl API documentation for any changes

### Webhook not received
- Verify the webhook URL is accessible (try accessing it directly)
- Check Edge Function logs for incoming requests
- Ensure signature verification is working (check logs)
- Make sure the webhook URL is correctly formatted in link creation

### Wallet balance not updated
- Check `pending_topups` table for the payment status
- Verify webhook was received and processed
- Check `wallet_transactions` table for new transaction
- Review Edge Function logs for errors

## Security Notes

- Webhook signature verification is critical - never skip it
- Store `WAYL_MERCHANT_TOKEN` and `WAYL_SECRET` securely
- Use environment variables, never hardcode credentials
- Monitor webhook logs for suspicious activity

## Future Enhancements

- Add payment status polling (in case webhook fails)
- Add payment retry mechanism
- Add support for payment cancellation
- Add payment history/receipts
- Add support for multiple currencies
