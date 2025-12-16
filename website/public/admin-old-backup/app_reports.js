// =====================================================================================
// REPORTS & EXPORT FUNCTIONALITY
// =====================================================================================

// Export orders to CSV
async function exportOrdersToCSV(startDate, endDate) {
    try {
        showSuccess('جاري التصدير... / Exporting...');
        
        const { data: orders, error } = await supabaseClient
            .from('orders')
            .select(`
                *,
                merchant:users!merchant_id(name, phone, store_name),
                driver:users!driver_id(name, phone)
            `)
            .gte('created_at', startDate || '2020-01-01')
            .lte('created_at', endDate || new Date().toISOString())
            .order('created_at', { ascending: false });
        
        if (error) throw error;
        
        // Create CSV content
        const headers = [
            'Order ID',
            'Status',
            'Merchant Name',
            'Merchant Phone',
            'Driver Name',
            'Driver Phone',
            'Customer Name',
            'Customer Phone',
            'Pickup Address',
            'Delivery Address',
            'Total Amount',
            'Delivery Fee',
            'Created At',
            'Delivered At'
        ];
        
        let csv = headers.join(',') + '\n';
        
        orders.forEach(order => {
            const row = [
                order.id,
                order.status,
                order.merchant?.name || '',
                order.merchant?.phone || '',
                order.driver?.name || '',
                order.driver?.phone || '',
                order.customer_name,
                order.customer_phone,
                `"${order.pickup_address}"`,
                `"${order.delivery_address}"`,
                order.total_amount,
                order.delivery_fee,
                order.created_at,
                order.delivered_at || ''
            ];
            csv += row.join(',') + '\n';
        });
        
        // Download CSV
        const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
        const link = document.createElement('a');
        const url = URL.createObjectURL(blob);
        link.setAttribute('href', url);
        link.setAttribute('download', `orders_${new Date().toISOString().split('T')[0]}.csv`);
        link.style.visibility = 'hidden';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        
        showSuccess('✅ تم التصدير بنجاح / Exported successfully');
    } catch (error) {
        console.error('Export orders error:', error);
        showError('❌ خطأ في التصدير / Export error');
    }
}

// Export wallet transactions to CSV
async function exportTransactionsToCSV() {
    try {
        showSuccess('جاري التصدير... / Exporting...');
        
        const { data: transactions, error } = await supabaseClient
            .from('wallet_transactions')
            .select('*')
            .order('created_at', { ascending: false });
        
        if (error) throw error;
        
        const headers = [
            'Transaction ID',
            'Merchant ID',
            'Type',
            'Amount',
            'Balance Before',
            'Balance After',
            'Payment Method',
            'Notes',
            'Created At'
        ];
        
        let csv = headers.join(',') + '\n';
        
        transactions.forEach(tx => {
            const row = [
                tx.id,
                tx.merchant_id,
                tx.transaction_type,
                tx.amount,
                tx.balance_before,
                tx.balance_after,
                tx.payment_method || '',
                `"${tx.notes || ''}"`,
                tx.created_at
            ];
            csv += row.join(',') + '\n';
        });
        
        const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
        const link = document.createElement('a');
        const url = URL.createObjectURL(blob);
        link.setAttribute('href', url);
        link.setAttribute('download', `transactions_${new Date().toISOString().split('T')[0]}.csv`);
        link.style.visibility = 'hidden';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        
        showSuccess('✅ تم التصدير بنجاح / Exported successfully');
    } catch (error) {
        console.error('Export transactions error:', error);
        showError('❌ خطأ في التصدير / Export error');
    }
}

// Export users to CSV
async function exportUsersToCSV(role = null) {
    try {
        showSuccess('جاري التصدير... / Exporting...');
        
        let query = supabaseClient
            .from('users')
            .select('*')
            .order('created_at', { ascending: false });
        
        if (role) {
            query = query.eq('role', role);
        }
        
        const { data: users, error } = await query;
        
        if (error) throw error;
        
        const headers = [
            'User ID',
            'Name',
            'Phone',
            'Role',
            'Is Online',
            'Is Verified',
            'Store Name',
            'Vehicle Type',
            'Created At',
            'Last Seen'
        ];
        
        let csv = headers.join(',') + '\n';
        
        users.forEach(user => {
            const row = [
                user.id,
                user.name || '',
                user.phone,
                user.role || 'customer',
                user.is_online ? 'Yes' : 'No',
                user.manual_verified ? 'Yes' : 'No',
                user.store_name || '',
                user.vehicle_type || '',
                user.created_at,
                user.last_seen_at || ''
            ];
            csv += row.join(',') + '\n';
        });
        
        const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
        const link = document.createElement('a');
        const url = URL.createObjectURL(blob);
        link.setAttribute('href', url);
        link.setAttribute('download', `users_${role || 'all'}_${new Date().toISOString().split('T')[0]}.csv`);
        link.style.visibility = 'hidden';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        
        showSuccess('✅ تم التصدير بنجاح / Exported successfully');
    } catch (error) {
        console.error('Export users error:', error);
        showError('❌ خطأ في التصدير / Export error');
    }
}

// Generate and download comprehensive report
async function generateComprehensiveReport() {
    try {
        showSuccess('جاري إنشاء التقرير... / Generating report...');
        
        // Get all data
        const [
            { data: summary },
            { data: dailyReport },
            { data: topDrivers }
        ] = await Promise.all([
            supabaseClient.rpc('get_financial_summary', {
                p_start_date: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
                p_end_date: new Date().toISOString()
            }),
            supabaseClient.rpc('get_daily_revenue_report', { p_days: 30 }),
            supabaseClient.rpc('get_top_drivers', { p_limit: 10, p_days: 30 })
        ]);
        
        // Create HTML report
        const reportHTML = `
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <title>Hur Delivery - Monthly Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #3B82F6; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #3B82F6; color: white; }
        .summary-box { background: #EFF6FF; padding: 15px; margin: 10px 0; border-radius: 8px; }
    </style>
</head>
<body>
    <h1>🚚 Hur Delivery - تقرير شهري / Monthly Report</h1>
    <p><strong>التاريخ / Date:</strong> ${new Date().toLocaleDateString('ar-IQ')}</p>
    <p><strong>الفترة / Period:</strong> آخر 30 يوم / Last 30 Days</p>
    
    <div class="summary-box">
        <h2>الملخص المالي / Financial Summary</h2>
        <p><strong>إجمالي الإيرادات / Total Revenue:</strong> ${formatCurrency(summary.revenue.total)}</p>
        <p><strong>العمولات / Commission:</strong> ${formatCurrency(summary.revenue.commission)}</p>
        <p><strong>صافي الربح / Net Profit:</strong> ${formatCurrency(summary.revenue.net)}</p>
        <p><strong>الطلبات المكتملة / Completed Orders:</strong> ${summary.orders.completed}</p>
        <p><strong>معدل الإكمال / Completion Rate:</strong> ${summary.orders.completion_rate}%</p>
    </div>
    
    <h2>التقرير اليومي / Daily Report</h2>
    <table>
        <thead>
            <tr>
                <th>التاريخ / Date</th>
                <th>الطلبات / Orders</th>
                <th>المكتملة / Completed</th>
                <th>الإيرادات / Revenue</th>
                <th>العمولة / Commission</th>
            </tr>
        </thead>
        <tbody>
            ${dailyReport.map(day => `
                <tr>
                    <td>${new Date(day.report_date).toLocaleDateString('ar-IQ')}</td>
                    <td>${day.total_orders}</td>
                    <td>${day.completed_orders}</td>
                    <td>${formatCurrency(day.total_revenue)}</td>
                    <td>${formatCurrency(day.commission_earned)}</td>
                </tr>
            `).join('')}
        </tbody>
    </table>
    
    <h2>أفضل السائقين / Top Drivers</h2>
    <table>
        <thead>
            <tr>
                <th>المرتبة / Rank</th>
                <th>الاسم / Name</th>
                <th>الطلبات / Orders</th>
                <th>الأرباح / Earnings</th>
                <th>التقييم / Rating</th>
            </tr>
        </thead>
        <tbody>
            ${topDrivers.map((driver, idx) => `
                <tr>
                    <td>${idx + 1}</td>
                    <td>${driver.driver_name}</td>
                    <td>${driver.completed_orders}</td>
                    <td>${formatCurrency(driver.total_earnings)}</td>
                    <td>${driver.average_rating.toFixed(2)}/5.00</td>
                </tr>
            `).join('')}
        </tbody>
    </table>
    
    <hr>
    <p><small>تم الإنشاء بواسطة لوحة تحكم حر / Generated by Hur Admin Panel</small></p>
</body>
</html>
        `;
        
        // Download HTML report
        const blob = new Blob([reportHTML], { type: 'text/html;charset=utf-8;' });
        const link = document.createElement('a');
        const url = URL.createObjectURL(blob);
        link.setAttribute('href', url);
        link.setAttribute('download', `hur_report_${new Date().toISOString().split('T')[0]}.html`);
        link.style.visibility = 'hidden';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        
        showSuccess('✅ تم إنشاء التقرير / Report generated successfully');
    } catch (error) {
        console.error('Generate report error:', error);
        showError('❌ خطأ في إنشاء التقرير / Error generating report');
    }
}

// =====================================================================================
// BULK OPERATIONS
// =====================================================================================

async function bulkApproveUsers(userIds) {
    if (!confirm(`تأكيد الموافقة على ${userIds.length} مستخدم؟\nApprove ${userIds.length} users?`)) {
        return;
    }
    
    try {
        const { error } = await supabaseClient
            .from('users')
            .update({ manual_verified: true, verified_at: new Date().toISOString() })
            .in('id', userIds);
        
        if (error) throw error;
        
        alert(`✅ تمت الموافقة على ${userIds.length} مستخدم / ${userIds.length} users approved`);
        loadVerification();
    } catch (error) {
        console.error('Bulk approve error:', error);
        alert('❌ خطأ / Error');
    }
}

async function bulkSendNotification(userIds, title, message) {
    if (!userIds || userIds.length === 0) {
        alert('❌ لم يتم اختيار مستخدمين / No users selected');
        return;
    }
    
    if (!confirm(`إرسال إشعار لـ ${userIds.length} مستخدم؟\nSend notification to ${userIds.length} users?`)) {
        return;
    }
    
    try {
        const notifications = userIds.map(userId => ({
            user_id: userId,
            type: 'system',
            title: title,
            body: message,
            is_read: false,
            created_at: new Date().toISOString()
        }));
        
        const { error } = await supabaseClient
            .from('notifications')
            .insert(notifications);
        
        if (error) throw error;
        
        showSuccess(`✅ تم إرسال ${userIds.length} إشعار / ${userIds.length} notifications sent`);
    } catch (error) {
        console.error('Bulk notification error:', error);
        showError('❌ خطأ في الإرسال / Send error');
    }
}

// =====================================================================================
// DATE RANGE EXPORT
// =====================================================================================

function openDateRangeExport() {
    const modalBody = document.getElementById('walletModalBody');
    modalBody.innerHTML = `
        <form id="dateRangeExportForm" class="form-container">
            <h3>تصدير حسب التاريخ / Date Range Export</h3>
            
            <div class="form-group">
                <label>من تاريخ / Start Date</label>
                <input type="date" id="exportStartDate" class="form-control" required 
                       value="${new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]}">
            </div>
            
            <div class="form-group">
                <label>إلى تاريخ / End Date</label>
                <input type="date" id="exportEndDate" class="form-control" required 
                       value="${new Date().toISOString().split('T')[0]}">
            </div>
            
            <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                    <i class="fas fa-download"></i> تصدير الطلبات / Export Orders
                </button>
                <button type="button" class="btn btn-secondary" onclick="closeAllModals()">
                    <i class="fas fa-times"></i> إلغاء / Cancel
                </button>
            </div>
        </form>
    `;
    
    document.getElementById('dateRangeExportForm').onsubmit = (e) => {
        e.preventDefault();
        const startDate = document.getElementById('exportStartDate').value;
        const endDate = document.getElementById('exportEndDate').value;
        exportOrdersToCSV(startDate, endDate);
        closeAllModals();
    };
    
    openModal('walletModal');
}

// =====================================================================================
// DATABASE STATISTICS
// =====================================================================================

async function loadDatabaseStats() {
    const container = document.getElementById('databaseStatsContent');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        // Get counts from all major tables
        const [
            { count: usersCount },
            { count: ordersCount },
            { count: driversCount },
            { count: merchantsCount },
            { count: notificationsCount },
            { data: wallets }
        ] = await Promise.all([
            supabaseClient.from('users').select('*', { count: 'exact', head: true }),
            supabaseClient.from('orders').select('*', { count: 'exact', head: true }),
            supabaseClient.from('users').select('*', { count: 'exact', head: true }).eq('role', 'driver'),
            supabaseClient.from('users').select('*', { count: 'exact', head: true }).eq('role', 'merchant'),
            supabaseClient.from('notifications').select('*', { count: 'exact', head: true }),
            supabaseClient.from('merchant_wallets').select('balance')
        ]);
        
        const totalWalletBalance = wallets?.reduce((sum, w) => sum + parseFloat(w.balance), 0) || 0;
        
        container.innerHTML = `
            <div class="cards-grid">
                <div class="info-box" style="background: #EFF6FF;">
                    <i class="fas fa-users"></i>
                    <div>
                        <strong>إجمالي المستخدمين / Total Users</strong>
                        <h3>${usersCount || 0}</h3>
                    </div>
                </div>
                
                <div class="info-box" style="background: #F0FDF4;">
                    <i class="fas fa-box"></i>
                    <div>
                        <strong>إجمالي الطلبات / Total Orders</strong>
                        <h3>${ordersCount || 0}</h3>
                    </div>
                </div>
                
                <div class="info-box" style="background: #FEF3C7;">
                    <i class="fas fa-motorcycle"></i>
                    <div>
                        <strong>السائقون / Drivers</strong>
                        <h3>${driversCount || 0}</h3>
                    </div>
                </div>
                
                <div class="info-box" style="background: #F3E8FF;">
                    <i class="fas fa-store"></i>
                    <div>
                        <strong>التجار / Merchants</strong>
                        <h3>${merchantsCount || 0}</h3>
                    </div>
                </div>
                
                <div class="info-box" style="background: #FFEDD5;">
                    <i class="fas fa-bell"></i>
                    <div>
                        <strong>الإشعارات / Notifications</strong>
                        <h3>${notificationsCount || 0}</h3>
                    </div>
                </div>
                
                <div class="info-box" style="background: #E0E7FF;">
                    <i class="fas fa-wallet"></i>
                    <div>
                        <strong>إجمالي المحافظ / Total Wallet Balance</strong>
                        <h3>${formatCurrency(totalWalletBalance)}</h3>
                    </div>
                </div>
            </div>
            
            <div style="margin-top: 20px; padding: 15px; background: #F9FAFB; border-radius: 8px;">
                <p><strong>آخر تحديث / Last Updated:</strong> ${new Date().toLocaleString('ar-IQ')}</p>
            </div>
        `;
        
    } catch (error) {
        console.error('Load database stats error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل الإحصائيات / Error loading stats</p>';
    }
}

// =====================================================================================
// EXPORT FUNCTIONS
// =====================================================================================

window.exportOrdersToCSV = exportOrdersToCSV;
window.exportTransactionsToCSV = exportTransactionsToCSV;
window.exportUsersToCSV = exportUsersToCSV;
window.generateComprehensiveReport = generateComprehensiveReport;
window.bulkApproveUsers = bulkApproveUsers;
window.bulkSendNotification = bulkSendNotification;
window.openDateRangeExport = openDateRangeExport;
window.loadDatabaseStats = loadDatabaseStats;

// =====================================================================================
// END OF FILE
// =====================================================================================

