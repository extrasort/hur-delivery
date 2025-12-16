import { useEffect, useState } from 'react';
import { supabaseAdmin, supabase, type Order, type User } from '../lib/supabase-admin';
import { config } from '../lib/config';

export default function Orders() {
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<string>('all');
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedOrder, setSelectedOrder] = useState<Order | null>(null);
  const [showModal, setShowModal] = useState(false);
  const [availableDrivers, setAvailableDrivers] = useState<User[]>([]);
  const [updating, setUpdating] = useState(false);
  const [editMode, setEditMode] = useState(false);
  const [editedOrder, setEditedOrder] = useState<Partial<Order>>({});

  useEffect(() => {
    loadOrders();
    loadAvailableDrivers();

    // Real-time subscription
    const channel = supabase
      .channel('orders-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, () => {
        loadOrders();
      })
      .subscribe();

    return () => {
      channel.unsubscribe();
    };
  }, [filter]);

  const loadOrders = async () => {
    setLoading(true);
    try {
      let query = supabase
        .from('orders')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(config.itemsPerPage * 2);

      if (filter !== 'all') {
        query = query.eq('status', filter);
      }

      const { data, error } = await query;

      if (error) throw error;
      setOrders(data || []);
    } catch (error) {
      console.error('Error loading orders:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadAvailableDrivers = async () => {
    try {
      const { data, error } = await supabase
        .from('users')
        .select('*')
        .eq('role', 'driver')
        .order('name');

      if (error) throw error;
      const available =
        (data || []).filter((driver: any) => (driver.is_available ?? driver.is_online) === true) as User[];
      setAvailableDrivers(available);
    } catch (error) {
      console.error('Error loading drivers:', error);
    }
  };

  const filteredOrders = orders.filter((order) => {
    if (!searchTerm) return true;
    const search = searchTerm.toLowerCase();
    return (
      order.id.toLowerCase().includes(search) ||
      order.customer_name?.toLowerCase().includes(search) ||
      order.customer_phone?.includes(search)
    );
  });

  const updateOrderStatus = async (orderId: string, newStatus: Order['status']) => {
    setUpdating(true);
    try {
      const { error } = await supabaseAdmin.rpc('update_order_from_chat', {
        p_order_id: orderId,
        p_status: newStatus,
      });

      if (error) throw error;
      
      await loadOrders();
      if (selectedOrder?.id === orderId) {
        setSelectedOrder({ ...selectedOrder, status: newStatus });
      }
      alert('تم تحديث الحالة بنجاح / Status updated successfully');
    } catch (error: any) {
      console.error('Error updating status:', error);
      alert(error.message || 'فشل التحديث / Update failed');
    } finally {
      setUpdating(false);
    }
  };

  const reassignDriver = async (orderId: string, driverId: string) => {
    setUpdating(true);
    try {
      const { error } = await supabaseAdmin.rpc('update_order_from_chat', {
        p_order_id: orderId,
        p_driver_id: driverId,
      });

      if (error) throw error;
      
      await loadOrders();
      if (selectedOrder?.id === orderId) {
        setSelectedOrder({ ...selectedOrder, driver_id: driverId });
      }
      alert('تم إعادة تعيين السائق بنجاح / Driver reassigned successfully');
    } catch (error: any) {
      console.error('Error reassigning driver:', error);
      alert(error.message || 'فشل إعادة التعيين / Reassignment failed');
    } finally {
      setUpdating(false);
    }
  };

  const autoAssignDriver = async (orderId: string) => {
    setUpdating(true);
    try {
      const { error } = await supabaseAdmin.rpc('auto_assign_order', {
        p_order_id: orderId,
      });

      if (error) throw error;
      
      await loadOrders();
      alert('تم التعيين التلقائي بنجاح / Auto-assigned successfully');
    } catch (error: any) {
      console.error('Error auto-assigning:', error);
      alert(error.message || 'فشل التعيين التلقائي / Auto-assign failed');
    } finally {
      setUpdating(false);
    }
  };

  const callCustomer = (phone: string) => {
    window.location.href = `tel:${phone}`;
  };

  const getStatusBadge = (status: Order['status']) => {
    const badges = {
      pending: 'bg-yellow-100 text-yellow-800',
      assigned: 'bg-blue-100 text-blue-800',
      accepted: 'bg-indigo-100 text-indigo-800',
      on_the_way: 'bg-purple-100 text-purple-800',
      delivered: 'bg-green-100 text-green-800',
      cancelled: 'bg-red-100 text-red-800',
      rejected: 'bg-gray-100 text-gray-800',
    };
    return badges[status] || badges.pending;
  };

  const getStatusLabel = (status: Order['status']) => {
    const labels = {
      pending: 'قيد الانتظار',
      assigned: 'تم التعيين',
      accepted: 'تم القبول',
      on_the_way: 'في الطريق',
      delivered: 'تم التسليم',
      cancelled: 'ملغي',
      rejected: 'مرفوض',
    };
    return labels[status] || status;
  };

  const openOrderDetails = (order: Order) => {
    setSelectedOrder(order);
    setEditedOrder(order);
    setEditMode(false);
    setShowModal(true);
  };

  const saveOrderChanges = async () => {
    if (!selectedOrder || !editedOrder) return;

    setUpdating(true);
    try {
      const { error } = await supabase
        .from('orders')
        .update({
          customer_name: editedOrder.customer_name,
          customer_phone: editedOrder.customer_phone,
          customer_address: editedOrder.customer_address,
          merchant_name: editedOrder.merchant_name,
          merchant_phone: editedOrder.merchant_phone,
          merchant_address: editedOrder.merchant_address,
          delivery_fee: editedOrder.delivery_fee,
          notes: editedOrder.notes,
        })
        .eq('id', selectedOrder.id);

      if (error) throw error;

      await loadOrders();
      setSelectedOrder({ ...selectedOrder, ...editedOrder });
      setEditMode(false);
      alert('تم حفظ التغييرات / Changes saved successfully');
    } catch (error: any) {
      console.error('Error saving changes:', error);
      alert(error.message || 'فشل الحفظ / Save failed');
    } finally {
      setUpdating(false);
    }
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
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">الطلبات / Orders</h2>
          <p className="text-gray-600 text-sm mt-1">إدارة جميع الطلبات / Manage all orders</p>
        </div>
        <div className="flex gap-2">
          <span className="px-3 py-1 bg-blue-100 text-blue-800 rounded-full text-sm font-medium">
            {filteredOrders.length} طلب
          </span>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-xl shadow-sm p-4">
        <div className="flex flex-wrap items-center gap-4">
          <input
            type="search"
            placeholder="البحث... / Search..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="flex-1 min-w-[200px] px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
          />
          <select
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent outline-none"
          >
            <option value="all">جميع الحالات / All Status</option>
            <option value="pending">قيد الانتظار / Pending</option>
            <option value="assigned">تم التعيين / Assigned</option>
            <option value="accepted">تم القبول / Accepted</option>
            <option value="on_the_way">في الطريق / On the Way</option>
            <option value="delivered">تم التسليم / Delivered</option>
            <option value="cancelled">ملغي / Cancelled</option>
          </select>
        </div>
      </div>

      {/* Orders Table */}
      <div className="bg-white rounded-xl shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">رقم الطلب / ID</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">العميل / Customer</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">الحالة / Status</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">رسوم التوصيل / Fee</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">التاريخ / Date</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">إجراءات / Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filteredOrders.map((order) => (
                <tr key={order.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className="text-sm font-mono text-gray-900">
                      #{order.id.slice(0, 8)}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <div>
                      <p className="text-sm font-medium text-gray-900">{order.customer_name}</p>
                      <p className="text-sm text-gray-500">{order.customer_phone}</p>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`px-3 py-1 text-xs font-medium rounded-full ${getStatusBadge(order.status)}`}>
                      {getStatusLabel(order.status)}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className="text-sm text-gray-900">{order.delivery_fee.toLocaleString()} {config.currencySymbol}</span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {new Date(order.created_at).toLocaleDateString('ar-IQ')}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm">
                    <button 
                      onClick={() => openOrderDetails(order)}
                      className="text-primary-600 hover:text-primary-800 font-medium"
                    >
                      <i className="fas fa-eye mr-1"></i>
                      عرض
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {filteredOrders.length === 0 && (
          <div className="text-center py-12 text-gray-500">
            <i className="fas fa-box-open text-4xl mb-2"></i>
            <p>لا توجد طلبات / No orders found</p>
          </div>
        )}
      </div>

      {/* Order Details Modal */}
      {showModal && selectedOrder && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl shadow-xl max-w-4xl w-full max-h-[90vh] overflow-y-auto">
            {/* Modal Header */}
            <div className="flex items-center justify-between p-6 border-b border-gray-200">
              <div>
                <h3 className="text-xl font-bold text-gray-900">تفاصيل الطلب / Order Details</h3>
                <p className="text-sm text-gray-500 mt-1">#{selectedOrder.id.slice(0, 8)}</p>
              </div>
              <button
                onClick={() => setShowModal(false)}
                className="text-gray-400 hover:text-gray-600 transition-colors"
              >
                <i className="fas fa-times text-xl"></i>
              </button>
            </div>

            {/* Modal Content */}
            <div className="p-6 space-y-6">
              {/* Status */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  الحالة / Status
                </label>
                <select
                  value={selectedOrder.status}
                  onChange={(e) => {
                    if (confirm('هل أنت متأكد من تغيير الحالة؟ / Are you sure?')) {
                      updateOrderStatus(selectedOrder.id, e.target.value as Order['status']);
                    }
                  }}
                  disabled={updating}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                >
                  <option value="pending">قيد الانتظار / Pending</option>
                  <option value="assigned">تم التعيين / Assigned</option>
                  <option value="accepted">تم القبول / Accepted</option>
                  <option value="on_the_way">في الطريق / On the Way</option>
                  <option value="delivered">تم التسليم / Delivered</option>
                  <option value="cancelled">ملغي / Cancelled</option>
                </select>
              </div>

              {/* Driver Assignment */}
              {selectedOrder.status !== 'delivered' && selectedOrder.status !== 'cancelled' && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    السائق / Driver
                  </label>
                  <div className="flex gap-2">
                    <select
                      value={selectedOrder.driver_id || ''}
                      onChange={(e) => {
                        if (e.target.value && confirm('هل أنت متأكد من إعادة تعيين السائق؟ / Reassign driver?')) {
                          reassignDriver(selectedOrder.id, e.target.value);
                        }
                      }}
                      disabled={updating}
                      className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                    >
                      <option value="">اختر سائق / Select Driver</option>
                      {availableDrivers.map((driver) => (
                        <option key={driver.id} value={driver.id}>
                          {driver.name} - {driver.phone}
                        </option>
                      ))}
                    </select>
                    <button
                      onClick={() => autoAssignDriver(selectedOrder.id)}
                      disabled={updating}
                      className="px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg transition-colors disabled:opacity-50"
                    >
                      <i className="fas fa-magic mr-1"></i>
                      تعيين تلقائي
                    </button>
                  </div>
                </div>
              )}

              {/* Customer Info */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <h4 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
                  <i className="fas fa-user text-primary-500"></i>
                  معلومات العميل / Customer Info
                </h4>
                <div className="space-y-2">
                  {editMode ? (
                    <>
                      <div>
                        <label className="block text-xs font-medium text-gray-700 mb-1">الاسم / Name</label>
                        <input
                          type="text"
                          value={editedOrder.customer_name || ''}
                          onChange={(e) => setEditedOrder({...editedOrder, customer_name: e.target.value})}
                          className="w-full px-3 py-1 text-sm border border-gray-300 rounded focus:ring-2 focus:ring-primary-500 outline-none"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-medium text-gray-700 mb-1">الهاتف / Phone</label>
                        <input
                          type="text"
                          value={editedOrder.customer_phone || ''}
                          onChange={(e) => setEditedOrder({...editedOrder, customer_phone: e.target.value})}
                          className="w-full px-3 py-1 text-sm border border-gray-300 rounded focus:ring-2 focus:ring-primary-500 outline-none"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-medium text-gray-700 mb-1">العنوان / Address</label>
                        <textarea
                          value={editedOrder.customer_address || ''}
                          onChange={(e) => setEditedOrder({...editedOrder, customer_address: e.target.value})}
                          className="w-full px-3 py-1 text-sm border border-gray-300 rounded focus:ring-2 focus:ring-primary-500 outline-none"
                          rows={2}
                        ></textarea>
                      </div>
                    </>
                  ) : (
                    <>
                      <p className="text-sm"><span className="font-medium">الاسم / Name:</span> {selectedOrder.customer_name}</p>
                      <p className="text-sm">
                        <span className="font-medium">الهاتف / Phone:</span> {selectedOrder.customer_phone}
                        <button
                          onClick={() => callCustomer(selectedOrder.customer_phone)}
                          className="mr-2 text-green-600 hover:text-green-800"
                        >
                          <i className="fas fa-phone"></i>
                        </button>
                      </p>
                      <p className="text-sm"><span className="font-medium">العنوان / Address:</span> {selectedOrder.customer_address}</p>
                    </>
                  )}
                </div>
              </div>

              <div>
                <h4 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
                  <i className="fas fa-store text-primary-500"></i>
                  معلومات التاجر / Merchant Info
                </h4>
                <div className="space-y-2">
                  {editMode ? (
                    <>
                      <div>
                        <label className="block text-xs font-medium text-gray-700 mb-1">الاسم / Name</label>
                        <input
                          type="text"
                          value={editedOrder.merchant_name || ''}
                          onChange={(e) => setEditedOrder({...editedOrder, merchant_name: e.target.value})}
                          className="w-full px-3 py-1 text-sm border border-gray-300 rounded focus:ring-2 focus:ring-primary-500 outline-none"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-medium text-gray-700 mb-1">الهاتف / Phone</label>
                        <input
                          type="text"
                          value={editedOrder.merchant_phone || ''}
                          onChange={(e) => setEditedOrder({...editedOrder, merchant_phone: e.target.value})}
                          className="w-full px-3 py-1 text-sm border border-gray-300 rounded focus:ring-2 focus:ring-primary-500 outline-none"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-medium text-gray-700 mb-1">العنوان / Address</label>
                        <textarea
                          value={editedOrder.merchant_address || ''}
                          onChange={(e) => setEditedOrder({...editedOrder, merchant_address: e.target.value})}
                          className="w-full px-3 py-1 text-sm border border-gray-300 rounded focus:ring-2 focus:ring-primary-500 outline-none"
                          rows={2}
                        ></textarea>
                      </div>
                    </>
                  ) : (
                    <>
                      <p className="text-sm"><span className="font-medium">الاسم / Name:</span> {selectedOrder.merchant_name || 'N/A'}</p>
                      <p className="text-sm"><span className="font-medium">الهاتف / Phone:</span> {selectedOrder.merchant_phone || 'N/A'}</p>
                      <p className="text-sm"><span className="font-medium">العنوان / Address:</span> {selectedOrder.merchant_address || 'N/A'}</p>
                    </>
                  )}
                </div>
              </div>
              </div>

              {/* Order Details */}
              <div>
                <h4 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
                  <i className="fas fa-box text-primary-500"></i>
                  تفاصيل الطلب / Order Details
                </h4>
                <div className="bg-gray-50 rounded-lg p-4 space-y-2">
                  {editMode ? (
                    <>
                      <div>
                        <label className="block text-xs font-medium text-gray-700 mb-1">رسوم التوصيل / Delivery Fee ({config.currencySymbol})</label>
                        <input
                          type="number"
                          value={editedOrder.delivery_fee || 0}
                          onChange={(e) => setEditedOrder({...editedOrder, delivery_fee: Number(e.target.value)})}
                          className="w-full px-3 py-1 text-sm border border-gray-300 rounded focus:ring-2 focus:ring-primary-500 outline-none"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-medium text-gray-700 mb-1">ملاحظات / Notes</label>
                        <textarea
                          value={editedOrder.notes || ''}
                          onChange={(e) => setEditedOrder({...editedOrder, notes: e.target.value})}
                          className="w-full px-3 py-1 text-sm border border-gray-300 rounded focus:ring-2 focus:ring-primary-500 outline-none"
                          rows={3}
                        ></textarea>
                      </div>
                    </>
                  ) : (
                    <>
                      <p className="text-sm"><span className="font-medium">رسوم التوصيل / Delivery Fee:</span> {selectedOrder.delivery_fee.toLocaleString()} {config.currencySymbol}</p>
                      {selectedOrder.notes && (
                        <p className="text-sm"><span className="font-medium">ملاحظات / Notes:</span> {selectedOrder.notes}</p>
                      )}
                    </>
                  )}
                  <p className="text-sm"><span className="font-medium">تاريخ الإنشاء / Created:</span> {new Date(selectedOrder.created_at).toLocaleString('ar-IQ')}</p>
                  {selectedOrder.assigned_at && (
                    <p className="text-sm"><span className="font-medium">تاريخ التعيين / Assigned:</span> {new Date(selectedOrder.assigned_at).toLocaleString('ar-IQ')}</p>
                  )}
                  {selectedOrder.delivered_at && (
                    <p className="text-sm"><span className="font-medium">تاريخ التسليم / Delivered:</span> {new Date(selectedOrder.delivered_at).toLocaleString('ar-IQ')}</p>
                  )}
                </div>
              </div>
            </div>

            {/* Modal Footer */}
            <div className="flex items-center justify-end gap-3 p-6 border-t border-gray-200">
              {editMode ? (
                <>
                  <button
                    onClick={() => {
                      setEditMode(false);
                      setEditedOrder(selectedOrder);
                    }}
                    className="px-6 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
                  >
                    إلغاء / Cancel
                  </button>
                  <button
                    onClick={saveOrderChanges}
                    disabled={updating}
                    className="px-6 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-lg disabled:opacity-50"
                  >
                    <i className="fas fa-save mr-1"></i>
                    {updating ? 'جاري الحفظ...' : 'حفظ / Save'}
                  </button>
                </>
              ) : (
                <>
                  <button
                    onClick={() => setShowModal(false)}
                    className="px-6 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
                  >
                    إغلاق / Close
                  </button>
                  <button
                    onClick={() => setEditMode(true)}
                    className="px-6 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg"
                  >
                    <i className="fas fa-edit mr-1"></i>
                    تعديل / Edit
                  </button>
                </>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
