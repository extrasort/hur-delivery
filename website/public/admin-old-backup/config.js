// Admin Panel Configuration
// Instructions: Replace these with your actual Supabase credentials

const CONFIG = {
  // Supabase Configuration
  SUPABASE_URL: 'https://bvtoxmmiitznagsbubhg.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2dG94bW1paXR6bmFnc2J1YmhnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwNzk5MTcsImV4cCI6MjA2NzY1NTkxN30.WjdQh_cvOebwL0TG0bzDLZimWCLC4YuP__jtvBD_xv0',
  
  // Mapbox Configuration (Get from: https://account.mapbox.com/access-tokens/)
  MAPBOX_ACCESS_TOKEN: 'pk.eyJ1IjoibW9oYW1tZWRzYWRlcSIsImEiOiJjbWNybzlrYmQwcHo2MmtyMms5c3FheDgxIn0.H3pL2ByqWsDNllY8NuT-Hw',
  
  // App Configuration
  APP_NAME: 'حر - Hur Delivery',
  CURRENCY: 'IQD',
  CURRENCY_SYMBOL: 'د.ع',
  
  // Features
  DEFAULT_DELIVERY_FEE: 5000,
  ORDER_TIMEOUT_MINUTES: 2,
  COMMISSION_RATE: 0.10,
  DEFAULT_CREDIT_LIMIT: -10000,
  INITIAL_WALLET_BALANCE: 10000,
  
  // Map Configuration
  DEFAULT_LATITUDE: 33.3152, // Baghdad
  DEFAULT_LONGITUDE: 44.3661,
  
  // Pagination
  ITEMS_PER_PAGE: 20,
  
  // Refresh Intervals (milliseconds)
  DASHBOARD_REFRESH: 30000, // 30 seconds
  ORDERS_REFRESH: 10000,    // 10 seconds
  REALTIME_ENABLED: true
};

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
  module.exports = CONFIG;
}
