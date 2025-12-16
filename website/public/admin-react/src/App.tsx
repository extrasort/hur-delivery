import { useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { useAuthStore } from './store/authStore';
import Login from './pages/Login';
import MainLayout from './components/Layout/MainLayout';
import Dashboard from './pages/Dashboard';

// Placeholder pages (will be built next)
import Users from './pages/Users';
import Orders from './pages/Orders';
import Drivers from './pages/Drivers';
import Merchants from './pages/Merchants';
import Wallets from './pages/Wallets';
import Earnings from './pages/Earnings';
import Notifications from './pages/Notifications';
import Verification from './pages/Verification';
import Tracking from './pages/Tracking';
import Emergency from './pages/Emergency';
import Messaging from './pages/Messaging';
import Announcements from './pages/Announcements';
import Settings from './pages/Settings';

const ADMIN_BASE_PATH = '/admin';

const determineRouterBasename = () => {
  const configured = import.meta.env.VITE_ROUTER_BASENAME?.trim();
  if (configured) return configured;

  if (typeof window === 'undefined') {
    return '/';
  }

  const host = window.location.hostname.toLowerCase();
  const path = window.location.pathname;

  // If accessing via admin subdomain, use root basename
  if (host === 'admin.hur.delivery' || host.endsWith('.admin.hur.delivery')) {
    // If path starts with /admin, normalize it (remove /admin prefix)
    if (path === '/admin' || path.startsWith('/admin/')) {
      const normalizedPath = path.replace(/^\/admin/, '') || '/';
      // Only update if path actually changed
      if (normalizedPath !== path) {
        window.history.replaceState({}, '', normalizedPath + window.location.search + window.location.hash);
      }
    }
    return '/';
  }

  // If accessing via main domain with /admin path, use /admin basename
  if (path === ADMIN_BASE_PATH || path.startsWith(`${ADMIN_BASE_PATH}/`)) {
    return ADMIN_BASE_PATH;
  }

  return '/';
};

function App() {
  const { checkAuth, loading, isAdmin } = useAuthStore();
  const basename = determineRouterBasename();

  useEffect(() => {
    checkAuth();
  }, [checkAuth]);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-16 w-16 border-b-2 border-primary-500 mx-auto mb-4"></div>
          <p className="text-gray-600">جاري التحميل... / Loading...</p>
        </div>
      </div>
    );
  }

  return (
    <BrowserRouter basename={basename}>
      <Routes>
        <Route path="/login" element={!isAdmin ? <Login /> : <Navigate to="/" replace />} />
        
        <Route element={isAdmin ? <MainLayout /> : <Navigate to="/login" replace />}>
          <Route index element={<Dashboard />} />
          <Route path="users" element={<Users />} />
          <Route path="orders" element={<Orders />} />
          <Route path="drivers" element={<Drivers />} />
          <Route path="drivers/:id" element={<Drivers />} />
          <Route path="merchants" element={<Merchants />} />
          <Route path="wallets" element={<Wallets />} />
          <Route path="earnings" element={<Earnings />} />
          <Route path="notifications" element={<Notifications />} />
          <Route path="verification" element={<Verification />} />
          <Route path="tracking" element={<Tracking />} />
          <Route path="emergency" element={<Emergency />} />
          <Route path="messaging" element={<Messaging />} />
          <Route path="announcements" element={<Announcements />} />
          <Route path="settings" element={<Settings />} />
        </Route>

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
