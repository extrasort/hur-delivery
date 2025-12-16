import { useEffect, useState } from 'react';
import { supabaseAdmin, supabase, type User } from '../lib/supabase-admin';

export default function Users() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<string>('all');
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [showModal, setShowModal] = useState(false);
  const [walletAmount, setWalletAmount] = useState('');
  const [updating, setUpdating] = useState(false);

  useEffect(() => {
    loadUsers();

    const channel = supabase
      .channel('users-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'users' }, () => {
        loadUsers();
      })
      .subscribe();

    return () => {
      channel.unsubscribe();
    };
  }, [filter]);

  const loadUsers = async () => {
    setLoading(true);
    try {
      let query = supabaseAdmin
        .from('users')
        .select('*')
        .order('created_at', { ascending: false });

      if (filter !== 'all') {
        query = query.eq('role', filter);
      }

      const { data, error } = await query;

      if (error) {
        console.error('Error loading users - details:', {
          message: error.message,
          code: error.code,
          details: error.details,
          hint: error.hint,
        });
        throw error;
      }
      setUsers(data || []);
    } catch (error: any) {
      console.error('Error loading users:', error);
      // Show user-friendly error
      if (error?.code === 'PGRST301' || error?.message?.includes('permission denied')) {
        console.error('RLS policy is blocking access. Please ensure admin RLS policies are set up.');
      }
    } finally {
      setLoading(false);
    }
  };

  const filteredUsers = users.filter((user) => {
    if (!searchTerm) return true;
    const search = searchTerm.toLowerCase();
    return (
      user.name?.toLowerCase().includes(search) ||
      user.phone?.includes(search) ||
      user.email?.toLowerCase().includes(search)
    );
  });

  const toggleUserStatus = async (userId: string, currentStatus: boolean) => {
    try {
      const { error } = await supabaseAdmin
        .from('users')
        .update({ is_active: !currentStatus })
        .eq('id', userId);

      if (error) throw error;
      
      await loadUsers();
      alert('تم تحديث الحالة / Status updated');
    } catch (error: any) {
      console.error('Error updating user:', error);
      alert(error.message || 'فشل التحديث / Update failed');
    }
  };

  const verifyUser = async (userId: string) => {
    try {
      const { error } = await supabaseAdmin
        .from('users')
        .update({ verification_status: 'approved' })
        .eq('id', userId);

      if (error) throw error;
      
      await loadUsers();
      alert('تم التحقق من المستخدم / User verified');
    } catch (error: any) {
      console.error('Error verifying user:', error);
      alert(error.message || 'فشل التحقق / Verification failed');
    }
  };

  const addWalletBalance = async () => {
    if (!selectedUser || !walletAmount) return;
    
    setUpdating(true);
    try {
      const amount = parseFloat(walletAmount);
      if (isNaN(amount) || amount <= 0) {
        alert('الرجاء إدخال مبلغ صحيح / Please enter a valid amount');
        return;
      }

      const { error } = await supabaseAdmin.rpc('add_wallet_balance', {
        p_merchant_id: selectedUser.id,
        p_amount: amount,
        p_payment_method: 'admin_manual',
        p_notes: 'إضافة رصيد من قبل المشرف / Balance added by admin',
      });

      if (error) throw error;
      
      await loadUsers();
      setWalletAmount('');
      setShowModal(false);
      alert('تم إضافة الرصيد بنجاح / Balance added successfully');
    } catch (error: any) {
      console.error('Error adding balance:', error);
      alert(error.message || 'فشل إضافة الرصيد / Failed to add balance');
    } finally {
      setUpdating(false);
    }
  };

  const getRoleBadge = (role: User['role']) => {
    const badges = {
      driver: 'bg-blue-100 text-blue-800',
      merchant: 'bg-purple-100 text-purple-800',
      customer: 'bg-gray-100 text-gray-800',
      admin: 'bg-red-100 text-red-800',
    };
    return badges[role] || badges.customer;
  };

  const getRoleLabel = (role: User['role']) => {
    const labels = {
      driver: 'سائق',
      merchant: 'تاجر',
      customer: 'عميل',
      admin: 'مشرف',
    };
    return labels[role] || role;
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
          <h2 className="text-2xl font-bold text-gray-900">المستخدمون / Users</h2>
          <p className="text-gray-600 text-sm mt-1">إدارة جميع المستخدمين / Manage all users</p>
        </div>
        <div className="flex gap-2">
          <span className="px-3 py-1 bg-blue-100 text-blue-800 rounded-full text-sm font-medium">
            {filteredUsers.length} مستخدم
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
            <option value="all">جميع الأدوار / All Roles</option>
            <option value="driver">سائق / Driver</option>
            <option value="merchant">تاجر / Merchant</option>
            <option value="customer">عميل / Customer</option>
            <option value="admin">مشرف / Admin</option>
          </select>
        </div>
      </div>

      {/* Users Table */}
      <div className="bg-white rounded-xl shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">الاسم / Name</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">الدور / Role</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">الهاتف / Phone</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">الحالة / Status</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">إجراءات / Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filteredUsers.map((user) => (
                <tr key={user.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-3">
                      <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
                        user.is_online ? 'bg-green-100' : 'bg-gray-100'
                      }`}>
                        <i className={`fas ${
                          user.role === 'driver' ? 'fa-motorcycle' :
                          user.role === 'merchant' ? 'fa-store' :
                          user.role === 'admin' ? 'fa-user-shield' :
                          'fa-user'
                        } ${user.is_online ? 'text-green-600' : 'text-gray-500'}`}></i>
                      </div>
                      <div>
                        <p className="text-sm font-medium text-gray-900">{user.name}</p>
                        {user.email && <p className="text-xs text-gray-500">{user.email}</p>}
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`px-3 py-1 text-xs font-medium rounded-full ${getRoleBadge(user.role)}`}>
                      {getRoleLabel(user.role)}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {user.phone}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center gap-2">
                      <span className={`inline-flex items-center gap-1 px-2 py-1 text-xs rounded-full ${
                        user.is_active ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                      }`}>
                        <i className={`fas ${user.is_active ? 'fa-check-circle' : 'fa-times-circle'}`}></i>
                        {user.is_active ? 'نشط' : 'غير نشط'}
                      </span>
                      {user.verification_status === 'approved' && (
                        <span className="inline-flex items-center gap-1 px-2 py-1 text-xs bg-blue-100 text-blue-800 rounded-full">
                          <i className="fas fa-check-circle"></i>
                          موثق
                        </span>
                      )}
                      {user.verification_status === 'rejected' && (
                        <span className="inline-flex items-center gap-1 px-2 py-1 text-xs bg-red-100 text-red-800 rounded-full">
                          <i className="fas fa-times-circle"></i>
                          مرفوض
                        </span>
                      )}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm">
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => toggleUserStatus(user.id, user.is_active)}
                        className="text-blue-600 hover:text-blue-800"
                        title={user.is_active ? 'تعطيل' : 'تفعيل'}
                      >
                        <i className={`fas ${user.is_active ? 'fa-ban' : 'fa-check'}`}></i>
                      </button>
                      {user.verification_status !== 'approved' && (
                        <button
                          onClick={() => verifyUser(user.id)}
                          className="text-green-600 hover:text-green-800"
                          title="توثيق"
                        >
                          <i className="fas fa-check-double"></i>
                        </button>
                      )}
                      <button
                        onClick={() => {
                          setSelectedUser(user);
                          setShowModal(true);
                        }}
                        className="text-purple-600 hover:text-purple-800"
                        title="إضافة رصيد"
                      >
                        <i className="fas fa-wallet"></i>
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {filteredUsers.length === 0 && (
          <div className="text-center py-12 text-gray-500">
            <i className="fas fa-users text-4xl mb-2"></i>
            <p>لا يوجد مستخدمون / No users found</p>
          </div>
        )}
      </div>

      {/* Add Balance Modal */}
      {showModal && selectedUser && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl shadow-xl max-w-md w-full">
            <div className="flex items-center justify-between p-6 border-b border-gray-200">
              <h3 className="text-xl font-bold text-gray-900">إضافة رصيد / Add Balance</h3>
              <button
                onClick={() => setShowModal(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <i className="fas fa-times text-xl"></i>
              </button>
            </div>

            <div className="p-6 space-y-4">
              <div>
                <p className="text-sm text-gray-600 mb-4">
                  المستخدم: <span className="font-medium text-gray-900">{selectedUser.name}</span>
                </p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  المبلغ / Amount (IQD)
                </label>
                <input
                  type="number"
                  value={walletAmount}
                  onChange={(e) => setWalletAmount(e.target.value)}
                  placeholder="أدخل المبلغ / Enter amount"
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                />
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 p-6 border-t border-gray-200">
              <button
                onClick={() => setShowModal(false)}
                className="px-6 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
              >
                إلغاء / Cancel
              </button>
              <button
                onClick={addWalletBalance}
                disabled={updating || !walletAmount}
                className="px-6 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-lg disabled:opacity-50"
              >
                {updating ? 'جاري الإضافة...' : 'إضافة / Add'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
