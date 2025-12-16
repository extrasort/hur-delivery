import { useEffect, useState } from 'react';
import { supabaseAdmin, type User } from '../lib/supabase-admin';

export default function Verification() {
  const [pendingUsers, setPendingUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadPendingUsers();
  }, []);

  const loadPendingUsers = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabaseAdmin
        .from('users')
        .select('*')
        .or('verification_status.eq.pending,verification_status.is.null')
        .in('role', ['driver', 'merchant'])
        .order('created_at', { ascending: false });

      if (error) throw error;
      setPendingUsers(data || []);
    } catch (error) {
      console.error('Error loading pending users:', error);
    } finally {
      setLoading(false);
    }
  };

  const verifyUser = async (userId: string) => {
    try {
      const { error } = await supabaseAdmin
        .from('users')
        .update({ verification_status: 'approved', is_active: true })
        .eq('id', userId);

      if (error) throw error;
      
      await loadPendingUsers();
      alert('تم التحقق بنجاح / Verified successfully');
    } catch (error: any) {
      console.error('Error verifying user:', error);
      alert(error.message || 'فشل التحقق / Verification failed');
    }
  };

  const rejectUser = async (userId: string) => {
    if (!confirm('هل أنت متأكد من رفض هذا المستخدم؟ / Are you sure you want to reject this user?')) {
      return;
    }

    try {
      const { error } = await supabaseAdmin
        .from('users')
        .update({ verification_status: 'rejected', is_active: false })
        .eq('id', userId);

      if (error) throw error;
      
      await loadPendingUsers();
      alert('تم الرفض / Rejected');
    } catch (error: any) {
      console.error('Error rejecting user:', error);
      alert(error.message || 'فشل الرفض / Rejection failed');
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
      <div>
        <h2 className="text-2xl font-bold text-gray-900">التحقق / Verification</h2>
        <p className="text-gray-600 text-sm mt-1">التحقق من السائقين والتجار / Verify drivers and merchants</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {pendingUsers.map(user => (
          <div key={user.id} className="bg-white rounded-xl shadow-sm p-6">
            <div className="flex items-start gap-3 mb-4">
              <div className={`w-12 h-12 rounded-full flex items-center justify-center ${
                user.role === 'driver' ? 'bg-blue-100' : 'bg-purple-100'
              }`}>
                <i className={`fas ${
                  user.role === 'driver' ? 'fa-motorcycle' : 'fa-store'
                } ${user.role === 'driver' ? 'text-blue-600' : 'text-purple-600'} text-xl`}></i>
              </div>
              <div className="flex-1">
                <p className="font-medium text-gray-900">{user.name}</p>
                <p className="text-sm text-gray-500">{user.phone}</p>
                <span className={`inline-block mt-1 px-2 py-1 text-xs rounded-full ${
                  user.role === 'driver' ? 'bg-blue-100 text-blue-800' : 'bg-purple-100 text-purple-800'
                }`}>
                  {user.role === 'driver' ? 'سائق' : 'تاجر'}
                </span>
              </div>
            </div>

            {user.vehicle_type && (
              <p className="text-sm text-gray-600 mb-2">
                <i className="fas fa-motorcycle mr-1"></i>
                {user.vehicle_type}
              </p>
            )}

            <p className="text-xs text-gray-500 mb-4">
              تاريخ التسجيل: {new Date(user.created_at).toLocaleDateString('ar-IQ')}
            </p>

            <div className="flex gap-2">
              <button
                onClick={() => verifyUser(user.id)}
                className="flex-1 px-3 py-2 bg-green-500 hover:bg-green-600 text-white rounded-lg text-sm font-medium"
              >
                <i className="fas fa-check mr-1"></i>
                قبول
              </button>
              <button
                onClick={() => rejectUser(user.id)}
                className="flex-1 px-3 py-2 bg-red-500 hover:bg-red-600 text-white rounded-lg text-sm font-medium"
              >
                <i className="fas fa-times mr-1"></i>
                رفض
              </button>
            </div>
          </div>
        ))}
      </div>

      {pendingUsers.length === 0 && (
        <div className="bg-white rounded-xl shadow-sm p-12 text-center text-gray-500">
          <i className="fas fa-check-circle text-4xl mb-2 text-green-500"></i>
          <p className="text-lg font-medium mb-1">لا توجد طلبات معلقة</p>
          <p className="text-sm">No pending verification requests</p>
        </div>
      )}
    </div>
  );
}
