/**
 * Hur Delivery Admin Panel - Main Application
 * Comprehensive management system for all app functionality
 */

// Initialize Supabase Client
const { createClient } = supabase;
let supabaseClient = null;
let currentUser = null;
let realtimeSubscriptions = [];
let messagingInitialized = false;
let messagingConversationsUnsub = null;
let messagingMessagesUnsub = null;
const messagingElements = {};

// Initialize App
document.addEventListener('DOMContentLoaded', () => {
    initializeSupabase();
    setupEventListeners();
    checkAuthStatus();
});

// Initialize Supabase
function initializeSupabase() {
    try {
        supabaseClient = createClient(CONFIG.SUPABASE_URL, CONFIG.SUPABASE_ANON_KEY);
        console.log('✅ Supabase initialized');
    } catch (error) {
        console.error('❌ Failed to initialize Supabase:', error);
        showError('Failed to connect to database. Please check configuration.');
    }
}

// Setup Event Listeners
function setupEventListeners() {
    // Login Form
    document.getElementById('loginForm')?.addEventListener('submit', handleLogin);
    
    // Logout
    document.getElementById('logoutBtn')?.addEventListener('click', handleLogout);
    
    // Navigation
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            const page = item.dataset.page;
            navigateToPage(page);
        });
    });
    
    // Sidebar Toggle
    document.getElementById('sidebarToggle')?.addEventListener('click', toggleSidebar);
    
    // Close Modals
    document.querySelectorAll('.close-modal').forEach(btn => {
        btn.addEventListener('click', closeAllModals);
    });
    
    // Click outside modal to close
    document.querySelectorAll('.modal').forEach(modal => {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) closeAllModals();
        });
    });
    
    // Refresh Buttons
    document.getElementById('refreshUsers')?.addEventListener('click', () => loadUsers());
    document.getElementById('refreshOrders')?.addEventListener('click', () => loadOrders());
    document.getElementById('refreshDrivers')?.addEventListener('click', () => loadDrivers());
    document.getElementById('refreshMerchants')?.addEventListener('click', () => loadMerchants());
    document.getElementById('refreshWallets')?.addEventListener('click', () => loadWallets());
    document.getElementById('refreshEarnings')?.addEventListener('click', () => loadEarnings());
    document.getElementById('refreshNotifications')?.addEventListener('click', () => loadNotifications());
    document.getElementById('refreshVerification')?.addEventListener('click', () => loadVerification());
    document.getElementById('refreshSessions')?.addEventListener('click', () => loadSessions());
    document.getElementById('refreshTracking')?.addEventListener('click', () => loadTracking());
    
    // Search Inputs
    document.getElementById('usersSearch')?.addEventListener('input', (e) => filterTable('usersTable', e.target.value));
    document.getElementById('ordersSearch')?.addEventListener('input', (e) => filterTable('ordersTable', e.target.value));
    document.getElementById('driversSearch')?.addEventListener('input', (e) => filterTable('driversTable', e.target.value));
    document.getElementById('merchantsSearch')?.addEventListener('input', (e) => filterTable('merchantsSearch', e.target.value));
    document.getElementById('walletsSearch')?.addEventListener('input', (e) => filterTable('walletsTable', e.target.value));
    document.getElementById('earningsSearch')?.addEventListener('input', (e) => filterTable('earningsTable', e.target.value));
    document.getElementById('sessionsSearch')?.addEventListener('input', (e) => filterTable('sessionsTable', e.target.value));
    
    // Filter Selects
    document.getElementById('usersRoleFilter')?.addEventListener('change', loadUsers);
    document.getElementById('ordersStatusFilter')?.addEventListener('change', loadOrders);
    document.getElementById('driversStatusFilter')?.addEventListener('change', loadDrivers);
    document.getElementById('merchantsStatusFilter')?.addEventListener('change', loadMerchants);
    document.getElementById('earningsStatusFilter')?.addEventListener('change', loadEarnings);
    document.getElementById('verificationRoleFilter')?.addEventListener('change', loadVerification);
    
    // Bulk Notification
    document.getElementById('sendBulkNotification')?.addEventListener('click', () => openModal('notificationModal'));
    document.getElementById('notificationForm')?.addEventListener('submit', handleSendNotification);

    // Messaging events
    document.getElementById('messagingConversations')?.addEventListener('click', handleMessagingConversationClick);
    document.getElementById('messagingSendBtn')?.addEventListener('click', handleMessagingSend);
    document.getElementById('messagingCompose')?.addEventListener('keydown', handleMessagingComposerKeydown);
    document.getElementById('messagingRefreshBtn')?.addEventListener('click', refreshMessagingConversations);
}

// Authentication
async function checkAuthStatus() {
    const storedSession = localStorage.getItem('admin_session');
    if (storedSession) {
        try {
            const session = JSON.parse(storedSession);
            if (session?.user?.role === 'admin') {
                currentUser = session.user;
                showApp();
                loadDashboard();
                return;
            }
        } catch (e) {
            console.warn('Invalid stored admin session, clearing.');
        }
        localStorage.removeItem('admin_session');
    }
    showLogin();
}

/* Admin login uses username/password via edge function */

async function handleLogin(e) {
    e.preventDefault();
    const errorDiv = document.getElementById('loginError');
    errorDiv.textContent = '';
    errorDiv.classList.remove('active');
    
    const usernameInput = document.getElementById('loginUsername');
    const passwordInput = document.getElementById('loginPassword');
    const submitBtn = document.getElementById('loginSubmitBtn');
    
    const username = usernameInput?.value?.trim();
    const password = passwordInput?.value ?? '';
    
    if (!username || !password) {
        errorDiv.textContent = 'يرجى إدخال اسم المستخدم وكلمة المرور / Please enter username and password';
        errorDiv.classList.add('active');
        return;
    }
    
    const originalBtnText = submitBtn?.innerHTML;
    if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> جاري تسجيل الدخول...';
    }
    
    try {
        const { data, error } = await supabaseClient.functions.invoke('admin-login', {
            body: {
                username,
                password,
            },
        });
        
        if (error) throw error;
        
        if (!data || !data.success) {
            const message = data?.error || data?.message || 'فشل تسجيل الدخول / Login failed';
            throw new Error(message);
        }
        
        const session = data.session;
        if (!session || !session.access_token || !session.refresh_token) {
            throw new Error('فشل إنشاء جلسة المدير / Failed to establish admin session');
        }

        const { data: setSessionData, error: setSessionError } = await supabaseClient.auth.setSession({
            access_token: session.access_token,
            refresh_token: session.refresh_token,
        });

        if (setSessionError || !setSessionData?.session) {
            console.error('Admin setSession error:', setSessionError);
            throw new Error(setSessionError?.message || 'فشل إنشاء جلسة المدير / Failed to establish admin session');
        }

        const adminUser = setSessionData.session.user;
        const displayName = data.user?.name || adminUser?.user_metadata?.name || username;

        const adminSession = {
            user: {
                id: adminUser?.id || 'admin',
                username: data.user?.username || username,
                name: displayName,
                email: adminUser?.email,
                role: 'admin',
            },
            verified_at: new Date().toISOString(),
            supabase_session: {
                access_token: session.access_token,
                refresh_token: session.refresh_token,
                expires_in: session.expires_in,
                expires_at: session.expires_at,
            },
        };

        localStorage.setItem('admin_session', JSON.stringify(adminSession));
        currentUser = adminSession.user;
        showApp();
        loadDashboard();
    } catch (error) {
        console.error('Admin login error:', error);
        errorDiv.textContent = error.message || 'فشل تسجيل الدخول / Login failed';
        errorDiv.classList.add('active');
    } finally {
        if (submitBtn) {
            submitBtn.disabled = false;
            submitBtn.innerHTML = originalBtnText;
        }
        if (passwordInput) {
            passwordInput.value = '';
        }
    }
}

function showSuccess(message) {
    const errorDiv = document.getElementById('loginError');
    errorDiv.textContent = message;
    errorDiv.style.color = 'var(--success)';
    errorDiv.style.backgroundColor = '#D1FAE5';
    errorDiv.style.border = '1px solid var(--success)';
    errorDiv.style.borderRadius = 'var(--radius-md)';
    errorDiv.classList.add('active');
    setTimeout(() => {
        errorDiv.classList.remove('active');
        // Reset styles after hiding
        setTimeout(() => {
            errorDiv.style.color = '';
            errorDiv.style.backgroundColor = '';
            errorDiv.style.border = '';
            errorDiv.style.borderRadius = '';
        }, 300);
    }, 3000);
}

async function handleLogout() {
    try {
        // Clear stored admin session
        localStorage.removeItem('admin_session');

        // Sign out from Supabase Auth
        try {
            await supabaseClient?.auth?.signOut();
        } catch (signOutError) {
            console.warn('Supabase signOut warning:', signOutError);
        }
        
        // Reset state
        currentUser = null;
        unsubscribeFromRealtime();
        resetMessagingState();
        
        // Reset login form
        document.getElementById('loginUsername')?.focus();
        const usernameInput = document.getElementById('loginUsername');
        const passwordInput = document.getElementById('loginPassword');
        if (usernameInput) usernameInput.value = '';
        if (passwordInput) passwordInput.value = '';
        const errorDiv = document.getElementById('loginError');
        if (errorDiv) {
            errorDiv.textContent = '';
            errorDiv.classList.remove('active');
        }
        
        showLogin();
    } catch (error) {
        console.error('Logout error:', error);
        showLogin();
    }
}

function showLogin() {
    document.getElementById('loginScreen').style.display = 'flex';
    document.getElementById('appScreen').style.display = 'none';
}

function showApp() {
    document.getElementById('loginScreen').style.display = 'none';
    document.getElementById('appScreen').style.display = 'flex';
    document.getElementById('userName').textContent = currentUser?.name || currentUser?.username || 'Admin';
}

// Navigation
function navigateToPage(page) {
    // Update nav items
    document.querySelectorAll('.nav-item').forEach(item => {
        item.classList.remove('active');
        if (item.dataset.page === page) {
            item.classList.add('active');
        }
    });
    
    // Update pages
    document.querySelectorAll('.page').forEach(p => {
        p.classList.remove('active');
    });
    document.getElementById(page + 'Page')?.classList.add('active');
    
    // Update title
    const titles = {
        dashboard: 'لوحة التحكم / Dashboard',
        users: 'المستخدمون / Users',
        orders: 'الطلبات / Orders',
        drivers: 'السائقون / Drivers',
        merchants: 'التجار / Merchants',
        wallets: 'المحافظ / Wallets',
        earnings: 'الأرباح / Earnings',
        notifications: 'الإشعارات / Notifications',
        verification: 'التحقق من المستخدمين / User Verification',
        tracking: 'التتبع المباشر / Live Tracking',
        sessions: 'الجلسات / Device Sessions',
        financial: 'المالية / Financial',
        reviews: 'التقييمات / Reviews',
        'promo-codes': 'أكواد الخصم / Promo Codes',
        zones: 'مناطق التوصيل / Delivery Zones',
        blacklist: 'القائمة السوداء / Blacklist',
        messaging: 'دعم العملاء / Support Messaging',
        disputes: 'النزاعات / Disputes',
        customers: 'العملاء / Customers',
        announcements: 'الإعلانات / Announcements',
        performance: 'الأداء / Performance',
        analytics: 'التحليلات / Analytics',
        settings: 'الإعدادات / Settings',
        database: 'قاعدة البيانات / Database',
        health: 'Health Status / حالة الصحة'
    };
    document.getElementById('pageTitle').textContent = titles[page] || 'Admin Panel';
    
    // Load page data
    switch(page) {
        case 'dashboard': loadDashboard(); break;
        case 'users': loadUsers(); break;
        case 'orders': loadOrders(); break;
        case 'drivers': loadDrivers(); break;
        case 'merchants': loadMerchants(); break;
        case 'wallets': loadWallets(); break;
        case 'earnings': loadEarnings(); break;
        case 'notifications': loadNotifications(); break;
        case 'verification': loadVerification(); break;
        case 'tracking': loadTracking(); break;
        case 'emergency': 
            initializeEmergencyPage(); 
            startEmergencyAutoRefresh(); 
            break;
        case 'sessions': 
            stopEmergencyAutoRefresh(); 
            loadSessions(); 
            break;
        case 'financial': loadFinancialDashboard(); break;
        case 'messaging': 
            loadMessaging();
            break;
        case 'reviews': loadReviews(); break;
        case 'promo-codes': loadPromoCodes(); break;
        case 'zones': loadDeliveryZones(); break;
        case 'blacklist': loadBlacklist(); break;
        case 'disputes': loadDisputes(); break;
        case 'customers': loadCustomers(); break;
        case 'announcements': loadAnnouncements(); break;
        case 'performance': loadPerformance(); break;
        case 'system-config': loadSystemConfig(); break;
        case 'analytics': loadAnalytics(); break;
        case 'settings': loadSettings(); break;
        case 'database': loadDatabaseTools(); break;
        case 'health': 
            stopEmergencyAutoRefresh();
            initializeHealthPage(); 
            break;
        default:
            if (page !== 'emergency') {
                stopEmergencyAutoRefresh();
            }
    }
}

function toggleSidebar() {
    document.querySelector('.sidebar').classList.toggle('open');
}

// Dashboard
async function loadDashboard() {
    try {
        // Load statistics
        const [usersCount, ordersCount, driversData, merchantsData, pendingOrders, pendingVerifications] = await Promise.all([
            supabaseClient.from('users').select('id', { count: 'exact', head: true }),
            supabaseClient.from('orders').select('id', { count: 'exact', head: true }),
            supabaseClient.from('users').select('id').eq('role', 'driver').eq('is_online', true),
            supabaseClient.from('users').select('id').eq('role', 'merchant').eq('manual_verified', true),
            supabaseClient.from('orders').select('id').in('status', ['pending', 'assigned']),
            supabaseClient.from('users').select('id').eq('manual_verified', false)
        ]);
        
        document.getElementById('totalUsers').textContent = usersCount.count || 0;
        document.getElementById('totalOrders').textContent = ordersCount.count || 0;
        document.getElementById('activeDrivers').textContent = driversData.data?.length || 0;
        document.getElementById('activeMerchants').textContent = merchantsData.data?.length || 0;
        document.getElementById('pendingOrders').textContent = pendingOrders.data?.length || 0;
        document.getElementById('pendingVerifications').textContent = pendingVerifications.data?.length || 0;
        
        // Load charts
        await loadDashboardCharts();
        
        // Load recent orders
        await loadRecentOrders();
        
        // Setup realtime
        setupRealtimeSubscriptions();
    } catch (error) {
        console.error('Dashboard error:', error);
    }
}

// Store chart instances globally to prevent duplicates
let ordersChartInstance = null;
let usersChartInstance = null;

async function loadDashboardCharts() {
    // Destroy existing charts if they exist
    if (ordersChartInstance) {
        ordersChartInstance.destroy();
        ordersChartInstance = null;
    }
    if (usersChartInstance) {
        usersChartInstance.destroy();
        usersChartInstance = null;
    }
    
    // Orders Status Chart
    const { data: ordersByStatus } = await supabaseClient
        .from('orders')
        .select('status');
    
    const statusCounts = {};
    ordersByStatus?.forEach(order => {
        statusCounts[order.status] = (statusCounts[order.status] || 0) + 1;
    });
    
    ordersChartInstance = new Chart(document.getElementById('ordersChart'), {
        type: 'doughnut',
        data: {
            labels: Object.keys(statusCounts),
            datasets: [{
                data: Object.values(statusCounts),
                backgroundColor: [
                    '#F59E0B', // pending - orange
                    '#3B82F6', // assigned - blue
                    '#10B981', // accepted - green
                    '#8B5CF6', // on_the_way - purple
                    '#14B8A6', // delivered - teal
                    '#EF4444', // cancelled - red
                    '#6B7280'  // rejected - gray
                ]
            }]
        },
        options: {
            responsive: true,
            plugins: {
                legend: { position: 'bottom' }
            }
        }
    });
    
    // Users Distribution Chart
    const { data: usersByRole } = await supabaseClient
        .from('users')
        .select('role');
    
    const roleCounts = {};
    usersByRole?.forEach(user => {
        roleCounts[user.role] = (roleCounts[user.role] || 0) + 1;
    });
    
    usersChartInstance = new Chart(document.getElementById('usersChart'), {
        type: 'pie',
        data: {
            labels: Object.keys(roleCounts),
            datasets: [{
                data: Object.values(roleCounts),
                backgroundColor: ['#3B82F6', '#10B981', '#F59E0B', '#8B5CF6']
            }]
        },
        options: {
            responsive: true,
            plugins: {
                legend: { position: 'bottom' }
            }
        }
    });
}

async function loadRecentOrders() {
    const { data: orders } = await supabaseClient
        .from('orders')
        .select(`
            *,
            merchant:users!merchant_id(name, phone),
            driver:users!driver_id(name, phone)
        `)
        .order('created_at', { ascending: false })
        .limit(10);
    
    const container = document.getElementById('recentOrders');
    
    if (!orders || orders.length === 0) {
        container.innerHTML = '<p class="loading">لا توجد طلبات / No orders</p>';
        return;
    }
    
    const table = `
        <table>
            <thead>
                <tr>
                    <th>رقم الطلب / ID</th>
                    <th>التاجر / Merchant</th>
                    <th>السائق / Driver</th>
                    <th>العميل / Customer</th>
                    <th>الحالة / Status</th>
                    <th>المبلغ / Amount</th>
                    <th>التاريخ / Date</th>
                    <th>إجراءات / Actions</th>
                </tr>
            </thead>
            <tbody>
                ${orders.map(order => `
                    <tr>
                        <td>${order.id.substring(0, 8)}...</td>
                        <td>${order.merchant?.name || 'N/A'}</td>
                        <td>${order.driver?.name || 'غير مخصص / Unassigned'}</td>
                        <td>${order.customer_name}</td>
                        <td><span class="badge badge-${getStatusBadgeClass(order.status)}">${order.status}</span></td>
                        <td>${formatCurrency(order.total_amount + order.delivery_fee)}</td>
                        <td>${formatDate(order.created_at)}</td>
                        <td>
                            <button class="btn btn-sm btn-info" onclick="viewOrderDetails('${order.id}')">
                                <i class="fas fa-eye"></i>
                            </button>
                        </td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;
    
    container.innerHTML = table;
}

// Users Management
async function loadUsers() {
    const roleFilter = document.getElementById('usersRoleFilter')?.value;
    const container = document.getElementById('usersTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        let query = supabaseClient.from('users').select('*').order('created_at', { ascending: false });
        
        if (roleFilter) {
            query = query.eq('role', roleFilter);
        }
        
        const { data: users, error } = await query;
        
        if (error) throw error;
        
        if (!users || users.length === 0) {
            container.innerHTML = '<p class="loading">لا توجد بيانات / No data</p>';
            return;
        }
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>الاسم / Name</th>
                        <th>الهاتف / Phone</th>
                        <th>الدور / Role</th>
                        <th>مصدر المعرفة / Referral</th>
                        <th>الحالة / Status</th>
                        <th>التحقق / Verified</th>
                        <th>التاريخ / Date</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${users.map(user => `
                        <tr>
                            <td>${user.name}</td>
                            <td>${user.phone}</td>
                            <td><span class="badge badge-info">${user.role}</span></td>
                            <td>${formatReferralSource(user.referral_source)}</td>
                            <td><span class="status-${user.is_online ? 'online' : 'offline'}">${user.is_online ? 'متصل / Online' : 'غير متصل / Offline'}</span></td>
                            <td><span class="badge badge-${user.manual_verified ? 'success' : 'warning'}">${user.manual_verified ? 'موثق / Verified' : 'غير موثق / Unverified'}</span></td>
                            <td>${formatDate(user.created_at)}</td>
                            <td>
                                <div class="action-buttons">
                                    <button class="btn btn-sm btn-info" onclick="viewUser('${user.id}')" title="View Details">
                                        <i class="fas fa-eye"></i>
                                    </button>
                                    ${!user.manual_verified ? `
                                        <button class="btn btn-sm btn-success" onclick="verifyUser('${user.id}')" title="Verify">
                                            <i class="fas fa-check"></i>
                                        </button>
                                    ` : ''}
                                    ${user.role !== 'admin' ? `
                                        <button class="btn btn-sm btn-warning" onclick="promoteToAdmin('${user.id}', '${user.name}')" title="Promote to Admin">
                                            <i class="fas fa-user-shield"></i>
                                        </button>
                                    ` : ''}
                                    <button class="btn btn-sm btn-danger" onclick="deleteUser('${user.id}')" title="Delete">
                                        <i class="fas fa-trash"></i>
                                    </button>
                                </div>
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;
        
        container.innerHTML = table;
    } catch (error) {
        console.error('Load users error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

// Orders Management
async function loadOrders() {
    const statusFilter = document.getElementById('ordersStatusFilter')?.value;
    const container = document.getElementById('ordersTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        let query = supabaseClient
            .from('orders')
            .select(`
                *,
                merchant:users!merchant_id(name, phone),
                driver:users!driver_id(name, phone)
            `)
            .order('created_at', { ascending: false });
        
        if (statusFilter) {
            query = query.eq('status', statusFilter);
        }
        
        const { data: orders, error } = await query;
        
        if (error) throw error;
        
        if (!orders || orders.length === 0) {
            container.innerHTML = '<p class="loading">لا توجد طلبات / No orders</p>';
            return;
        }
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>رقم الطلب / ID</th>
                        <th>التاجر / Merchant</th>
                        <th>السائق / Driver</th>
                        <th>العميل / Customer</th>
                        <th>من / From</th>
                        <th>إلى / To</th>
                        <th>الحالة / Status</th>
                        <th>المبلغ / Amount</th>
                        <th>التاريخ / Date</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${orders.map(order => `
                        <tr>
                            <td>${order.id.substring(0, 8)}...</td>
                            <td>${order.merchant?.name || 'N/A'}<br><small>${order.merchant?.phone || ''}</small></td>
                            <td>${order.driver?.name || 'غير مخصص / Unassigned'}<br><small>${order.driver?.phone || ''}</small></td>
                            <td>${order.customer_name}<br><small>${order.customer_phone}</small></td>
                            <td>${order.pickup_address.substring(0, 30)}...</td>
                            <td>${order.delivery_address.substring(0, 30)}...</td>
                            <td><span class="badge badge-${getStatusBadgeClass(order.status)}">${order.status}</span></td>
                            <td>${formatCurrency(order.total_amount + order.delivery_fee)}</td>
                            <td>${formatDate(order.created_at)}</td>
                            <td>
                                <div class="action-buttons">
                                    <button class="btn btn-sm btn-info" onclick="viewOrderDetails('${order.id}')" title="View Details">
                                        <i class="fas fa-eye"></i>
                                    </button>
                                    ${!order.driver_id || order.status === 'pending' ? `
                                        <button class="btn btn-sm btn-success" onclick="assignDriver('${order.id}')" title="Assign Driver">
                                            <i class="fas fa-user-plus"></i>
                                        </button>
                                    ` : ''}
                                    ${order.driver_id && order.status !== 'delivered' && order.status !== 'cancelled' ? `
                                        <button class="btn btn-sm btn-warning" onclick="reassignOrder('${order.id}')" title="Reassign">
                                            <i class="fas fa-exchange-alt"></i>
                                        </button>
                                    ` : ''}
                                    ${order.status !== 'delivered' && order.status !== 'cancelled' ? `
                                        <button class="btn btn-sm btn-secondary" onclick="changeOrderStatus('${order.id}', '${order.status}')" title="Change Status">
                                            <i class="fas fa-edit"></i>
                                        </button>
                                    ` : ''}
                                    ${order.status !== 'delivered' && order.status !== 'cancelled' ? `
                                        <button class="btn btn-sm btn-primary" onclick="editOrderDetails('${order.id}')" title="Edit Details">
                                            <i class="fas fa-pencil-alt"></i>
                                        </button>
                                    ` : ''}
                                    ${order.status !== 'cancelled' && order.status !== 'delivered' ? `
                                        <button class="btn btn-sm btn-danger" onclick="cancelOrderWithRefund('${order.id}')" title="Cancel">
                                            <i class="fas fa-times-circle"></i>
                                        </button>
                                    ` : ''}
                                </div>
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;
        
        container.innerHTML = table;
    } catch (error) {
        console.error('Load orders error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

// Drivers Management
async function loadDrivers() {
    const statusFilter = document.getElementById('driversStatusFilter')?.value;
    const container = document.getElementById('driversTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        let query = supabaseClient
            .from('users')
            .select('*')
            .eq('role', 'driver')
            .order('created_at', { ascending: false });
        
        if (statusFilter === 'online') query = query.eq('is_online', true);
        if (statusFilter === 'offline') query = query.eq('is_online', false);
        if (statusFilter === 'verified') query = query.eq('manual_verified', true);
        if (statusFilter === 'unverified') query = query.eq('manual_verified', false);
        
        const { data: drivers, error } = await query;
        
        if (error) throw error;
        
        // Get driver statistics
        const driversWithStats = await Promise.all(drivers.map(async (driver) => {
            const { data: orders } = await supabaseClient
                .from('orders')
                .select('id, status')
                .eq('driver_id', driver.id);
            
            const { data: earnings } = await supabaseClient
                .from('earnings')
                .select('net_amount')
                .eq('driver_id', driver.id)
                .eq('status', 'paid');
            
            return {
                ...driver,
                totalOrders: orders?.length || 0,
                completedOrders: orders?.filter(o => o.status === 'delivered').length || 0,
                totalEarnings: earnings?.reduce((sum, e) => sum + parseFloat(e.net_amount), 0) || 0
            };
        }));
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>الاسم / Name</th>
                        <th>الهاتف / Phone</th>
                        <th>المركبة / Vehicle</th>
                        <th>الحالة / Status</th>
                        <th>التحقق / Verified</th>
                        <th>إجمالي الطلبات / Orders</th>
                        <th>المكتملة / Completed</th>
                        <th>الأرباح / Earnings</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${driversWithStats.map(driver => `
                        <tr>
                            <td>${driver.name}</td>
                            <td>${driver.phone}</td>
                            <td>${driver.vehicle_type || 'N/A'}</td>
                            <td><span class="status-${driver.is_online ? 'online' : 'offline'}">${driver.is_online ? 'متصل / Online' : 'غير متصل / Offline'}</span></td>
                            <td><span class="badge badge-${driver.manual_verified ? 'success' : 'warning'}">${driver.manual_verified ? 'موثق / Verified' : 'غير موثق / Unverified'}</span></td>
                            <td>${driver.totalOrders}</td>
                            <td>${driver.completedOrders}</td>
                            <td>${formatCurrency(driver.totalEarnings)}</td>
                            <td>
                                <div class="action-buttons">
                                    <button class="btn btn-sm btn-info" onclick="viewUser('${driver.id}')">
                                        <i class="fas fa-eye"></i>
                                    </button>
                                    ${!driver.manual_verified ? `
                                        <button class="btn btn-sm btn-success" onclick="verifyUser('${driver.id}')">
                                            <i class="fas fa-check"></i>
                                        </button>
                                    ` : ''}
                                </div>
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;
        
        container.innerHTML = table;
    } catch (error) {
        console.error('Load drivers error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

// Merchants Management
async function loadMerchants() {
    const statusFilter = document.getElementById('merchantsStatusFilter')?.value;
    const container = document.getElementById('merchantsTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        let query = supabaseClient
            .from('users')
            .select('*')
            .eq('role', 'merchant')
            .order('created_at', { ascending: false });
        
        if (statusFilter === 'verified') query = query.eq('manual_verified', true);
        if (statusFilter === 'unverified') query = query.eq('manual_verified', false);
        
        const { data: merchants, error } = await query;
        
        if (error) throw error;
        
        // Get merchant statistics
        const merchantsWithStats = await Promise.all(merchants.map(async (merchant) => {
            const { data: orders } = await supabaseClient
                .from('orders')
                .select('id, status, total_amount, delivery_fee')
                .eq('merchant_id', merchant.id);
            
            const { data: wallet } = await supabaseClient
                .from('merchant_wallets')
                .select('balance')
                .eq('merchant_id', merchant.id)
                .single();
            
            return {
                ...merchant,
                totalOrders: orders?.length || 0,
                completedOrders: orders?.filter(o => o.status === 'delivered').length || 0,
                totalSpent: orders?.reduce((sum, o) => sum + parseFloat(o.total_amount) + parseFloat(o.delivery_fee), 0) || 0,
                walletBalance: wallet?.balance || 0
            };
        }));
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>الاسم / Name</th>
                        <th>الهاتف / Phone</th>
                        <th>المتجر / Store</th>
                        <th>التحقق / Verified</th>
                        <th>إجمالي الطلبات / Orders</th>
                        <th>المكتملة / Completed</th>
                        <th>الإنفاق / Spent</th>
                        <th>رصيد المحفظة / Balance</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${merchantsWithStats.map(merchant => `
                        <tr>
                            <td>${merchant.name}</td>
                            <td>${merchant.phone}</td>
                            <td>${merchant.store_name || 'N/A'}</td>
                            <td><span class="badge badge-${merchant.manual_verified ? 'success' : 'warning'}">${merchant.manual_verified ? 'موثق / Verified' : 'غير موثق / Unverified'}</span></td>
                            <td>${merchant.totalOrders}</td>
                            <td>${merchant.completedOrders}</td>
                            <td>${formatCurrency(merchant.totalSpent)}</td>
                            <td>${formatCurrency(merchant.walletBalance)}</td>
                            <td>
                                <div class="action-buttons">
                                    <button class="btn btn-sm btn-info" onclick="viewUser('${merchant.id}')">
                                        <i class="fas fa-eye"></i>
                                    </button>
                                    ${!merchant.manual_verified ? `
                                        <button class="btn btn-sm btn-success" onclick="verifyUser('${merchant.id}')">
                                            <i class="fas fa-check"></i>
                                        </button>
                                    ` : ''}
                                </div>
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;
        
        container.innerHTML = table;
    } catch (error) {
        console.error('Load merchants error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

// Wallets Management
async function loadWallets() {
    const container = document.getElementById('walletsTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        const { data: wallets, error } = await supabaseClient
            .from('merchant_wallets')
            .select(`
                *,
                merchant:users!merchant_id(name, phone)
            `)
            .order('balance', { ascending: true });
        
        if (error) throw error;
        
        if (!wallets || wallets.length === 0) {
            container.innerHTML = '<p class="loading">لا توجد بيانات / No data</p>';
            return;
        }
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>التاجر / Merchant</th>
                        <th>الهاتف / Phone</th>
                        <th>الرصيد / Balance</th>
                        <th>رسوم الطلب / Order Fee</th>
                        <th>الحد الائتماني / Credit Limit</th>
                        <th>الحالة / Status</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${wallets.map(wallet => `
                        <tr>
                            <td>${wallet.merchant?.name || 'N/A'}</td>
                            <td>${wallet.merchant?.phone || 'N/A'}</td>
                            <td style="color: ${parseFloat(wallet.balance) < 0 ? 'var(--danger)' : 'var(--success)'}">${formatCurrency(wallet.balance)}</td>
                            <td>${formatCurrency(wallet.order_fee)}</td>
                            <td>${formatCurrency(wallet.credit_limit)}</td>
                            <td><span class="badge badge-${parseFloat(wallet.balance) >= parseFloat(wallet.credit_limit) ? 'success' : 'danger'}">${parseFloat(wallet.balance) >= parseFloat(wallet.credit_limit) ? 'جيد / Good' : 'يحتاج شحن / Needs Top-up'}</span></td>
                            <td>
                                <div class="action-buttons">
                                    <button class="btn btn-sm btn-primary" onclick="topUpWallet('${wallet.merchant_id}')">
                                        <i class="fas fa-plus"></i> شحن / Top-up
                                    </button>
                                    <button class="btn btn-sm btn-warning" onclick="editWalletSettings('${wallet.merchant_id}', ${wallet.order_fee}, ${wallet.credit_limit})">
                                        <i class="fas fa-cog"></i> إعدادات / Settings
                                    </button>
                                    <button class="btn btn-sm btn-info" onclick="viewWalletTransactions('${wallet.merchant_id}')">
                                        <i class="fas fa-history"></i> المعاملات / Transactions
                                    </button>
                                </div>
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;
        
        container.innerHTML = table;
    } catch (error) {
        console.error('Load wallets error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

// Earnings Management
async function loadEarnings() {
    const statusFilter = document.getElementById('earningsStatusFilter')?.value;
    const container = document.getElementById('earningsTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        let query = supabaseClient
            .from('earnings')
            .select(`
                *,
                driver:users!driver_id(name, phone),
                order:orders!order_id(id, customer_name)
            `)
            .order('created_at', { ascending: false });
        
        if (statusFilter) {
            query = query.eq('status', statusFilter);
        }
        
        const { data: earnings, error } = await query;
        
        if (error) throw error;
        
        if (!earnings || earnings.length === 0) {
            container.innerHTML = '<p class="loading">لا توجد بيانات / No data</p>';
            return;
        }
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>السائق / Driver</th>
                        <th>الطلب / Order</th>
                        <th>المبلغ / Amount</th>
                        <th>العمولة / Commission</th>
                        <th>الصافي / Net Amount</th>
                        <th>الحالة / Status</th>
                        <th>التاريخ / Date</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${earnings.map(earning => `
                        <tr>
                            <td>${earning.driver?.name || 'N/A'}<br><small>${earning.driver?.phone || ''}</small></td>
                            <td>${earning.order?.id.substring(0, 8)}...<br><small>${earning.order?.customer_name || ''}</small></td>
                            <td>${formatCurrency(earning.amount)}</td>
                            <td>${formatCurrency(earning.commission)}</td>
                            <td><strong>${formatCurrency(earning.net_amount)}</strong></td>
                            <td><span class="badge badge-${getEarningStatusBadgeClass(earning.status)}">${earning.status}</span></td>
                            <td>${formatDate(earning.created_at)}</td>
                            <td>
                                <div class="action-buttons">
                                    ${earning.status === 'pending' ? `
                                        <button class="btn btn-sm btn-success" onclick="markEarningAsPaid('${earning.id}')">
                                            <i class="fas fa-check"></i> دفع / Mark Paid
                                        </button>
                                    ` : ''}
                                </div>
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;
        
        container.innerHTML = table;
    } catch (error) {
        console.error('Load earnings error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

// Notifications Management
async function loadNotifications() {
    const container = document.getElementById('notificationsTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        const { data: notifications, error } = await supabaseClient
            .from('notifications')
            .select(`
                *,
                user:users!user_id(name, phone, role)
            `)
            .order('created_at', { ascending: false })
            .limit(100);
        
        if (error) throw error;
        
        if (!notifications || notifications.length === 0) {
            container.innerHTML = '<p class="loading">لا توجد إشعارات / No notifications</p>';
            return;
        }
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>المستخدم / User</th>
                        <th>العنوان / Title</th>
                        <th>الرسالة / Message</th>
                        <th>النوع / Type</th>
                        <th>الحالة / Status</th>
                        <th>التاريخ / Date</th>
                    </tr>
                </thead>
                <tbody>
                    ${notifications.map(notif => `
                        <tr>
                            <td>${notif.user?.name || 'N/A'} (${notif.user?.role || 'N/A'})<br><small>${notif.user?.phone || ''}</small></td>
                            <td>${notif.title}</td>
                            <td>${notif.body.substring(0, 50)}...</td>
                            <td><span class="badge badge-info">${notif.type}</span></td>
                            <td><span class="badge badge-${notif.is_read ? 'secondary' : 'success'}">${notif.is_read ? 'مقروء / Read' : 'جديد / New'}</span></td>
                            <td>${formatDate(notif.created_at)}</td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;
        
        container.innerHTML = table;
    } catch (error) {
        console.error('Load notifications error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

// Device Sessions Management
async function loadSessions() {
    const container = document.getElementById('sessionsTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        const { data: sessions, error } = await supabaseClient
            .from('device_sessions')
            .select(`
                *,
                user:users!user_id(name, phone, role)
            `)
            .order('last_seen_at', { ascending: false });
        
        if (error) throw error;
        
        if (!sessions || sessions.length === 0) {
            container.innerHTML = '<p class="loading">لا توجد جلسات / No sessions</p>';
            return;
        }
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>المستخدم / User</th>
                        <th>معرف الجهاز / Device ID</th>
                        <th>معلومات الجهاز / Device Info</th>
                        <th>الحالة / Status</th>
                        <th>آخر ظهور / Last Seen</th>
                        <th>تم الإنشاء / Created</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${sessions.map(session => `
                        <tr>
                            <td>${session.user?.name || 'N/A'} (${session.user?.role || 'N/A'})<br><small>${session.user?.phone || ''}</small></td>
                            <td>${session.device_id.substring(0, 20)}...</td>
                            <td>${session.device_info ? JSON.stringify(session.device_info).substring(0, 30) + '...' : 'N/A'}</td>
                            <td><span class="badge badge-${session.is_active ? 'success' : 'danger'}">${session.is_active ? 'نشط / Active' : 'غير نشط / Inactive'}</span></td>
                            <td>${formatDate(session.last_seen_at)}</td>
                            <td>${formatDate(session.created_at)}</td>
                            <td>
                                ${session.is_active ? `
                                    <button class="btn btn-sm btn-danger" onclick="logoutSession('${session.user_id}', '${session.device_id}')">
                                        <i class="fas fa-sign-out-alt"></i> تسجيل خروج / Logout
                                    </button>
                                ` : ''}
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;
        
        container.innerHTML = table;
    } catch (error) {
        console.error('Load sessions error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

// Live Tracking - Moved to app_verification.js with Mapbox

// Analytics
async function loadAnalytics() {
    // This would include more advanced charts and analytics
    // For now, keeping it simple
    console.log('Analytics loaded');
}

// Settings
async function loadSettings() {
    const container = document.getElementById('settingsForm');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        const { data: settings, error } = await supabaseClient
            .from('system_settings')
            .select('*')
            .order('key');
        
        if (error) throw error;
        
        const form = settings.map(setting => `
            <div class="form-group">
                <label>${setting.key}</label>
                <input 
                    type="text" 
                    id="setting_${setting.key}" 
                    value="${setting.value}"
                    data-key="${setting.key}"
                >
                <small>${setting.description || ''}</small>
            </div>
        `).join('');
        
        const saveButton = `
            <div class="form-group">
                <button class="btn btn-primary" onclick="saveSettings()">
                    <i class="fas fa-save"></i> حفظ الإعدادات / Save Settings
                </button>
            </div>
        `;
        
        container.innerHTML = form + saveButton;
    } catch (error) {
        console.error('Load settings error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

async function saveSettings() {
    const inputs = document.querySelectorAll('#settingsForm input[data-key]');
    
    try {
        for (const input of inputs) {
            const key = input.dataset.key;
            const value = input.value;
            
            await supabaseClient
                .from('system_settings')
                .update({ value, updated_at: new Date().toISOString() })
                .eq('key', key);
        }
        
        alert('✅ تم حفظ الإعدادات بنجاح / Settings saved successfully');
    } catch (error) {
        console.error('Save settings error:', error);
        alert('❌ خطأ في حفظ الإعدادات / Error saving settings');
    }
}

// Database Tools
function loadDatabaseTools() {
    console.log('Database tools loaded');
}

// Action Functions
async function viewUser(userId) {
    try {
        const { data: user, error } = await supabaseClient
            .from('users')
            .select('*')
            .eq('id', userId)
            .single();
        
        if (error) throw error;
        
        const modalBody = document.getElementById('userModalBody');
        modalBody.innerHTML = `
            <div class="details-list">
                <div class="details-item">
                    <div class="details-label">الاسم / Name:</div>
                    <div class="details-value">${user.name}</div>
                </div>
                <div class="details-item">
                    <div class="details-label">الهاتف / Phone:</div>
                    <div class="details-value">${user.phone}</div>
                </div>
                <div class="details-item">
                    <div class="details-label">الدور / Role:</div>
                    <div class="details-value"><span class="badge badge-info">${user.role}</span></div>
                </div>
                <div class="details-item">
                    <div class="details-label">الحالة / Status:</div>
                    <div class="details-value"><span class="status-${user.is_online ? 'online' : 'offline'}">${user.is_online ? 'متصل / Online' : 'غير متصل / Offline'}</span></div>
                </div>
                <div class="details-item">
                    <div class="details-label">التحقق / Verified:</div>
                    <div class="details-value"><span class="badge badge-${user.manual_verified ? 'success' : 'warning'}">${user.manual_verified ? 'موثق / Verified' : 'غير موثق / Unverified'}</span></div>
                </div>
                ${user.referral_source ? `
                    <div class="details-item">
                        <div class="details-label">مصدر المعرفة / Referral Source:</div>
                        <div class="details-value">${formatReferralSource(user.referral_source)}</div>
                    </div>
                ` : ''}
                ${user.document_type ? `
                    <div class="details-item">
                        <div class="details-label">نوع الوثيقة / Document Type:</div>
                        <div class="details-value">${formatDocumentType(user.document_type)}</div>
                    </div>
                ` : ''}
                <div class="details-item">
                    <div class="details-label">العنوان / Address:</div>
                    <div class="details-value">${user.address || 'N/A'}</div>
                </div>
                ${user.store_name ? `
                    <div class="details-item">
                        <div class="details-label">المتجر / Store:</div>
                        <div class="details-value">${user.store_name}</div>
                    </div>
                ` : ''}
                ${user.business_type ? `
                    <div class="details-item">
                        <div class="details-label">نوع النشاط / Business Type:</div>
                        <div class="details-value">${formatBusinessType(user.business_type)}</div>
                    </div>
                ` : ''}
                ${user.vehicle_type ? `
                    <div class="details-item">
                        <div class="details-label">المركبة / Vehicle:</div>
                        <div class="details-value">${user.vehicle_type}</div>
                    </div>
                ` : ''}
                <div class="details-item">
                    <div class="details-label">تاريخ التسجيل / Registered:</div>
                    <div class="details-value">${formatDate(user.created_at)}</div>
                </div>
            </div>
        `;
        
        openModal('userModal');
    } catch (error) {
        console.error('View user error:', error);
        alert('خطأ / Error');
    }
}

async function verifyUser(userId) {
    if (!confirm('هل أنت متأكد من توثيق هذا المستخدم؟ / Are you sure you want to verify this user?')) return;
    
    try {
        const { error } = await supabaseClient
            .from('users')
            .update({ 
                manual_verified: true,
                verified_at: new Date().toISOString(),
                verified_by: currentUser.id
            })
            .eq('id', userId);
        
        if (error) throw error;
        
        alert('✅ تم التوثيق بنجاح / User verified successfully');
        // Reload the current page
        const activePage = document.querySelector('.nav-item.active').dataset.page;
        navigateToPage(activePage);
    } catch (error) {
        console.error('Verify user error:', error);
        alert('❌ خطأ / Error');
    }
}

async function deleteUser(userId) {
    if (!confirm('⚠️ هل أنت متأكد؟ سيتم حذف المستخدم وجميع بياناته! / Are you sure? This will delete the user and all their data!')) return;
    
    try {
        const { error } = await supabaseClient
            .from('users')
            .delete()
            .eq('id', userId);
        
        if (error) throw error;
        
        alert('✅ تم الحذف بنجاح / User deleted successfully');
        loadUsers();
    } catch (error) {
        console.error('Delete user error:', error);
        alert('❌ خطأ / Error');
    }
}

async function viewOrderDetails(orderId) {
    try {
        const { data: order, error } = await supabaseClient
            .from('orders')
            .select(`
                *,
                merchant:users!merchant_id(name, phone),
                driver:users!driver_id(name, phone),
                items:order_items(*)
            `)
            .eq('id', orderId)
            .single();
        
        if (error) throw error;
        
        const modalBody = document.getElementById('orderModalBody');
        modalBody.innerHTML = `
            <div class="details-list">
                <div class="details-item">
                    <div class="details-label">رقم الطلب / Order ID:</div>
                    <div class="details-value">${order.id}</div>
                </div>
                <div class="details-item">
                    <div class="details-label">التاجر / Merchant:</div>
                    <div class="details-value">${order.merchant?.name} (${order.merchant?.phone})</div>
                </div>
                <div class="details-item">
                    <div class="details-label">السائق / Driver:</div>
                    <div class="details-value">${order.driver ? `${order.driver.name} (${order.driver.phone})` : 'غير مخصص / Unassigned'}</div>
                </div>
                <div class="details-item">
                    <div class="details-label">العميل / Customer:</div>
                    <div class="details-value">${order.customer_name} (${order.customer_phone})</div>
                </div>
                <div class="details-item">
                    <div class="details-label">من / From:</div>
                    <div class="details-value">${order.pickup_address}</div>
                </div>
                <div class="details-item">
                    <div class="details-label">إلى / To:</div>
                    <div class="details-value">${order.delivery_address}</div>
                </div>
                <div class="details-item">
                    <div class="details-label">الحالة / Status:</div>
                    <div class="details-value"><span class="badge badge-${getStatusBadgeClass(order.status)}">${order.status}</span></div>
                </div>
                <div class="details-item">
                    <div class="details-label">المبلغ الإجمالي / Total:</div>
                    <div class="details-value">${formatCurrency(order.total_amount)}</div>
                </div>
                <div class="details-item">
                    <div class="details-label">رسوم التوصيل / Delivery Fee:</div>
                    <div class="details-value">${formatCurrency(order.delivery_fee)}</div>
                </div>
                <div class="details-item">
                    <div class="details-label">الإجمالي / Grand Total:</div>
                    <div class="details-value"><strong>${formatCurrency(parseFloat(order.total_amount) + parseFloat(order.delivery_fee))}</strong></div>
                </div>
                <div class="details-item">
                    <div class="details-label">تاريخ الإنشاء / Created:</div>
                    <div class="details-value">${formatDate(order.created_at)}</div>
                </div>
                ${order.notes ? `
                    <div class="details-item">
                        <div class="details-label">ملاحظات / Notes:</div>
                        <div class="details-value">${order.notes}</div>
                    </div>
                ` : ''}
                ${order.items && order.items.length > 0 ? `
                    <div class="details-item">
                        <div class="details-label">المحتويات / Items:</div>
                        <div class="details-value">
                            <ul>
                                ${order.items.map(item => `<li>${item.name} x${item.quantity} - ${formatCurrency(item.price)}</li>`).join('')}
                            </ul>
                        </div>
                    </div>
                ` : ''}
            </div>
        `;
        
        openModal('orderModal');
    } catch (error) {
        console.error('View order error:', error);
        alert('خطأ / Error');
    }
}

async function cancelOrder(orderId) {
    if (!confirm('هل أنت متأكد من إلغاء هذا الطلب؟ / Are you sure you want to cancel this order?')) return;
    
    try {
        const { error } = await supabaseClient
            .from('orders')
            .update({ 
                status: 'cancelled',
                cancelled_at: new Date().toISOString(),
                cancellation_reason: 'Cancelled by admin'
            })
            .eq('id', orderId);
        
        if (error) throw error;
        
        alert('✅ تم إلغاء الطلب / Order cancelled');
        loadOrders();
    } catch (error) {
        console.error('Cancel order error:', error);
        alert('❌ خطأ / Error');
    }
}

async function topUpWallet(merchantId) {
    try {
        // Get merchant info
        const { data: merchant, error: merchantError } = await supabaseClient
            .from('users')
            .select('name, store_name')
            .eq('id', merchantId)
            .single();
        
        if (merchantError) throw merchantError;
        
        // Get current wallet balance
        const { data: wallet } = await supabaseClient
            .from('merchant_wallets')
            .select('balance')
            .eq('merchant_id', merchantId)
            .single();
        
        const currentBalance = wallet?.balance || 0;
        
        // Show modal with form
        const modalBody = document.getElementById('walletModalBody');
        modalBody.innerHTML = `
            <form id="topUpForm" class="form-container">
                <div class="form-group">
                    <label>التاجر / Merchant</label>
                    <input type="text" value="${merchant.name} - ${merchant.store_name || ''}" disabled class="form-control">
                </div>
                
                <div class="form-group">
                    <label>الرصيد الحالي / Current Balance</label>
                    <input type="text" value="${formatCurrency(currentBalance)}" disabled class="form-control" style="color: ${currentBalance < 0 ? 'var(--danger)' : 'var(--success)'}; font-weight: bold;">
                </div>
                
                <div class="form-group">
                    <label>المبلغ / Amount (IQD) *</label>
                    <input type="number" id="topUpAmount" class="form-control" placeholder="Enter amount" required min="1000" step="1000">
                    <small style="color: var(--gray-600);">الحد الأدنى: 1,000 IQD / Minimum: 1,000 IQD</small>
                </div>
                
                <div class="form-group">
                    <label>طريقة الدفع / Payment Method *</label>
                    <select id="topUpMethod" class="form-control" required>
                        <option value="">-- اختر الطريقة / Select Method --</option>
                        <option value="zain_cash">📱 زين كاش / Zain Cash</option>
                        <option value="qi_card">💳 كي كارد / Qi Card</option>
                        <option value="hur_representative">👤 مندوب حر / Hur Representative</option>
                        <option value="bank_transfer">🏦 تحويل بنكي / Bank Transfer</option>
                        <option value="cash">💵 نقداً / Cash</option>
                        <option value="card_payment">💳 بطاقة / Card Payment</option>
                        <option value="online_payment">🌐 دفع إلكتروني / Online Payment</option>
                        <option value="check">📝 شيك / Check</option>
                        <option value="gift">🎁 هدية / Gift</option>
                        <option value="other">📋 أخرى / Other</option>
                    </select>
                </div>
                
                <div class="form-group">
                    <label>ملاحظات / Notes</label>
                    <textarea id="topUpNotes" class="form-control" rows="3" placeholder="Optional notes..."></textarea>
                </div>
                
                <div class="info-box" style="background: #EFF6FF; border-color: #3B82F6; margin-top: 20px; padding: 15px; border-radius: 8px; border: 1px solid;">
                    <i class="fas fa-info-circle" style="color: #3B82F6;"></i>
                    <div style="margin-left: 10px;">
                        <strong>الرصيد الجديد المتوقع / Expected New Balance:</strong>
                        <div id="newBalancePreview" style="font-size: 1.3em; color: #10B981; font-weight: bold; margin-top: 8px;">
                            ${formatCurrency(currentBalance)}
                        </div>
                    </div>
                </div>
                
                <div class="form-actions" style="margin-top: 20px;">
                    <button type="submit" class="btn btn-primary">
                        <i class="fas fa-check"></i> تأكيد الشحن / Confirm Top-up
                    </button>
                    <button type="button" class="btn btn-secondary" onclick="closeAllModals()">
                        <i class="fas fa-times"></i> إلغاء / Cancel
                    </button>
                </div>
            </form>
        `;
        
        // Update preview when amount changes
        document.getElementById('topUpAmount').addEventListener('input', (e) => {
            const amount = parseFloat(e.target.value) || 0;
            const newBalance = currentBalance + amount;
            const previewEl = document.getElementById('newBalancePreview');
            previewEl.textContent = formatCurrency(newBalance);
            previewEl.style.color = newBalance >= 0 ? '#10B981' : '#EF4444';
        });
        
        // Handle form submit
        document.getElementById('topUpForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            
            const amount = parseFloat(document.getElementById('topUpAmount').value);
            const method = document.getElementById('topUpMethod').value;
            const notes = document.getElementById('topUpNotes').value || 'Admin top-up';
            
            if (!amount || amount < 1000) {
                showError('❌ المبلغ يجب أن يكون 1,000 IQD على الأقل / Amount must be at least 1,000 IQD');
                return;
            }
            
            if (!method) {
                showError('❌ يرجى اختيار طريقة الدفع / Please select payment method');
                return;
            }
            
            try {
                const { data, error } = await supabaseClient
                    .rpc('add_wallet_balance', {
                        p_merchant_id: merchantId,
                        p_amount: amount,
                        p_payment_method: method,
                        p_notes: notes || null
                    });
                
                if (error) throw error;
                
                showSuccess(`✅ تم شحن ${formatCurrency(amount)} بنجاح / Successfully added ${formatCurrency(amount)}`);
                closeAllModals();
                loadWallets();
            } catch (error) {
                console.error('Top-up error:', error);
                showError('❌ خطأ في الشحن / Top-up failed: ' + error.message);
            }
        });
        
        openModal('walletModal');
        
        // Focus on amount input
        setTimeout(() => document.getElementById('topUpAmount').focus(), 100);
        
    } catch (error) {
        console.error('Load wallet modal error:', error);
        showError('خطأ / Error loading wallet');
    }
}

async function viewWalletTransactions(merchantId) {
    try {
        const { data: transactions, error } = await supabaseClient
            .from('wallet_transactions')
            .select('*')
            .eq('merchant_id', merchantId)
            .order('created_at', { ascending: false })
            .limit(50);
        
        if (error) throw error;
        
        const modalBody = document.getElementById('walletModalBody');
        modalBody.innerHTML = `
            <h3>معاملات المحفظة / Wallet Transactions</h3>
            <table>
                <thead>
                    <tr>
                        <th>النوع / Type</th>
                        <th>المبلغ / Amount</th>
                        <th>الرصيد بعد / Balance After</th>
                        <th>التاريخ / Date</th>
                    </tr>
                </thead>
                <tbody>
                    ${transactions.map(t => `
                        <tr>
                            <td><span class="badge badge-info">${t.transaction_type}</span></td>
                            <td style="color: ${parseFloat(t.amount) >= 0 ? 'var(--success)' : 'var(--danger)'}">${formatCurrency(t.amount)}</td>
                            <td>${formatCurrency(t.balance_after)}</td>
                            <td>${formatDate(t.created_at)}</td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;
        
        openModal('walletModal');
    } catch (error) {
        console.error('View transactions error:', error);
        alert('خطأ / Error');
    }
}

async function editWalletSettings(merchantId, currentOrderFee, currentCreditLimit) {
    try {
        // Get merchant info
        const { data: merchant, error: merchantError } = await supabaseClient
            .from('users')
            .select('name, store_name')
            .eq('id', merchantId)
            .single();
        
        if (merchantError) throw merchantError;
        
        // Show modal with form
        const modalBody = document.getElementById('walletModalBody');
        modalBody.innerHTML = `
            <form id="editWalletSettingsForm" class="form-container">
                <div class="form-group">
                    <label>التاجر / Merchant</label>
                    <input type="text" value="${merchant.name} - ${merchant.store_name || ''}" disabled class="form-control">
                </div>
                
                <div class="form-group">
                    <label>رسوم الطلب / Order Fee (IQD) *</label>
                    <input type="number" id="newOrderFee" class="form-control" value="${currentOrderFee}" required min="0" step="100">
                    <small style="color: var(--gray-600);">الرسم المقتطع من كل طلب مكتمل / Fee deducted per completed order</small>
                </div>
                
                <div class="form-group">
                    <label>الحد الائتماني / Credit Limit (IQD) *</label>
                    <input type="number" id="newCreditLimit" class="form-control" value="${currentCreditLimit}" required max="0" step="1000">
                    <small style="color: var(--gray-600);">الحد الأدنى للرصيد (قيمة سالبة) / Minimum balance (negative value)</small>
                </div>
                
                <div class="form-group">
                    <label>ملاحظات الإدارة / Admin Notes</label>
                    <textarea id="adminNotes" class="form-control" rows="3" placeholder="Optional notes..."></textarea>
                </div>
                
                <div class="info-box" style="background: #FEF3C7; border-color: #F59E0B; margin-top: 20px; padding: 15px; border-radius: 8px; border: 1px solid;">
                    <i class="fas fa-exclamation-triangle" style="color: #F59E0B;"></i>
                    <div style="margin-left: 10px;">
                        <strong>تنبيه / Warning:</strong>
                        <p style="margin: 5px 0 0 0; font-size: 0.9em;">
                            تغيير هذه الإعدادات سيؤثر على الطلبات المستقبلية فقط<br>
                            Changing these settings will affect future orders only
                        </p>
                    </div>
                </div>
                
                <div class="form-actions" style="margin-top: 20px;">
                    <button type="submit" class="btn btn-primary">
                        <i class="fas fa-save"></i> حفظ التغييرات / Save Changes
                    </button>
                    <button type="button" class="btn btn-secondary" onclick="closeAllModals()">
                        <i class="fas fa-times"></i> إلغاء / Cancel
                    </button>
                </div>
            </form>
        `;
        
        // Handle form submission
        document.getElementById('editWalletSettingsForm').onsubmit = async (e) => {
            e.preventDefault();
            
            const newOrderFee = parseFloat(document.getElementById('newOrderFee').value);
            const newCreditLimit = parseFloat(document.getElementById('newCreditLimit').value);
            const adminNotes = document.getElementById('adminNotes').value;
            
            // Validate
            if (newOrderFee < 0) {
                alert('❌ رسوم الطلب يجب أن تكون صفر أو أكثر / Order fee must be zero or more');
                return;
            }
            
            if (newCreditLimit > 0) {
                alert('❌ الحد الائتماني يجب أن يكون صفر أو أقل / Credit limit must be zero or less');
                return;
            }
            
            if (!confirm(`تأكيد التغييرات؟\nConfirm changes?\n\nOrder Fee: ${newOrderFee} IQD\nCredit Limit: ${newCreditLimit} IQD`)) {
                return;
            }
            
            try {
                const { data, error } = await supabaseClient
                    .rpc('admin_update_wallet_settings', {
                        p_merchant_id: merchantId,
                        p_new_credit_limit: newCreditLimit,
                        p_new_order_fee: newOrderFee,
                        p_admin_notes: adminNotes || null
                    });
                
                if (error) throw error;
                
                if (data.success) {
                    alert('✅ تم تحديث الإعدادات بنجاح / Settings updated successfully');
                    closeAllModals();
                    loadWallets();
                } else {
                    throw new Error(data.error || 'Update failed');
                }
            } catch (error) {
                console.error('Update wallet settings error:', error);
                alert('❌ خطأ في تحديث الإعدادات / Error updating settings');
            }
        };
        
        openModal('walletModal');
    } catch (error) {
        console.error('Edit wallet settings error:', error);
        alert('خطأ / Error');
    }
}

async function markEarningAsPaid(earningId) {
    if (!confirm('تأكيد الدفع؟ / Confirm payment?')) return;
    
    try {
        const { error } = await supabaseClient
            .from('earnings')
            .update({ 
                status: 'paid',
                paid_at: new Date().toISOString()
            })
            .eq('id', earningId);
        
        if (error) throw error;
        
        alert('✅ تم تحديث الحالة / Status updated');
        loadEarnings();
    } catch (error) {
        console.error('Mark paid error:', error);
        alert('❌ خطأ / Error');
    }
}

// handleSendNotification moved to app_admin_management.js with FCM support

async function logoutSession(userId, deviceId) {
    if (!confirm('تسجيل خروج هذه الجلسة؟ / Logout this session?')) return;
    
    try {
        const { error } = await supabaseClient
            .rpc('logout_device_session', {
                p_user_id: userId,
                p_device_id: deviceId
            });
        
        if (error) throw error;
        
        alert('✅ تم تسجيل الخروج / Session logged out');
        loadSessions();
    } catch (error) {
        console.error('Logout session error:', error);
        alert('❌ خطأ / Error');
    }
}

function viewDriverOnMap(lat, lng) {
    alert(`Driver location: ${lat}, ${lng}\nOpen in Google Maps: https://maps.google.com/?q=${lat},${lng}`);
}

// Admin Object for Database Tools
const admin = {
    async exportData() {
        alert('تصدير البيانات / Export Data - Feature coming soon!');
    },
    
    async cleanupOldData() {
        if (!confirm('⚠️ هل أنت متأكد؟ / Are you sure?')) return;
        alert('تنظيف البيانات / Cleanup - Feature coming soon!');
    },
    
    async getDatabaseStats() {
        try {
            const [users, orders, notifications] = await Promise.all([
                supabaseClient.from('users').select('id', { count: 'exact', head: true }),
                supabaseClient.from('orders').select('id', { count: 'exact', head: true }),
                supabaseClient.from('notifications').select('id', { count: 'exact', head: true })
            ]);
            
            alert(`إحصائيات قاعدة البيانات / Database Stats:
Users: ${users.count}
Orders: ${orders.count}
Notifications: ${notifications.count}`);
        } catch (error) {
            console.error('Database stats error:', error);
        }
    },
    
    async runSQLQuery() {
        const query = document.getElementById('sqlQuery').value;
        if (!query) return;
        
        alert('⚠️ SQL Query execution is disabled for security reasons. Use Supabase Dashboard for direct SQL queries.');
    }
};

// Utility Functions
function formatCurrency(amount) {
    return `${parseFloat(amount).toLocaleString()} ${CONFIG.CURRENCY_SYMBOL}`;
}

function formatReferralSource(source) {
    if (!source) return '<span style="color: #999;">غير محدد / N/A</span>';
    
    const sources = {
        'social_media': '📱 وسائل التواصل',
        'friend': '👥 صديق/معارف',
        'representative': '🤝 ممثل حر',
        'advertisement': '📺 إعلان',
        'search_engine': '🔍 محرك بحث',
        'word_of_mouth': '💬 من شخص آخر',
        'store_banner': '🏪 لافتة',
        'other': '📋 أخرى'
    };
    
    return sources[source] || source;
}

function formatDocumentType(docType) {
    if (!docType) return '<span style="color: #999;">غير محدد / N/A</span>';
    
    const types = {
        'national_id': '🪪 الهوية الوطنية / National ID',
        'driver_license': '🚗 رخصة القيادة / Driver License',
        'passport': '✈️ جواز السفر / Passport'
    };
    
    return types[docType] || docType;
}

function formatBusinessType(businessType) {
    if (!businessType) return '<span style="color: #999;">غير محدد / N/A</span>';
    
    const types = {
        'restaurant': '🍽️ مطعم / Restaurant',
        'grocery': '🛒 بقالة / Grocery',
        'pharmacy': '💊 صيدلية / Pharmacy',
        'bakery': '🥖 مخبز / Bakery',
        'cafe': '☕ مقهى / Cafe',
        'supermarket': '🏪 سوبرماركت / Supermarket',
        'electronics': '📱 إلكترونيات / Electronics',
        'clothing': '👕 ملابس / Clothing',
        'other': '📦 أخرى / Other'
    };
    
    return types[businessType] || businessType;
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleString('ar-IQ', { 
        year: 'numeric', 
        month: 'short', 
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function getStatusBadgeClass(status) {
    const classes = {
        pending: 'warning',
        assigned: 'info',
        accepted: 'success',
        on_the_way: 'info',
        delivered: 'success',
        cancelled: 'danger',
        rejected: 'danger'
    };
    return classes[status] || 'secondary';
}

function getEarningStatusBadgeClass(status) {
    const classes = {
        pending: 'warning',
        paid: 'success',
        cancelled: 'danger'
    };
    return classes[status] || 'secondary';
}

function openModal(modalId) {
    document.getElementById(modalId)?.classList.add('active');
}

function closeAllModals() {
    document.querySelectorAll('.modal').forEach(modal => {
        modal.classList.remove('active');
    });
}

function showError(message) {
    console.error(message);
    // Also show a temporary alert
    const alertDiv = document.createElement('div');
    alertDiv.style.cssText = 'position: fixed; top: 20px; right: 20px; background: #FEE2E2; color: #DC2626; padding: 15px 20px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); z-index: 10000; border: 2px solid #EF4444;';
    alertDiv.innerHTML = `<i class="fas fa-exclamation-circle"></i> ${message}`;
    document.body.appendChild(alertDiv);
    setTimeout(() => alertDiv.remove(), 5000);
}

function showSuccess(message) {
    console.log(message);
    // Show a temporary success alert
    const alertDiv = document.createElement('div');
    alertDiv.style.cssText = 'position: fixed; top: 20px; right: 20px; background: #D1FAE5; color: #059669; padding: 15px 20px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); z-index: 10000; border: 2px solid #10B981;';
    alertDiv.innerHTML = `<i class="fas fa-check-circle"></i> ${message}`;
    document.body.appendChild(alertDiv);
    setTimeout(() => alertDiv.remove(), 3000);
}

function filterTable(tableId, searchTerm) {
    const table = document.getElementById(tableId);
    const rows = table?.querySelectorAll('tbody tr');
    
    rows?.forEach(row => {
        const text = row.textContent.toLowerCase();
        row.style.display = text.includes(searchTerm.toLowerCase()) ? '' : 'none';
    });
}

// Realtime Subscriptions
function setupRealtimeSubscriptions() {
    if (!CONFIG.REALTIME_ENABLED) return;
    
    // Subscribe to orders
    const ordersSubscription = supabaseClient
        .channel('orders-changes')
        .on('postgres_changes', { 
            event: '*', 
            schema: 'public', 
            table: 'orders' 
        }, payload => {
            console.log('Order changed:', payload);
            // Refresh dashboard stats
            loadDashboard();
        })
        .subscribe();
    
    realtimeSubscriptions.push(ordersSubscription);
    
    // Subscribe to users
    const usersSubscription = supabaseClient
        .channel('users-changes')
        .on('postgres_changes', { 
            event: '*', 
            schema: 'public', 
            table: 'users' 
        }, payload => {
            console.log('User changed:', payload);
        })
        .subscribe();
    
    realtimeSubscriptions.push(usersSubscription);
}

function unsubscribeFromRealtime() {
    realtimeSubscriptions.forEach(sub => {
        supabaseClient.removeChannel(sub);
    });
    realtimeSubscriptions = [];
}

// Auto-refresh Dashboard
setInterval(() => {
    const activePage = document.querySelector('.nav-item.active')?.dataset.page;
    if (activePage === 'dashboard' && document.getElementById('appScreen').style.display !== 'none') {
        loadDashboard();
    }
}, CONFIG.DASHBOARD_REFRESH);

console.log('✅ Hur Delivery Admin Panel Initialized');

async function loadMessaging() {
    stopEmergencyAutoRefresh();
    if (typeof AdminMessaging === 'undefined') {
        console.warn('AdminMessaging module not available');
        return;
    }
    ensureMessagingElements();

    if (!messagingInitialized) {
        messagingConversationsUnsub = AdminMessaging.onConversations(renderMessagingConversations);
        messagingMessagesUnsub = AdminMessaging.onMessages(renderMessagingMessages);
        await AdminMessaging.initRealtime();
        messagingInitialized = true;
    } else {
        await AdminMessaging.listConversations();
        if (AdminMessaging.state.activeConversationId) {
            await AdminMessaging.selectConversation(AdminMessaging.state.activeConversationId);
        }
    }

    if (!AdminMessaging.state.activeConversationId && AdminMessaging.state.conversations.length > 0) {
        await AdminMessaging.selectConversation(AdminMessaging.state.conversations[0].id);
    }

    renderMessagingConversations();
    renderMessagingMessages();
}

function ensureMessagingElements() {
    if (messagingElements.conversations) return;
    messagingElements.conversations = document.getElementById('messagingConversations');
    messagingElements.messages = document.getElementById('messagingMessages');
    messagingElements.compose = document.getElementById('messagingCompose');
    messagingElements.sendBtn = document.getElementById('messagingSendBtn');
    messagingElements.title = document.getElementById('messagingActiveTitle');
    messagingElements.subtitle = document.getElementById('messagingActiveSubtitle');
}

function renderMessagingConversations(conversations = AdminMessaging?.state?.conversations || []) {
    ensureMessagingElements();
    if (!messagingElements.conversations) return;

    const container = messagingElements.conversations;
    container.innerHTML = '';

    if (!conversations.length) {
        container.innerHTML = '<p class="empty-state">لا توجد محادثات حالياً / No conversations yet</p>';
        setActiveConversationUI(null);
        return;
    }

    conversations.forEach((conversation) => {
        const item = document.createElement('div');
        item.className = 'messaging-item';
        if (conversation.id === AdminMessaging.state.activeConversationId) {
            item.classList.add('active');
        }
        item.dataset.conversationId = conversation.id;
        item.dataset.orderId = conversation.order_id || '';
        item.dataset.isSupport = conversation.is_support ? 'true' : 'false';

        const title = getConversationTitle(conversation);
        const subtitle = conversation.order_id ? `طلب: ${conversation.order_id}` : (conversation.is_support ? 'محادثة دعم فني' : 'محادثة عامة');
        const created = formatMessagingTimestamp(conversation.created_at);

        item.innerHTML = `
            <h4>${escapeHtml(title)}</h4>
            <p>${escapeHtml(subtitle)}</p>
            <p style="font-size: 0.75rem; color: var(--gray-400); margin-top: 6px;">${escapeHtml(created)}</p>
        `;

        container.appendChild(item);
    });

    const active = AdminMessaging.state.activeConversationId
        ? AdminMessaging.state.conversations.find(c => c.id === AdminMessaging.state.activeConversationId)
        : null;
    setActiveConversationUI(active || null);
}

function renderMessagingMessages(messages = AdminMessaging?.state?.messages || []) {
    ensureMessagingElements();
    if (!messagingElements.messages) return;

    const container = messagingElements.messages;
    container.innerHTML = '';

    if (!messages.length) {
        container.innerHTML = '<div class="empty-state">لا توجد رسائل بعد / No messages yet</div>';
        return;
    }

    messages.forEach((message) => {
        const div = document.createElement('div');
        div.className = 'messaging-message';
        if (currentUser?.id && message.sender_id === currentUser.id) {
            div.classList.add('admin');
        }
        const time = formatMessagingTimestamp(message.created_at);
        const body = escapeHtml(message.body || '');
        div.innerHTML = `<div>${body}</div><time>${escapeHtml(time)}</time>`;
        container.appendChild(div);
    });

    container.scrollTop = container.scrollHeight;
}

async function handleMessagingConversationClick(event) {
    const item = event.target.closest('.messaging-item');
    if (!item) return;
    const conversationId = item.dataset.conversationId;
    if (!conversationId || typeof AdminMessaging === 'undefined') return;

    await AdminMessaging.selectConversation(conversationId);
    const conversation = AdminMessaging.state.conversations.find(c => c.id === conversationId);
    setActiveConversationUI(conversation || null);
    renderMessagingConversations();
    renderMessagingMessages();
}

async function handleMessagingSend() {
    ensureMessagingElements();
    if (!messagingElements.compose || typeof AdminMessaging === 'undefined') return;
    const text = messagingElements.compose.value.trim();
    if (!text) return;

    messagingElements.sendBtn?.setAttribute('disabled', 'disabled');
    try {
        await AdminMessaging.sendMessage(text);
        messagingElements.compose.value = '';
    } catch (error) {
        console.error('Failed to send message', error);
    } finally {
        messagingElements.sendBtn?.removeAttribute('disabled');
    }
}

function handleMessagingComposerKeydown(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault();
        handleMessagingSend();
    }
}

function refreshMessagingConversations() {
    if (typeof AdminMessaging === 'undefined') return;
    AdminMessaging.listConversations();
}

function setActiveConversationUI(conversation) {
    ensureMessagingElements();
    if (!messagingElements.title) return;

    if (!conversation) {
        messagingElements.title.textContent = 'اختر محادثة / Select a conversation';
        if (messagingElements.subtitle) messagingElements.subtitle.textContent = '';
        return;
    }

    messagingElements.title.textContent = getConversationTitle(conversation);
    if (messagingElements.subtitle) {
        messagingElements.subtitle.textContent = conversation.order_id
            ? `رقم الطلب: ${conversation.order_id}`
            : (conversation.is_support ? 'محادثة دعم فني' : 'محادثة عامة');
    }
}

function escapeHtml(value) {
    if (value == null) return '';
    return String(value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function getConversationTitle(conversation) {
    if (!conversation) return 'محادثة';
    if (conversation.title) return conversation.title;
    if (conversation.is_support) return 'دعم فني';
    return 'محادثة';
}

function formatMessagingTimestamp(value) {
    if (!value) return '';
    try {
        const date = new Date(value);
        if (Number.isNaN(date.getTime())) return '';
        return date.toLocaleString('ar-IQ', { hour12: false });
    } catch (error) {
        return value;
    }
}

function resetMessagingState() {
    if (messagingConversationsUnsub) {
        messagingConversationsUnsub();
        messagingConversationsUnsub = null;
    }
    if (messagingMessagesUnsub) {
        messagingMessagesUnsub();
        messagingMessagesUnsub = null;
    }
    messagingInitialized = false;
    if (typeof AdminMessaging !== 'undefined') {
        AdminMessaging.state.conversations = [];
        AdminMessaging.state.messages = [];
        AdminMessaging.state.activeConversationId = null;
    }
    ensureMessagingElements();
    if (messagingElements.conversations) {
        messagingElements.conversations.innerHTML = '<p class="empty-state">لا توجد محادثات حالياً / No conversations yet</p>';
    }
    if (messagingElements.messages) {
        messagingElements.messages.innerHTML = '<div class="empty-state">اختر محادثة لعرض الرسائل / Select a conversation to view messages</div>';
    }
    if (messagingElements.title) messagingElements.title.textContent = 'اختر محادثة / Select a conversation';
    if (messagingElements.subtitle) messagingElements.subtitle.textContent = '';
    if (messagingElements.compose) messagingElements.compose.value = '';
}
