import { create } from 'zustand';
import { supabase, type User } from '../lib/supabase-admin';
import type { Session } from '@supabase/supabase-js';

interface AuthState {
  session: Session | null;
  user: User | null;
  loading: boolean;
  isAdmin: boolean;
  setSession: (session: Session | null) => void;
  setUser: (user: User | null) => void;
  setLoading: (loading: boolean) => void;
  signIn: (username: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
  checkAuth: () => Promise<void>;
}

export const useAuthStore = create<AuthState>((set, get) => ({
  session: null,
  user: null,
  loading: true,
  isAdmin: false,

  setSession: (session) => set({ session }),
  
  setUser: (user) => set({ 
    user, 
    isAdmin: user?.role === 'admin' 
  }),
  
  setLoading: (loading) => set({ loading }),

  signIn: async (username: string, password: string) => {
    set({ loading: true });
    try {
      // Call the admin-login Edge Function
      const { data, error } = await supabase.functions.invoke('admin-login', {
        body: { username, password },
      });

      if (error) throw error;
      if (!data?.success) throw new Error(data?.error || 'Login failed');

      // Set the session from the Edge Function response
      const { session: sessionData, user: userData } = data;
      
      if (sessionData?.access_token) {
        // Set the session in Supabase client
        const { data: sessionResult, error: sessionError } = await supabase.auth.setSession({
          access_token: sessionData.access_token,
          refresh_token: sessionData.refresh_token,
        });

        if (sessionError) throw sessionError;

        set({ 
          session: sessionResult.session,
          user: userData as User,
          isAdmin: true,
        });

        // Store session in localStorage for persistence
        localStorage.setItem('hur_admin_session', JSON.stringify(sessionData));
        localStorage.setItem('hur_admin_user', JSON.stringify(userData));
      } else {
        throw new Error('Invalid session data received');
      }
    } catch (error: any) {
      console.error('Sign in error:', error);
      throw error;
    } finally {
      set({ loading: false });
    }
  },

  signOut: async () => {
    await supabase.auth.signOut();
    localStorage.removeItem('hur_admin_session');
    localStorage.removeItem('hur_admin_user');
    set({ session: null, user: null, isAdmin: false });
  },

  checkAuth: async () => {
    set({ loading: true });
    try {
      // Try to restore from localStorage first
      const storedSession = localStorage.getItem('hur_admin_session');
      const storedUser = localStorage.getItem('hur_admin_user');

      if (storedSession && storedUser) {
        const sessionData = JSON.parse(storedSession);
        const userData = JSON.parse(storedUser);

        // Set the session in Supabase client
        const { data: sessionResult, error: sessionError } = await supabase.auth.setSession({
          access_token: sessionData.access_token,
          refresh_token: sessionData.refresh_token,
        });

        if (!sessionError && sessionResult.session) {
          set({ 
            session: sessionResult.session,
            user: userData as User,
            isAdmin: userData.role === 'admin',
          });
          return;
        }
      }

      // Fallback: check current session
      const { data: { session } } = await supabase.auth.getSession();
      
      if (session) {
        // Fetch user details
        const { data: userData, error: userError } = await supabase
          .from('users')
          .select('*')
          .eq('id', session.user.id)
          .single();

        if (!userError && userData?.role === 'admin') {
          set({ 
            session,
            user: userData,
            isAdmin: true,
          });
          return;
        }
      }

      // No valid session found
      await get().signOut();
    } catch (error) {
      console.error('Auth check error:', error);
      await get().signOut();
    } finally {
      set({ loading: false });
    }
  },
}));

// Subscribe to auth changes
supabase.auth.onAuthStateChange((_event, session) => {
  useAuthStore.getState().setSession(session);
});

