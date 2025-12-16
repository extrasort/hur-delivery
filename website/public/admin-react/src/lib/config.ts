export const config = {
  // Supabase Configuration
  supabaseUrl: import.meta.env.VITE_SUPABASE_URL || 'https://bvtoxmmiitznagsbubhg.supabase.co',
  supabaseAnonKey: import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2dG94bW1paXR6bmFnc2J1YmhnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwNzk5MTcsImV4cCI6MjA2NzY1NTkxN30.WjdQh_cvOebwL0TG0bzDLZimWCLC4YuP__jtvBD_xv0',
  
  // Service Role Key (Admin Only - Set in Netlify env as VITE_SUPABASE_SERVICE_ROLE_KEY)
  // This key bypasses RLS and gives full database access
  // NEVER expose this to regular users!
  supabaseServiceRoleKey: import.meta.env.VITE_SUPABASE_SERVICE_ROLE_KEY || '',
  
  // Mapbox Configuration
  mapboxAccessToken: import.meta.env.VITE_MAPBOX_ACCESS_TOKEN || '',
  
  // App Configuration
  appName: 'حر - Hur Delivery',
  currency: 'IQD',
  currencySymbol: 'د.ع',
  
  // Features
  defaultDeliveryFee: 5000,
  orderTimeoutMinutes: 2,
  commissionRate: 0.10,
  defaultCreditLimit: -10000,
  initialWalletBalance: 10000,
  
  // Map Configuration
  defaultLatitude: 33.3152, // Baghdad
  defaultLongitude: 44.3661,
  
  // Pagination
  itemsPerPage: 20,
  
  // Refresh Intervals (milliseconds)
  dashboardRefresh: 30000, // 30 seconds
  ordersRefresh: 10000,    // 10 seconds
  realtimeEnabled: true
};

