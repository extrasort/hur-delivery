import { useEffect, useState } from 'react';
import { supabaseAdmin, type User } from '../lib/supabase-admin';

interface Transaction {
  id: string;
  user_id: string;
  user_name?: string;
  amount: number;
  type: 'credit' | 'debit';
  description?: string;
  created_at: string;
}

export default function Wallets() {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'credit' | 'debit'>('all');
  const [showTopupModal, setShowTopupModal] = useState(false);
  const [userQuery, setUserQuery] = useState('');
  const [userResults, setUserResults] = useState<User[]>([]);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [topupAmount, setTopupAmount] = useState('');
  const [topupMethod, setTopupMethod] = useState('admin_manual');
  const [topupNotes, setTopupNotes] = useState('');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    loadTransactions();
  }, []);

  useEffect(() => {
    if (showTopupModal) {
      searchUsers(userQuery);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [showTopupModal, userQuery]);

  const loadTransactions = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabaseAdmin
        .from('wallet_transactions')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(100);

      // Handle missing table gracefully
      if (error) {
        if (error.code === 'PGRST116' || error.message?.includes('does not exist') || error.code === '42P01') {
          // Table doesn't exist, set empty state
          setTransactions([]);
          return;
        }
        throw error;
      }

      // wallet_transactions uses merchant_id, not user_id
      const merchantIds = Array.from(new Set((data || []).map((t) => (t as any).merchant_id || t.user_id).filter(Boolean)));
      let usersById: Record<string, { name?: string }> = {};
      if (merchantIds.length) {
        const { data: userRows } = await supabaseAdmin
          .from('users')
          .select('id, name')
          .in('id', merchantIds);
        usersById = (userRows || []).reduce((acc, user) => {
          acc[user.id] = { name: user.name || 'Unknown' };
          return acc;
        }, {} as Record<string, { name?: string }>);
      }

      const formatted = (data || []).map((t) => {
        const merchantId = (t as any).merchant_id || t.user_id;
        const transactionType = (t as any).transaction_type || t.type;
        // Determine type based on transaction_type or amount sign
        const resolvedType: 'credit' | 'debit' = transactionType 
          ? (transactionType === 'top_up' || transactionType === 'initial_gift' || transactionType === 'refund' || transactionType === 'adjustment' ? 'credit' : 'debit')
          : ((t.amount ?? 0) >= 0 ? 'credit' : 'debit');
        
        return {
          id: t.id,
          user_id: merchantId,
          user_name: usersById[merchantId]?.name || 'Unknown',
          amount: t.amount || 0, // Keep original amount (positive for credits, negative for debits)
          type: resolvedType,
          description: t.description || (t as any).notes || 'Transaction',
          created_at: t.created_at,
        };
      });

      setTransactions(formatted);
    } catch (error) {
      console.error('Error loading transactions:', error);
    } finally {
      setLoading(false);
    }
  };

  const searchUsers = async (query: string) => {
    if (!showTopupModal) return;

    try {
      let request = supabaseAdmin
        .from('users')
        .select('id, name, phone, role')
        .order('created_at', { ascending: false })
        .limit(20);

      const trimmed = query.trim();
      if (trimmed) {
        request = request.or(`name.ilike.%${trimmed}%,phone.ilike.%${trimmed}%`);
      }

      const { data, error } = await request;
      if (error) {
        console.error('Error searching users - details:', {
          message: error.message,
          code: error.code,
          details: error.details,
          hint: error.hint,
        });
        throw error;
      }
      setUserResults((data || []) as User[]);
    } catch (error: any) {
      console.error('Error searching users:', error);
      if (error?.code === 'PGRST301' || error?.message?.includes('permission denied')) {
        console.error('RLS policy is blocking access. Please ensure admin RLS policies are set up.');
      }
      setUserResults([]);
    }
  };

  const handleTopup = async () => {
    if (!selectedUser || !topupAmount) {
      alert('الرجاء اختيار مستخدم وإدخال المبلغ');
      return;
    }

    const numericAmount = Number(topupAmount);
    if (Number.isNaN(numericAmount) || numericAmount <= 0) {
      alert('الرجاء إدخال مبلغ صالح');
      return;
    }

    setSubmitting(true);
    try {
      const { error } = await supabaseAdmin.rpc('add_wallet_balance', {
        p_merchant_id: selectedUser.id,
        p_amount: numericAmount,
        p_payment_method: topupMethod,
        p_notes: topupNotes?.trim() || null,
      });

      if (error) throw error;

      await loadTransactions();
      setTopupAmount('');
      setTopupMethod('admin_manual');
      setTopupNotes('');
      setSelectedUser(null);
      setShowTopupModal(false);
      alert('تم إضافة الرصيد بنجاح');
    } catch (error: any) {
      console.error('Error topping up wallet:', error);
      alert(error.message || 'فشل إضافة الرصيد');
    } finally {
      setSubmitting(false);
    }
  };

  const filteredTransactions = transactions.filter(
    (t) => filter === 'all' || t.type === filter
  );

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between flex-wrap gap-4">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">المحافظ / Wallets</h2>
          <p className="text-gray-600 text-sm mt-1">
            سجل المعاملات المالية / Transaction history
          </p>
        </div>

        <button
          onClick={() => setShowTopupModal(true)}
          className="px-4 py-2 bg-primary-500 hover:bg-primary-600 text-white text-sm rounded-lg transition-colors flex items-center gap-2"
        >
          <i className="fas fa-plus-circle"></i>
          إضافة رصيد / Top Up
        </button>
      </div>

      <div className="bg-white rounded-xl shadow-sm p-4">
        <div className="flex gap-2">
          <button
            onClick={() => setFilter('all')}
            className={`px-4 py-2 rounded-lg text-sm font-medium ${
              filter === 'all' ? 'bg-primary-500 text-white' : 'bg-gray-100 text-gray-700'
            }`}
          >
            الكل / All
          </button>
          <button
            onClick={() => setFilter('credit')}
            className={`px-4 py-2 rounded-lg text-sm font-medium ${
              filter === 'credit' ? 'bg-green-500 text-white' : 'bg-gray-100 text-gray-700'
            }`}
          >
            إضافة / Credit
          </button>
          <button
            onClick={() => setFilter('debit')}
            className={`px-4 py-2 rounded-lg text-sm font-medium ${
              filter === 'debit' ? 'bg-red-500 text-white' : 'bg-gray-100 text-gray-700'
            }`}
          >
            خصم / Debit
          </button>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">
                  المستخدم / User
                </th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">
                  النوع / Type
                </th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">
                  المبلغ / Amount
                </th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">
                  الوصف / Description
                </th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">
                  التاريخ / Date
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filteredTransactions.map((transaction) => (
                <tr key={transaction.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4 text-sm text-gray-900">{transaction.user_name}</td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span
                      className={`px-3 py-1 text-xs font-medium rounded-full ${
                        transaction.type === 'credit'
                          ? 'bg-green-100 text-green-800'
                          : 'bg-red-100 text-red-800'
                      }`}
                    >
                      {transaction.type === 'credit' ? 'إضافة / Credit' : 'خصم / Debit'}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <span className={transaction.type === 'credit' ? 'text-green-600' : 'text-red-600'}>
                      {transaction.type === 'credit' ? '+' : '-'}
                      {Math.abs(transaction.amount).toLocaleString()} IQD
                    </span>
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-600">
                    {transaction.description || '-'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {new Date(transaction.created_at).toLocaleString('ar-IQ')}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {filteredTransactions.length === 0 && (
          <div className="text-center py-12 text-gray-500">
            <i className="fas fa-wallet text-4xl mb-2"></i>
            <p>لا توجد معاملات / No transactions found</p>
          </div>
        )}
      </div>

      {showTopupModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl shadow-xl max-w-lg w-full max-h-[90vh] overflow-hidden">
            <div className="flex items-center justify-between p-5 border-b border-gray-200">
              <h3 className="text-xl font-bold text-gray-900">إضافة رصيد / Add Balance</h3>
              <button
                onClick={() => {
                  setShowTopupModal(false);
                  setSelectedUser(null);
                  setTopupAmount('');
                  setTopupMethod('admin_manual');
                  setTopupNotes('');
                }}
                className="text-gray-400 hover:text-gray-600"
              >
                <i className="fas fa-times text-xl"></i>
              </button>
            </div>

            <div className="p-5 space-y-5 overflow-y-auto">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  البحث عن المستخدم / Search user
                </label>
                <input
                  type="text"
                  value={userQuery}
                  onChange={(e) => setUserQuery(e.target.value)}
                  placeholder="الاسم أو رقم الهاتف"
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                />
              </div>

              <div>
                <p className="text-xs text-gray-500 mb-2">اختر مستخدمًا من القائمة</p>
                <div className="max-h-48 overflow-y-auto space-y-2">
                  {userResults.map((user) => (
                    <button
                      key={user.id}
                      onClick={() => setSelectedUser(user)}
                      className={`w-full text-right px-4 py-3 rounded-lg border transition-colors ${
                        selectedUser?.id === user.id
                          ? 'border-primary-500 bg-primary-50'
                          : 'border-gray-200 bg-gray-50 hover:bg-gray-100'
                      }`}
                    >
                      <div>
                        <p className="font-medium text-gray-900">{user.name || 'مستخدم بدون اسم'}</p>
                        <p className="text-xs text-gray-500">{user.phone || 'لا يوجد هاتف'}</p>
                      </div>
                    </button>
                  ))}
                  {userResults.length === 0 && (
                    <p className="text-sm text-gray-500 text-center py-6">لا يوجد مستخدمون مطابقون</p>
                  )}
                </div>
              </div>

              <div className="grid grid-cols-1 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    المبلغ / Amount (IQD)
                  </label>
                  <input
                    type="number"
                    value={topupAmount}
                    onChange={(e) => setTopupAmount(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                    placeholder="أدخل المبلغ"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    طريقة الدفع / Payment Method
                  </label>
                  <select
                    value={topupMethod}
                    onChange={(e) => setTopupMethod(e.target.value)}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none"
                  >
                    <option value="admin_manual">تحويل إداري / Admin Manual</option>
                    <option value="admin_cash">نقداً / Admin Cash</option>
                    <option value="admin_bank_transfer">تحويل بنكي / Admin Bank Transfer</option>
                    <option value="admin_pos">جهاز POS / Admin POS</option>
                    <option value="admin_transfer">تحويل إداري مباشر / Admin Transfer</option>
                    <option value="admin_adjustment">تعديل إداري / Admin Adjustment</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    الملاحظات / Notes
                  </label>
                  <textarea
                    value={topupNotes}
                    onChange={(e) => setTopupNotes(e.target.value)}
                    rows={3}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 outline-none resize-none"
                    placeholder="ملاحظات اختيارية حول عملية الشحن"
                  />
                </div>
                <p className="text-xs text-gray-500">
                  سيتم تسجيل هذه العملية كرصيد مضاف إلى محفظة المستخدم المختار.
                </p>
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 p-5 border-t border-gray-200">
              <button
                onClick={() => {
                  setShowTopupModal(false);
                  setSelectedUser(null);
                  setTopupAmount('');
                  setTopupMethod('admin_manual');
                  setTopupNotes('');
                }}
                className="px-6 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
              >
                إلغاء / Cancel
              </button>
              <button
                onClick={handleTopup}
                disabled={submitting || !selectedUser || !topupAmount}
                className="px-6 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-lg disabled:opacity-50"
              >
                {submitting ? 'جاري الإضافة...' : 'إضافة / Add'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
