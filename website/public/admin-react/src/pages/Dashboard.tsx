import { useEffect, useState } from 'react';
import { supabase, supabaseAdmin } from '../lib/supabase-admin';
import { config } from '../lib/config';

interface DashboardStats {
  totalOrders: number;
  activeOrders: number;
  completedOrders: number;
  totalDrivers: number;
  onlineDrivers: number;
  totalMerchants: number;
  totalRevenue: number;
  todayRevenue: number;
}

export default function Dashboard() {
  const [stats, setStats] = useState<DashboardStats>({
    totalOrders: 0,
    activeOrders: 0,
    completedOrders: 0,
    totalDrivers: 0,
    onlineDrivers: 0,
    totalMerchants: 0,
    totalRevenue: 0,
    todayRevenue: 0,
  });
  const [loading, setLoading] = useState(true);
  const [recentOrders, setRecentOrders] = useState<any[]>([]);
  const [systemEnabled, setSystemEnabled] = useState<boolean | null>(null);
  const [maintenanceMode, setMaintenanceMode] = useState<boolean | null>(null);
  const [updatingSystem, setUpdatingSystem] = useState(false);

  useEffect(() => {
    loadDashboardData();
    loadSystemState();

    // Real-time updates
    const channel = supabase
      .channel('dashboard-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, () => {
        loadDashboardData();
      })
      .subscribe();

    const settingsChannel = supabase
      .channel('dashboard-settings')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'system_settings' }, () => {
        loadSystemState();
      })
      .subscribe();

    return () => {
      channel.unsubscribe();
      settingsChannel.unsubscribe();
    };
  }, []);

  const loadDashboardData = async () => {
    setLoading(true);
    try {
      // Load orders stats
      const { data: orders } = await supabaseAdmin
        .from('orders')
        .select('id, status, delivery_fee, created_at');

      const totalOrders = orders?.length || 0;
      const activeOrders = orders?.filter(o => !['delivered', 'cancelled'].includes(o.status)).length || 0;
      const completedOrders = orders?.filter(o => o.status === 'delivered').length || 0;
      const totalRevenue = orders?.reduce((sum, o) => sum + (o.delivery_fee || 0), 0) || 0;

      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const todayRevenue = orders?.filter(o => new Date(o.created_at) >= today)
        .reduce((sum, o) => sum + (o.delivery_fee || 0), 0) || 0;

      // Load drivers stats
      const { data: drivers } = await supabaseAdmin
        .from('users')
        .select('id, is_online')
        .eq('role', 'driver');

      const totalDrivers = drivers?.length || 0;
      const onlineDrivers = drivers?.filter(d => d.is_online).length || 0;

      // Load merchants count
      const { data: merchants } = await supabaseAdmin
        .from('users')
        .select('id')
        .eq('role', 'merchant');

      const totalMerchants = merchants?.length || 0;

      // Load recent orders
      const { data: recent } = await supabaseAdmin
        .from('orders')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(5);

      setStats({
        totalOrders,
        activeOrders,
        completedOrders,
        totalDrivers,
        onlineDrivers,
        totalMerchants,
        totalRevenue,
        todayRevenue,
      });

      setRecentOrders(recent || []);
    } catch (error) {
      console.error('Error loading dashboard data:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadSystemState = async () => {
    try {
      const { data, error } = await supabaseAdmin
        .from('system_settings')
        .select('key, value')
        .in('key', ['system_enabled', 'maintenance_mode']);

      if (error) throw error;

      const enabledSetting = data?.find((s) => s.key === 'system_enabled');
      const maintenanceSetting = data?.find((s) => s.key === 'maintenance_mode');

      setSystemEnabled(enabledSetting ? enabledSetting.value === 'true' : null);
      setMaintenanceMode(maintenanceSetting ? maintenanceSetting.value === 'true' : null);
    } catch (error) {
      console.error('Error loading system state:', error);
    }
  };

  const updateSystemSetting = async (key: 'system_enabled' | 'maintenance_mode', value: boolean) => {
    setUpdatingSystem(true);
    try {
      const { error } = await supabaseAdmin
        .from('system_settings')
        .upsert(
          { key, value: value ? 'true' : 'false', updated_at: new Date().toISOString() },
          { onConflict: 'key' }
        );

      if (error) throw error;

      if (key === 'system_enabled' && !value) {
        const { error: forceError } = await supabaseAdmin.rpc('force_all_drivers_offline');
        if (forceError) {
          console.warn('Failed to force drivers offline:', forceError);
        }
        alert('تم تعطيل النظام وإخراج جميع السائقين');
      } else if (key === 'system_enabled' && value) {
        alert('تم تفعيل النظام');
      }

      await loadSystemState();
    } catch (error: any) {
      console.error('Error updating system setting:', error);
      alert(error.message || 'فشل تحديث حالة النظام');
    } finally {
      setUpdatingSystem(false);
    }
  };

  const getStatusBadge = (status: string) => {
    const badges: { [key: string]: string } = {
      pending: 'bg-yellow-100 text-yellow-800',
      assigned: 'bg-blue-100 text-blue-800',
      accepted: 'bg-indigo-100 text-indigo-800',
      on_the_way: 'bg-purple-100 text-purple-800',
      delivered: 'bg-green-100 text-green-800',
      cancelled: 'bg-red-100 text-red-800',
    };
    return badges[status] || badges.pending;
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">لوحة التحكم / Dashboard</h2>
          <p className="text-gray-600 text-sm mt-1">نظرة عامة على النظام / System overview</p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 w-full lg:w-auto">
          <div className="bg-white rounded-xl shadow-sm p-4 border border-gray-100">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs text-gray-500">حالة النظام / System State</p>
                <p
                  className={`text-lg font-semibold ${
                    systemEnabled ? 'text-green-600' : 'text-red-600'
                  }`}
                >
                  {systemEnabled === null
                    ? 'غير معروف'
                    : systemEnabled
                    ? 'مُفعل'
                    : 'موقوف'}
                </p>
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => updateSystemSetting('system_enabled', true)}
                  disabled={systemEnabled === true || updatingSystem}
                  className="px-3 py-2 bg-green-500 hover:bg-green-600 text-white text-xs rounded-lg disabled:opacity-40"
                >
                  تشغيل
                </button>
                <button
                  onClick={() => updateSystemSetting('system_enabled', false)}
                  disabled={systemEnabled === false || updatingSystem}
                  className="px-3 py-2 bg-red-500 hover:bg-red-600 text-white text-xs rounded-lg disabled:opacity-40"
                >
                  إيقاف
                </button>
              </div>
            </div>
          </div>

          <div className="bg-white rounded-xl shadow-sm p-4 border border-gray-100">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs text-gray-500">وضع الصيانة / Maintenance</p>
                <p
                  className={`text-lg font-semibold ${
                    maintenanceMode ? 'text-orange-600' : 'text-green-600'
                  }`}
                >
                  {maintenanceMode ? 'مُفعل' : 'غير مفعل'}
                </p>
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => updateSystemSetting('maintenance_mode', false)}
                  disabled={maintenanceMode === false || updatingSystem}
                  className="px-3 py-2 bg-blue-500 hover:bg-blue-600 text-white text-xs rounded-lg disabled:opacity-40"
                >
                  إيقاف
                </button>
                <button
                  onClick={() => updateSystemSetting('maintenance_mode', true)}
                  disabled={maintenanceMode === true || updatingSystem}
                  className="px-3 py-2 bg-orange-500 hover:bg-orange-600 text-white text-xs rounded-lg disabled:opacity-40"
                >
                  تشغيل
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {/* Total Orders */}
        <div className="bg-white rounded-xl shadow-sm p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-gray-600 text-sm mb-1">إجمالي الطلبات / Total Orders</p>
              <p className="text-3xl font-bold text-gray-900">{stats.totalOrders}</p>
            </div>
            <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
              <i className="fas fa-box text-blue-600 text-xl"></i>
            </div>
          </div>
        </div>

        {/* Active Orders */}
        <div className="bg-white rounded-xl shadow-sm p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-gray-600 text-sm mb-1">الطلبات النشطة / Active Orders</p>
              <p className="text-3xl font-bold text-gray-900">{stats.activeOrders}</p>
            </div>
            <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center">
              <i className="fas fa-truck text-purple-600 text-xl"></i>
            </div>
          </div>
        </div>

        {/* Online Drivers */}
        <div className="bg-white rounded-xl shadow-sm p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-gray-600 text-sm mb-1">السائقون المتصلون / Online Drivers</p>
              <p className="text-3xl font-bold text-gray-900">{stats.onlineDrivers}<span className="text-lg text-gray-500">/{stats.totalDrivers}</span></p>
            </div>
            <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
              <i className="fas fa-motorcycle text-green-600 text-xl"></i>
            </div>
          </div>
        </div>

        {/* Today's Revenue */}
        <div className="bg-white rounded-xl shadow-sm p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-gray-600 text-sm mb-1">إيرادات اليوم / Today's Revenue</p>
              <p className="text-3xl font-bold text-gray-900">{stats.todayRevenue.toLocaleString()}</p>
              <p className="text-xs text-gray-500 mt-1">{config.currencySymbol}</p>
            </div>
            <div className="w-12 h-12 bg-yellow-100 rounded-lg flex items-center justify-center">
              <i className="fas fa-coins text-yellow-600 text-xl"></i>
            </div>
          </div>
        </div>
      </div>

      {/* Additional Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white rounded-xl shadow-sm p-6">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 bg-indigo-100 rounded-lg flex items-center justify-center">
              <i className="fas fa-check-circle text-indigo-600 text-xl"></i>
            </div>
            <div>
              <p className="text-gray-600 text-sm">الطلبات المكتملة / Completed</p>
              <p className="text-2xl font-bold text-gray-900">{stats.completedOrders}</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-sm p-6">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 bg-pink-100 rounded-lg flex items-center justify-center">
              <i className="fas fa-store text-pink-600 text-xl"></i>
            </div>
            <div>
              <p className="text-gray-600 text-sm">التجار / Merchants</p>
              <p className="text-2xl font-bold text-gray-900">{stats.totalMerchants}</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-sm p-6">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 bg-teal-100 rounded-lg flex items-center justify-center">
              <i className="fas fa-chart-line text-teal-600 text-xl"></i>
            </div>
            <div>
              <p className="text-gray-600 text-sm">إجمالي الإيرادات / Total Revenue</p>
              <p className="text-2xl font-bold text-gray-900">{stats.totalRevenue.toLocaleString()}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Recent Orders */}
      <div className="bg-white rounded-xl shadow-sm overflow-hidden">
        <div className="p-6 border-b border-gray-200">
          <h3 className="text-lg font-bold text-gray-900">الطلبات الأخيرة / Recent Orders</h3>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">رقم الطلب / ID</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">العميل / Customer</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">الحالة / Status</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">الرسوم / Fee</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">الوقت / Time</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {recentOrders.map((order) => (
                <tr key={order.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-mono text-gray-900">
                    #{order.id.slice(0, 8)}
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-900">{order.customer_name}</td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`px-3 py-1 text-xs font-medium rounded-full ${getStatusBadge(order.status)}`}>
                      {order.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {order.delivery_fee.toLocaleString()} {config.currencySymbol}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {new Date(order.created_at).toLocaleTimeString('ar-IQ')}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {recentOrders.length === 0 && (
          <div className="text-center py-12 text-gray-500">
            <i className="fas fa-box-open text-4xl mb-2"></i>
            <p>لا توجد طلبات حديثة / No recent orders</p>
          </div>
        )}
      </div>
    </div>
  );
}
