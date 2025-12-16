import { createClient } from '@supabase/supabase-js';
import { config } from './config';

/**
 * Supabase Client for Admin Panel
 * Uses RLS policies to grant admin access based on user role
 * Admin users are identified via auth.uid() in the session
 */
export const supabase = createClient(
  config.supabaseUrl,
  config.supabaseAnonKey,
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      storageKey: 'hur-admin-auth',
    },
  }
);

// Alias for backward compatibility during migration
export const supabaseAdmin = supabase;

// Export types
export * from './supabase';

