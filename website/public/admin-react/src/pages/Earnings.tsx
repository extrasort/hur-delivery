import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase-admin';
import { config } from '../lib/config';

export default function Earnings() {
  const [totalEarnings, setTotalEarnings] = useState(0);
  const [todayEarnings, setTodayEarnings] = useState(0);
  const [weekEarnings, setWeekEarnings] = useState(0);
  const [monthEarnings, setMonthEarnings] = useState(0);
  const [loading, setLoading] = useState(true);
  const [transactions, setTransactions] = useState<any[]>([]);
  const [topupCount, setTopupCount] = useState(0);
  const [totalSpent, setTotalSpent] = useState(0);
  const [todaySpent, setTodaySpent] = useState(0);
  const [weekSpent, setWeekSpent] = useState(0);
  const [monthSpent, setMonthSpent] = useState(0);

  useEffect(() => {
    loadEarnings();

    // Real-time subscription for wallet transactions (only if table exists)
    const channel = supabase
      .channel('earnings-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'wallet_transactions' }, () => {
        loadEarnings();
      })
      .subscribe();

    return () => {
      channel.unsubscribe();
    };
  }, []);

  const loadEarnings = async () => {
    setLoading(true);
    try {
      // Load wallet topups (transaction_type = 'top_up') and order fees (transaction_type = 'order_fee')
      const { data, error } = await supabase
        .from('wallet_transactions')
        .select('amount, created_at, transaction_type, notes')
        .order('created_at', { ascending: false });

      // Handle missing table gracefully
      if (error) {
        if (error.code === 'PGRST116' || error.code === '42P01' || error.code === 'PGRST200' || error.message?.includes('does not exist')) {
          // Table doesn't exist, set empty state
          setTotalEarnings(0);
          setTodayEarnings(0);
          setWeekEarnings(0);
          setMonthEarnings(0);
          setTotalSpent(0);
          setTodaySpent(0);
          setWeekSpent(0);
          setMonthSpent(0);
          setTransactions([]);
          setTopupCount(0);
          setLoading(false);
          return;
        }
        console.error('Error loading earnings:', error);
        setLoading(false);
        return;
      }

      // Filter topups - any transaction with positive amount that is a top_up, refund, or adjustment
      // Exclude initial_gift as it's not counted as earnings
      // Also include positive amounts without a type (backward compatibility)
      const topups = (data || []).filter((txn) => {
        const amount = txn.amount ?? 0;
        const type = txn.transaction_type;
        // Topups are positive amounts with transaction_type = 'top_up', 'refund', or 'adjustment'
        // Exclude 'initial_gift' as it's not counted as earnings
        // Also include any positive amount if type is missing (for backward compatibility)
        if (amount <= 0) return false;
        if (!type) return true; // Backward compatibility
        // Exclude initial_gift
        if (type === 'initial_gift') return false;
        return type === 'top_up' || type === 'refund' || type === 'adjustment';
      });

      // Filter order fees (negative amounts with transaction_type = 'order_fee')
      const orderFees = (data || []).filter((txn) => {
        const amount = txn.amount ?? 0;
        const type = txn.transaction_type;
        return amount < 0 && type === 'order_fee';
      });

      // Calculate totals
      const totalTopups = topups.reduce((sum, txn) => sum + (txn.amount || 0), 0);
      const totalSpentAmount = Math.abs(orderFees.reduce((sum, txn) => sum + (txn.amount || 0), 0));

      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

      const todayTopups = topups.filter(t => new Date(t.created_at) >= today)
        .reduce((sum, t) => sum + (t.amount || 0), 0) || 0;

      const weekTopups = topups.filter(t => new Date(t.created_at) >= weekAgo)
        .reduce((sum, t) => sum + (t.amount || 0), 0) || 0;

      const monthTopups = topups.filter(t => new Date(t.created_at) >= monthStart)
        .reduce((sum, t) => sum + (t.amount || 0), 0) || 0;

      const todaySpentAmount = Math.abs(orderFees.filter(t => new Date(t.created_at) >= today)
        .reduce((sum, t) => sum + (t.amount || 0), 0)) || 0;

      const weekSpentAmount = Math.abs(orderFees.filter(t => new Date(t.created_at) >= weekAgo)
        .reduce((sum, t) => sum + (t.amount || 0), 0)) || 0;

      const monthSpentAmount = Math.abs(orderFees.filter(t => new Date(t.created_at) >= monthStart)
        .reduce((sum, t) => sum + (t.amount || 0), 0)) || 0;

      setTotalEarnings(totalTopups);
      setTodayEarnings(todayTopups);
      setWeekEarnings(weekTopups);
      setMonthEarnings(monthTopups);
      setTotalSpent(totalSpentAmount);
      setTodaySpent(todaySpentAmount);
      setWeekSpent(weekSpentAmount);
      setMonthSpent(monthSpentAmount);
      setTransactions(topups);
      setTopupCount(topups.length);
    } catch (error) {
      console.error('Error loading earnings:', error);
    } finally {
      setLoading(false);
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
        <h2 className="text-2xl font-bold text-gray-900">الأرباح / Earnings</h2>
        <p className="text-gray-600 text-sm mt-1">الإيرادات من تعبئة المحافظ / Revenue from wallet topups</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-gradient-to-br from-green-500 to-green-600 rounded-xl shadow-lg p-6 text-white">
          <div className="flex items-center justify-between mb-2">
            <p className="text-green-100">اليوم / Today</p>
            <i className="fas fa-calendar-day text-2xl text-green-200"></i>
          </div>
          <p className="text-3xl font-bold">{todayEarnings.toLocaleString()}</p>
          <p className="text-sm text-green-100 mt-1">{config.currencySymbol}</p>
        </div>

        <div className="bg-gradient-to-br from-blue-500 to-blue-600 rounded-xl shadow-lg p-6 text-white">
          <div className="flex items-center justify-between mb-2">
            <p className="text-blue-100">هذا الأسبوع / This Week</p>
            <i className="fas fa-calendar-week text-2xl text-blue-200"></i>
          </div>
          <p className="text-3xl font-bold">{weekEarnings.toLocaleString()}</p>
          <p className="text-sm text-blue-100 mt-1">{config.currencySymbol}</p>
        </div>

        <div className="bg-gradient-to-br from-purple-500 to-purple-600 rounded-xl shadow-lg p-6 text-white">
          <div className="flex items-center justify-between mb-2">
            <p className="text-purple-100">هذا الشهر / This Month</p>
            <i className="fas fa-calendar-alt text-2xl text-purple-200"></i>
          </div>
          <p className="text-3xl font-bold">{monthEarnings.toLocaleString()}</p>
          <p className="text-sm text-purple-100 mt-1">{config.currencySymbol}</p>
        </div>

        <div className="bg-gradient-to-br from-yellow-500 to-yellow-600 rounded-xl shadow-lg p-6 text-white">
          <div className="flex items-center justify-between mb-2">
            <p className="text-yellow-100">الإجمالي / Total</p>
            <i className="fas fa-coins text-2xl text-yellow-200"></i>
          </div>
          <p className="text-3xl font-bold">{totalEarnings.toLocaleString()}</p>
          <p className="text-sm text-yellow-100 mt-1">{config.currencySymbol}</p>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm p-6">
        <h3 className="text-lg font-bold text-gray-900 mb-4">الإنفاق من المحافظ / Spending from Wallets</h3>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-6">
          <div className="text-center p-4 bg-red-50 rounded-lg border border-red-200">
            <p className="text-red-600 text-sm mb-1">اليوم / Today</p>
            <p className="text-2xl font-bold text-red-700">{todaySpent.toLocaleString()}</p>
            <p className="text-xs text-red-500 mt-1">{config.currencySymbol}</p>
          </div>
          <div className="text-center p-4 bg-red-50 rounded-lg border border-red-200">
            <p className="text-red-600 text-sm mb-1">هذا الأسبوع / This Week</p>
            <p className="text-2xl font-bold text-red-700">{weekSpent.toLocaleString()}</p>
            <p className="text-xs text-red-500 mt-1">{config.currencySymbol}</p>
          </div>
          <div className="text-center p-4 bg-red-50 rounded-lg border border-red-200">
            <p className="text-red-600 text-sm mb-1">هذا الشهر / This Month</p>
            <p className="text-2xl font-bold text-red-700">{monthSpent.toLocaleString()}</p>
            <p className="text-xs text-red-500 mt-1">{config.currencySymbol}</p>
          </div>
          <div className="text-center p-4 bg-red-50 rounded-lg border border-red-200">
            <p className="text-red-600 text-sm mb-1">الإجمالي / Total</p>
            <p className="text-2xl font-bold text-red-700">{totalSpent.toLocaleString()}</p>
            <p className="text-xs text-red-500 mt-1">{config.currencySymbol}</p>
          </div>
        </div>
        <h3 className="text-lg font-bold text-gray-900 mb-4">إحصائيات إضافية / Additional Stats</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="text-center p-4 bg-gray-50 rounded-lg">
            <p className="text-gray-600 text-sm mb-1">عدد عمليات التعبئة</p>
            <p className="text-2xl font-bold text-gray-900">{topupCount}</p>
            <p className="text-xs text-gray-500 mt-1">Total Topups</p>
          </div>

          <div className="text-center p-4 bg-gray-50 rounded-lg">
            <p className="text-gray-600 text-sm mb-1">متوسط مبلغ التعبئة</p>
            <p className="text-2xl font-bold text-gray-900">
              {topupCount > 0 ? Math.round(totalEarnings / topupCount).toLocaleString() : 0}
            </p>
            <p className="text-xs text-gray-500 mt-1">Average Topup Amount</p>
          </div>

          <div className="text-center p-4 bg-gray-50 rounded-lg">
            <p className="text-gray-600 text-sm mb-1">صافي الربح / Net Profit</p>
            <p className="text-2xl font-bold text-green-600">
              {(totalEarnings - totalSpent).toLocaleString()}
            </p>
            <p className="text-xs text-gray-500 mt-1">{config.currencySymbol}</p>
          </div>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm overflow-hidden">
        <div className="p-6 border-b border-gray-200">
          <h3 className="text-lg font-bold text-gray-900">آخر عمليات التعبئة / Recent Topups</h3>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">المبلغ / Amount</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">الوصف / Description</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">التاريخ / Date</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {transactions.slice(0, 10).map((txn, idx) => (
                <tr key={idx} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className="text-sm font-bold text-green-600">
                      +{txn.amount.toLocaleString()} {config.currencySymbol}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-700">{txn.notes || 'تعبئة محفظة / Wallet topup'}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {new Date(txn.created_at).toLocaleString('ar-IQ')}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {transactions.length === 0 && (
          <div className="text-center py-12 text-gray-500">
            <i className="fas fa-wallet text-4xl mb-2"></i>
            <p>لا توجد عمليات تعبئة / No topups yet</p>
          </div>
        )}
      </div>

      <div className="bg-gradient-to-r from-primary-500 to-primary-600 rounded-xl shadow-lg p-6 text-white">
        <div className="flex items-center gap-4">
          <div className="w-16 h-16 bg-white bg-opacity-20 rounded-full flex items-center justify-center">
            <i className="fas fa-chart-line text-3xl"></i>
          </div>
          <div className="flex-1">
            <h3 className="text-xl font-bold mb-1">أداء ممتاز! / Excellent Performance!</h3>
            <p className="text-primary-100">جميع الإيرادات محسوبة من عمليات تعبئة المحافظ فقط.</p>
            <p className="text-sm text-primary-100">All revenue calculated from wallet topups only.</p>
          </div>
        </div>
      </div>
    </div>
  );
}
