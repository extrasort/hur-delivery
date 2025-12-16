// Supabase configuration for the main website
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://bvtoxmmiitznagsbubhg.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2dG94bW1paXR6bmFnc2J1YmhnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwNzk5MTcsImV4cCI6MjA2NzY1NTkxN30.WjdQh_cvOebwL0TG0bzDLZimWCLC4YuP__jtvBD_xv0';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
    storageKey: 'hur-marketing-public',
  },
});

// Helper function to fetch system setting
export const getSystemSetting = async (key, defaultValue = null) => {
  try {
    const { data, error } = await supabase
      .from('system_settings')
      .select('value')
      .eq('key', key)
      .maybeSingle();
    
    if (error) {
      console.error(`Error fetching ${key}:`, error);
      return defaultValue;
    }
    
    return data?.value || defaultValue;
  } catch (error) {
    console.error(`Error fetching ${key}:`, error);
    return defaultValue;
  }
};

// Helper function to fetch support phone
export const getSupportPhone = async () => {
  return await getSystemSetting('support_phone', '+964 770 123 4567');
};

