// Admin Panel Configuration - EXAMPLE FILE
// Copy this file to config.js and fill in your actual credentials

const CONFIG = {
  // ==========================================
  // SUPABASE CONFIGURATION - REQUIRED
  // ==========================================
  // Get these from: Supabase Dashboard > Settings > API
  
  SUPABASE_URL: 'https://your-project-ref.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.your-anon-key-here',
  
  // ==========================================
  // APP CONFIGURATION
  // ==========================================
  APP_NAME: 'حر - Hur Delivery',
  CURRENCY: 'IQD',
  CURRENCY_SYMBOL: 'د.ع',
  
  // ==========================================
  // BUSINESS RULES
  // ==========================================
  // Default delivery fee (in IQD)
  DEFAULT_DELIVERY_FEE: 5000,
  
  // Order timeout in minutes before auto-reject
  ORDER_TIMEOUT_MINUTES: 2,
  
  // Commission rate (10% = 0.10)
  COMMISSION_RATE: 0.10,
  
  // Merchant wallet credit limit (negative balance allowed)
  DEFAULT_CREDIT_LIMIT: -10000,
  
  // Initial wallet balance for new merchants (gift)
  INITIAL_WALLET_BALANCE: 10000,
  
  // ==========================================
  // MAP CONFIGURATION
  // ==========================================
  // Default map center (Baghdad coordinates)
  DEFAULT_LATITUDE: 33.3152,
  DEFAULT_LONGITUDE: 44.3661,
  
  // ==========================================
  // PAGINATION & UI
  // ==========================================
  // Number of items to show per page
  ITEMS_PER_PAGE: 20,
  
  // ==========================================
  // REFRESH INTERVALS
  // ==========================================
  // How often to refresh dashboard (in milliseconds)
  DASHBOARD_REFRESH: 30000, // 30 seconds
  
  // How often to refresh orders page
  ORDERS_REFRESH: 10000,    // 10 seconds
  
  // Enable/disable realtime subscriptions
  REALTIME_ENABLED: true,
  
  // ==========================================
  // ADVANCED SETTINGS
  // ==========================================
  // Enable debug mode (shows console logs)
  DEBUG_MODE: false,
  
  // Maximum file size for uploads (in bytes)
  MAX_UPLOAD_SIZE: 5242880, // 5MB
  
  // Supported languages (for future expansion)
  SUPPORTED_LANGUAGES: ['ar', 'en'],
  
  // Default language
  DEFAULT_LANGUAGE: 'ar',
};

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
  module.exports = CONFIG;
}

// ==========================================
// SETUP INSTRUCTIONS
// ==========================================
/*
1. Copy this file to config.js:
   cp config.example.js config.js

2. Get your Supabase credentials:
   - Go to https://app.supabase.com
   - Select your project
   - Go to Settings > API
   - Copy "Project URL" and "anon/public key"

3. Replace SUPABASE_URL and SUPABASE_ANON_KEY above

4. Adjust other settings as needed

5. Never commit config.js to Git (it's in .gitignore)

6. For production, ensure:
   - REALTIME_ENABLED is true
   - DEBUG_MODE is false
   - Using HTTPS
   - RLS policies are enabled
*/
