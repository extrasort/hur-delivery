import { NavLink } from 'react-router-dom';
import { useAuthStore } from '../../store/authStore';

interface NavItem {
  path: string;
  icon: string;
  label: string;
  labelEn: string;
  badge?: string;
  color?: string;
}

const navItems: NavItem[] = [
  { path: '/', icon: 'fa-home', label: 'لوحة التحكم', labelEn: 'Dashboard' },
  { path: '/orders', icon: 'fa-box', label: 'الطلبات', labelEn: 'Orders' },
  { path: '/messaging', icon: 'fa-headset', label: 'غرفة الرسائل', labelEn: 'Ops Messaging' },
  { path: '/tracking', icon: 'fa-map-marker-alt', label: 'التتبع المباشر', labelEn: 'Live Tracking' },
  { path: '/drivers', icon: 'fa-motorcycle', label: 'السائقون', labelEn: 'Drivers' },
  { path: '/merchants', icon: 'fa-store', label: 'التجار', labelEn: 'Merchants' },
  { path: '/users', icon: 'fa-users', label: 'المستخدمون', labelEn: 'Users' },
  { path: '/verification', icon: 'fa-user-check', label: 'التحقق', labelEn: 'Verification' },
  { path: '/wallets', icon: 'fa-wallet', label: 'المحافظ', labelEn: 'Wallets' },
  { path: '/earnings', icon: 'fa-money-bill-wave', label: 'الأرباح', labelEn: 'Earnings' },
  { path: '/emergency', icon: 'fa-exclamation-triangle', label: 'الطوارئ', labelEn: 'Emergency', color: 'text-red-500' },
  { path: '/announcements', icon: 'fa-bullhorn', label: 'الإعلانات', labelEn: 'Announcements' },
  { path: '/notifications', icon: 'fa-bell', label: 'الإشعارات', labelEn: 'Notifications' },
  { path: '/settings', icon: 'fa-cog', label: 'الإعدادات', labelEn: 'Settings' },
];

export default function Sidebar() {
  const { user, signOut } = useAuthStore();

  return (
    <aside className="w-64 bg-white border-r border-gray-200 flex flex-col h-screen fixed left-0 top-0 z-30">
      {/* Header */}
      <div className="p-6 border-b border-gray-200">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-primary-500 rounded-lg flex items-center justify-center">
            <i className="fas fa-truck-fast text-white text-xl"></i>
          </div>
          <div>
            <h2 className="text-xl font-bold text-gray-900">حر Admin</h2>
            <p className="text-xs text-gray-500">Hur Delivery</p>
          </div>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto py-4 px-3">
        {navItems.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            end={item.path === '/'}
            className={({ isActive }) =>
              `flex items-center gap-3 px-4 py-3 rounded-lg mb-1 transition-colors ${
                isActive
                  ? 'bg-primary-50 text-primary-600 font-medium'
                  : `hover:bg-gray-50 text-gray-700 ${item.color || ''}`
              }`
            }
          >
            <i className={`fas ${item.icon} w-5 text-center`}></i>
            <div className="flex-1 min-w-0">
              <div className="text-sm truncate">{item.label}</div>
              <div className="text-xs text-gray-500 truncate">{item.labelEn}</div>
            </div>
            {item.badge && (
              <span className="bg-red-500 text-white text-xs px-2 py-0.5 rounded-full">
                {item.badge}
              </span>
            )}
          </NavLink>
        ))}
      </nav>

      {/* User Info & Logout */}
      <div className="p-4 border-t border-gray-200">
        <div className="flex items-center gap-3 mb-3 px-2">
          <div className="w-10 h-10 bg-gray-200 rounded-full flex items-center justify-center">
            <i className="fas fa-user text-gray-600"></i>
          </div>
          <div className="flex-1 min-w-0">
            <div className="text-sm font-medium text-gray-900 truncate">{user?.name || 'Admin'}</div>
            <div className="text-xs text-gray-500 truncate">{user?.email || user?.phone}</div>
          </div>
        </div>
        <button
          onClick={signOut}
          className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-red-50 hover:bg-red-100 text-red-600 rounded-lg transition-colors text-sm font-medium"
        >
          <i className="fas fa-sign-out-alt"></i>
          <span>تسجيل الخروج / Logout</span>
        </button>
      </div>
    </aside>
  );
}

