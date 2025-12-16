import { useEffect, useState } from 'react';
import { supabase, supabaseAdmin, type User } from '../lib/supabase-admin';

export default function Merchants() {
  const [merchants, setMerchants] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');

  useEffect(() => {
    loadMerchants();

    const channel = supabase
      .channel('merchants-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'users' }, (payload) => {
        if (payload.new && (payload.new as User).role === 'merchant') {
          loadMerchants();
        }
      })
      .subscribe();

    return () => {
      channel.unsubscribe();
    };
  }, []);

  const loadMerchants = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabaseAdmin
        .from('users')
        .select('*')
        .eq('role', 'merchant')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setMerchants(data || []);
    } catch (error) {
      console.error('Error loading merchants:', error);
    } finally {
      setLoading(false);
    }
  };

  const filteredMerchants = merchants.filter(merchant => {
    if (!searchTerm) return true;
    const search = searchTerm.toLowerCase();
    return (
      merchant.name?.toLowerCase().includes(search) ||
      merchant.phone?.includes(search)
    );
  });

  const toggleVerification = async (merchantId: string, currentStatus: User['verification_status']) => {
    try {
      const nextStatus = currentStatus === 'approved' ? 'pending' : 'approved';
      const { error } = await supabaseAdmin
        .from('users')
        .update({ verification_status: nextStatus })
        .eq('id', merchantId);

      if (error) throw error;
      await loadMerchants();
      alert('تم تحديث حالة التوثيق / Verification updated');
    } catch (error: any) {
      console.error('Error updating merchant:', error);
      alert(error.message || 'فشل التحديث / Update failed');
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
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">التجار / Merchants</h2>
          <p className="text-gray-600 text-sm mt-1">إدارة جميع التجار / Manage all merchants</p>
        </div>
        <span className="px-3 py-1 bg-purple-100 text-purple-800 rounded-full text-sm font-medium">
          {filteredMerchants.length} تاجر
        </span>
      </div>

      <div className="bg-white rounded-xl shadow-sm p-4">
        <input
          type="search"
          placeholder="البحث... / Search..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
        />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {filteredMerchants.map(merchant => (
          <div key={merchant.id} className="bg-white rounded-xl shadow-sm p-6 hover:shadow-md transition-shadow">
            <div className="flex items-start justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 bg-purple-100 rounded-full flex items-center justify-center">
                  <i className="fas fa-store text-purple-600 text-xl"></i>
                </div>
                <div>
                  <p className="font-medium text-gray-900">{merchant.name}</p>
                  <p className="text-sm text-gray-500">{merchant.phone}</p>
                </div>
              </div>
              {merchant.verification_status === 'approved' && (
                <span className="inline-flex items-center gap-1 px-2 py-1 bg-blue-100 text-blue-800 text-xs rounded-full">
                  <i className="fas fa-check-circle"></i>
                  موثق
                </span>
              )}
              {merchant.verification_status === 'rejected' && (
                <span className="inline-flex items-center gap-1 px-2 py-1 bg-red-100 text-red-800 text-xs rounded-full">
                  <i className="fas fa-times-circle"></i>
                  مرفوض
                </span>
              )}
            </div>

            <div className="space-y-2 text-sm mb-4">
              <div className="flex justify-between">
                <span className="text-gray-600">الحالة / Status:</span>
                <span className={`px-2 py-1 rounded text-xs ${
                  merchant.is_active ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                }`}>
                  {merchant.is_active ? 'نشط' : 'غير نشط'}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-600">الرصيد / Balance:</span>
                <span className="font-medium">{merchant.wallet_balance?.toLocaleString() || 0} IQD</span>
              </div>
            </div>

            <div className="flex gap-2">
              <button
                onClick={() => toggleVerification(merchant.id, merchant.verification_status)}
                className={`flex-1 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                  merchant.verification_status === 'approved' 
                    ? 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                    : 'bg-blue-500 text-white hover:bg-blue-600'
                }`}
              >
                <i className={`fas ${merchant.verification_status === 'approved' ? 'fa-times' : 'fa-check'} mr-1`}></i>
                {merchant.verification_status === 'approved' ? 'إلغاء التوثيق' : 'توثيق'}
              </button>
              <button
                onClick={() => window.location.href = `tel:${merchant.phone}`}
                className="px-3 py-2 bg-green-500 hover:bg-green-600 text-white rounded-lg text-sm"
              >
                <i className="fas fa-phone"></i>
              </button>
            </div>
          </div>
        ))}
      </div>

      {filteredMerchants.length === 0 && (
        <div className="bg-white rounded-xl shadow-sm p-12 text-center text-gray-500">
          <i className="fas fa-store text-4xl mb-2"></i>
          <p>لا يوجد تجار / No merchants found</p>
        </div>
      )}
    </div>
  );
}
