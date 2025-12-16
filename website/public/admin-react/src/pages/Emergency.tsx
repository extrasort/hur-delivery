import { useEffect, useState } from 'react';
import { supabase, supabaseAdmin, type Order, type User } from '../lib/supabase-admin';

interface EmergencyOrder extends Order {
  driver?: User;
  merchant?: User;
  minutes_overdue: number;
  severity: 'warning' | 'critical';
}

export default function Emergency() {
  const [emergencyOrders, setEmergencyOrders] = useState<EmergencyOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'accepted' | 'picked_up' | 'all'>('all');

  useEffect(() => {
    loadEmergencyOrders();

    // Refresh every 30 seconds
    const interval = setInterval(() => {
      loadEmergencyOrders();
    }, 30000);

    // Subscribe to order changes
    const channel = supabase
      .channel('emergency-orders-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, () => {
        loadEmergencyOrders();
      })
      .subscribe();

    return () => {
      clearInterval(interval);
      channel.unsubscribe();
    };
  }, []);

  const loadEmergencyOrders = async () => {
    setLoading(true);
    try {
      const now = new Date();

      // Load orders with status 'accepted' or 'on_the_way' (picked_up might be stored as on_the_way)
      const { data: orders, error } = await supabase
        .from('orders')
        .select('*')
        .in('status', ['accepted', 'on_the_way'])
        .order('updated_at', { ascending: false });

      if (error) {
        console.error('Error loading emergency orders:', error);
        setEmergencyOrders([]);
        setLoading(false);
        return;
      }

      // Filter orders based on time thresholds
      const emergency: EmergencyOrder[] = [];

      (orders || []).forEach((order: any) => {
        const updatedAt = order.updated_at ? new Date(order.updated_at) : null;
        const acceptedAt = order.accepted_at ? new Date(order.accepted_at) : null;
        const pickedUpAt = order.picked_up_at ? new Date(order.picked_up_at) : null;
        
        // Use the most relevant timestamp for the status
        let referenceTime: Date | null = null;
        let thresholdMinutes = 0;

        if (order.status === 'accepted') {
          referenceTime = acceptedAt || updatedAt;
          thresholdMinutes = 15;
        } else if (order.status === 'on_the_way') {
          referenceTime = pickedUpAt || updatedAt;
          thresholdMinutes = 20;
        }

        if (!referenceTime) return;

        const minutesSinceUpdate = Math.floor((now.getTime() - referenceTime.getTime()) / (60 * 1000));

        if (minutesSinceUpdate >= thresholdMinutes) {
          emergency.push({
            ...order,
            minutes_overdue: minutesSinceUpdate - thresholdMinutes,
            severity: minutesSinceUpdate >= thresholdMinutes * 2 ? 'critical' : 'warning',
          });
        }
      });

      // Fetch driver and merchant info
      const driverIds = Array.from(new Set(emergency.map(o => o.driver_id).filter(Boolean)));
      const merchantIds = Array.from(new Set(emergency.map(o => o.merchant_id).filter(Boolean)));

      let driversById: Record<string, User> = {};
      let merchantsById: Record<string, User> = {};

      if (driverIds.length > 0) {
        const { data: driverRows } = await supabaseAdmin
          .from('users')
          .select('*')
          .in('id', driverIds);
        driversById = (driverRows || []).reduce((acc, driver) => {
          acc[driver.id] = driver;
          return acc;
        }, {} as Record<string, User>);
      }

      if (merchantIds.length > 0) {
        const { data: merchantRows } = await supabaseAdmin
          .from('users')
          .select('*')
          .in('id', merchantIds);
        merchantsById = (merchantRows || []).reduce((acc, merchant) => {
          acc[merchant.id] = merchant;
          return acc;
        }, {} as Record<string, User>);
      }

      // Enrich orders with driver and merchant info
      const enriched = emergency.map(order => ({
        ...order,
        driver: order.driver_id ? driversById[order.driver_id] : undefined,
        merchant: order.merchant_id ? merchantsById[order.merchant_id] : undefined,
      }));

      // Sort by severity and minutes overdue
      enriched.sort((a, b) => {
        if (a.severity !== b.severity) {
          return a.severity === 'critical' ? -1 : 1;
        }
        return b.minutes_overdue - a.minutes_overdue;
      });

      setEmergencyOrders(enriched);
    } catch (error) {
      console.error('Error loading emergency orders:', error);
    } finally {
      setLoading(false);
    }
  };

  const callUser = (phone: string) => {
    window.location.href = `tel:${phone}`;
  };

  const openLocation = (lat: number, lng: number) => {
    window.open(`https://www.google.com/maps?q=${lat},${lng}`, '_blank');
  };

  const getStatusLabel = (status: string) => {
    const labels: Record<string, string> = {
      accepted: 'مقبول / Accepted',
      picked_up: 'تم الاستلام / Picked Up',
      on_the_way: 'في الطريق / On The Way',
    };
    return labels[status] || status;
  };

  const filteredOrders = emergencyOrders.filter(order => {
    if (filter === 'all') return true;
    if (filter === 'accepted') return order.status === 'accepted';
    if (filter === 'picked_up') return order.status === 'on_the_way';
    return true;
  });

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">حالات الطوارئ / Emergency</h2>
          <p className="text-gray-600 text-sm mt-1">طلبات متأخرة في التحديث / Orders overdue for status update</p>
        </div>
        {filteredOrders.length > 0 && (
          <span className={`px-3 py-1 rounded-full text-sm font-medium animate-pulse ${
            filteredOrders.some(o => o.severity === 'critical') 
              ? 'bg-red-100 text-red-800' 
              : 'bg-yellow-100 text-yellow-800'
          }`}>
            <i className="fas fa-exclamation-triangle mr-1"></i>
            {filteredOrders.length} طلب متأخر
          </span>
        )}
      </div>

      <div className="bg-white rounded-xl shadow-sm p-4">
        <div className="flex gap-2">
          <button
            onClick={() => setFilter('all')}
            className={`px-4 py-2 rounded-lg text-sm font-medium ${
              filter === 'all' ? 'bg-red-500 text-white' : 'bg-gray-100 text-gray-700'
            }`}
          >
            <i className="fas fa-list mr-1"></i>
            الكل / All
          </button>
          <button
            onClick={() => setFilter('accepted')}
            className={`px-4 py-2 rounded-lg text-sm font-medium ${
              filter === 'accepted' ? 'bg-yellow-500 text-white' : 'bg-gray-100 text-gray-700'
            }`}
          >
            <i className="fas fa-clock mr-1"></i>
            مقبول (15 دقيقة) / Accepted (15min)
          </button>
          <button
            onClick={() => setFilter('picked_up')}
            className={`px-4 py-2 rounded-lg text-sm font-medium ${
              filter === 'picked_up' ? 'bg-orange-500 text-white' : 'bg-gray-100 text-gray-700'
            }`}
          >
            <i className="fas fa-box mr-1"></i>
            مستلم (20 دقيقة) / Picked Up (20min)
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {filteredOrders.map(order => (
          <div
            key={order.id}
            className={`bg-white rounded-xl shadow-sm p-6 border-l-4 ${
              order.severity === 'critical' ? 'border-red-500' : 'border-yellow-500'
            }`}
          >
            <div className="flex items-start justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className={`w-12 h-12 rounded-full flex items-center justify-center ${
                  order.severity === 'critical' ? 'bg-red-100' : 'bg-yellow-100'
                }`}>
                  <i className={`fas fa-exclamation-triangle ${
                    order.severity === 'critical' ? 'text-red-600' : 'text-yellow-600'
                  } text-xl`}></i>
                </div>
                <div>
                  <p className="font-medium text-gray-900">طلب #{order.id.slice(0, 8)}</p>
                  <p className="text-sm text-gray-500">{getStatusLabel(order.status)}</p>
                </div>
              </div>
              <span className={`px-2 py-1 text-xs rounded-full ${
                order.severity === 'critical' 
                  ? 'bg-red-100 text-red-800 animate-pulse' 
                  : 'bg-yellow-100 text-yellow-800'
              }`}>
                {order.minutes_overdue} دقيقة متأخر
              </span>
            </div>

            <div className="space-y-2 mb-4">
              <div className="bg-gray-50 rounded-lg p-3">
                <p className="text-sm font-medium text-gray-900 mb-1">العميل / Customer</p>
                <p className="text-sm text-gray-700">{order.customer_name}</p>
                <p className="text-xs text-gray-500">{order.customer_phone}</p>
              </div>

              {order.driver && (
                <div className="bg-blue-50 rounded-lg p-3">
                  <p className="text-sm font-medium text-gray-900 mb-1">السائق / Driver</p>
                  <p className="text-sm text-gray-700">{order.driver.name}</p>
                  <p className="text-xs text-gray-500">{order.driver.phone}</p>
                </div>
              )}

              {order.merchant && (
                <div className="bg-green-50 rounded-lg p-3">
                  <p className="text-sm font-medium text-gray-900 mb-1">التاجر / Merchant</p>
                  <p className="text-sm text-gray-700">{order.merchant.name}</p>
                  <p className="text-xs text-gray-500">{order.merchant.phone}</p>
                </div>
              )}
            </div>

            <div className="text-xs text-gray-500 mb-4 space-y-1">
              <p>
                <i className="fas fa-clock mr-1"></i>
                آخر تحديث: {order.updated_at ? new Date(order.updated_at).toLocaleString('ar-IQ') : 'غير معروف'}
              </p>
              {order.accepted_at && order.status === 'accepted' && (
                <p>
                  <i className="fas fa-check-circle mr-1"></i>
                  مقبول في: {new Date(order.accepted_at).toLocaleString('ar-IQ')}
                </p>
              )}
              {order.picked_up_at && order.status === 'on_the_way' && (
                <p>
                  <i className="fas fa-box mr-1"></i>
                  مستلم في: {new Date(order.picked_up_at).toLocaleString('ar-IQ')}
                </p>
              )}
            </div>

            <div className="flex gap-2">
              {order.customer_phone && (
                <button
                  onClick={() => callUser(order.customer_phone)}
                  className="flex-1 px-3 py-2 bg-green-500 hover:bg-green-600 text-white rounded-lg text-sm font-medium"
                >
                  <i className="fas fa-phone mr-1"></i>
                  اتصال عميل
                </button>
              )}
              {order.driver?.phone && (
                <button
                  onClick={() => callUser(order.driver!.phone!)}
                  className="flex-1 px-3 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg text-sm font-medium"
                >
                  <i className="fas fa-phone mr-1"></i>
                  اتصال سائق
                </button>
              )}
              {order.delivery_latitude && order.delivery_longitude && (
                <button
                  onClick={() => openLocation(order.delivery_latitude!, order.delivery_longitude!)}
                  className="px-3 py-2 bg-purple-500 hover:bg-purple-600 text-white rounded-lg text-sm font-medium"
                >
                  <i className="fas fa-map-marker-alt"></i>
                </button>
              )}
            </div>
          </div>
        ))}
      </div>

      {filteredOrders.length === 0 && (
        <div className="bg-white rounded-xl shadow-sm p-12 text-center text-gray-500">
          <i className="fas fa-check-circle text-green-500 text-4xl mb-2"></i>
          <p className="text-lg font-medium mb-1">
            لا توجد طلبات متأخرة
          </p>
          <p className="text-sm">
            No overdue orders
          </p>
        </div>
      )}
    </div>
  );
}
