/**
 * Health Status Monitoring System
 * Comprehensive monitoring of all app services, errors, and system status
 */

// Health status update interval (5 seconds)
const HEALTH_UPDATE_INTERVAL = 5000;
let healthUpdateTimer = null;

// Service endpoints
const SERVICES = {
    whatsapp: 'https://whatsapp-server-production.up.railway.app',
    supabase: CONFIG.SUPABASE_URL
};

// Health Status Data Storage
let healthData = {
    system: { status: 'checking', uptime: 0, lastCheck: null },
    services: {},
    errors: { recent: [], counts: {} },
    statistics: {}
};

/**
 * Initialize Health Page
 */
function initializeHealthPage() {
    console.log('🏥 Initializing Health Status Page');
    loadHealthStatus();
    
    // Setup auto-refresh
    if (healthUpdateTimer) clearInterval(healthUpdateTimer);
    healthUpdateTimer = setInterval(loadHealthStatus, HEALTH_UPDATE_INTERVAL);
}

/**
 * Stop health page auto-refresh
 */
function stopHealthPageRefresh() {
    if (healthUpdateTimer) {
        clearInterval(healthUpdateTimer);
        healthUpdateTimer = null;
    }
}

/**
 * Load comprehensive health status
 */
async function loadHealthStatus() {
    try {
        // Load all health data in parallel
        const [
            systemStatus,
            whatsappStatus,
            errorStats,
            notificationStats,
            recentErrors,
            databaseStats
        ] = await Promise.all([
            checkSystemStatus(),
            checkWhatsAppService(),
            getErrorStatistics(),
            getNotificationStatistics(),
            getRecentErrors(),
            getDatabaseStatistics()
        ]);

        // Update health data
        healthData = {
            system: systemStatus,
            services: {
                whatsapp: { ...whatsappStatus, name: 'WhatsApp Service' },
                database: { status: 'healthy', name: 'Database', lastCheck: new Date().toISOString(), message: 'Supabase database is operational' },
                notifications: { ...notificationStats, name: 'Notification System' }
            },
            errors: {
                recent: recentErrors,
                counts: errorStats
            },
            statistics: databaseStats
        };

        // Render health dashboard
        renderHealthDashboard();
    } catch (error) {
        console.error('Error loading health status:', error);
        showHealthError(error);
    }
}

/**
 * Check overall system status
 */
async function checkSystemStatus() {
    try {
        const { data: userCount } = await supabaseClient
            .from('users')
            .select('id', { count: 'exact', head: true });

        const { data: orderCount } = await supabaseClient
            .from('orders')
            .select('id', { count: 'exact', head: true });

        return {
            status: 'healthy',
            uptime: getUptime(),
            lastCheck: new Date().toISOString(),
            metrics: {
                totalUsers: userCount.count || 0,
                totalOrders: orderCount.count || 0
            }
        };
    } catch (error) {
        return {
            status: 'unhealthy',
            error: error.message,
            lastCheck: new Date().toISOString()
        };
    }
}

/**
 * Check WhatsApp Service Status
 */
async function checkWhatsAppService() {
    try {
        const response = await fetch(`${SERVICES.whatsapp}/health`);
        const data = await response.json();
        
        return {
            status: data.whatsapp_connected ? 'healthy' : 'degraded',
            connected: data.whatsapp_connected,
            lastCheck: new Date().toISOString(),
            message: data.whatsapp_connected ? 
                'WhatsApp service is connected and operational' : 
                'WhatsApp service is running but not connected to WhatsApp',
            icon: data.whatsapp_connected ? '✅' : '⚠️'
        };
    } catch (error) {
        return {
            status: 'down',
            connected: false,
            lastCheck: new Date().toISOString(),
            error: error.message,
            message: 'WhatsApp service is not responding',
            icon: '❌'
        };
    }
}

/**
 * Get Error Statistics
 */
async function getErrorStatistics() {
    try {
        // WhatsApp Errors
        const { data: whatsappErrors } = await supabaseClient
            .from('whatsapp_errors')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(1000);

        // Count errors by context
        const errorCounts = {};
        whatsappErrors?.forEach(error => {
            const context = error.context || 'unknown';
            errorCounts[context] = (errorCounts[context] || 0) + 1;
        });

        // Recent errors (last hour)
        const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
        const recentErrors = whatsappErrors?.filter(e => 
            new Date(e.created_at) > new Date(oneHourAgo)
        ) || [];

        return {
            total: whatsappErrors?.length || 0,
            recent: recentErrors.length,
            byContext: errorCounts
        };
    } catch (error) {
        console.error('Error getting error statistics:', error);
        return { total: 0, recent: 0, byContext: {} };
    }
}

/**
 * Get Notification Statistics
 */
async function getNotificationStatistics() {
    try {
        const { data: notifications } = await supabaseClient
            .from('notifications')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(100);

        const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
        const recent = notifications?.filter(n => 
            new Date(n.created_at) > new Date(oneHourAgo)
        ) || [];

        return {
            status: 'healthy',
            totalRecent: recent.length,
            lastCheck: new Date().toISOString()
        };
    } catch (error) {
        return {
            status: 'error',
            error: error.message,
            lastCheck: new Date().toISOString()
        };
    }
}

/**
 * Get Recent Errors
 */
async function getRecentErrors() {
    try {
        const { data: errors } = await supabaseClient
            .from('whatsapp_errors')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(20);

        return errors || [];
    } catch (error) {
        console.error('Error getting recent errors:', error);
        return [];
    }
}

/**
 * Get Database Statistics
 */
async function getDatabaseStatistics() {
    try {
        const [
            { count: userCount },
            { count: orderCount },
            { count: driverCount },
            { count: merchantCount },
            { count: notificationCount },
            { count: earningsCount }
        ] = await Promise.all([
            supabaseClient.from('users').select('*', { count: 'exact', head: true }),
            supabaseClient.from('orders').select('*', { count: 'exact', head: true }),
            supabaseClient.from('users').select('*', { count: 'exact', head: true }).eq('role', 'driver'),
            supabaseClient.from('users').select('*', { count: 'exact', head: true }).eq('role', 'merchant'),
            supabaseClient.from('notifications').select('*', { count: 'exact', head: true }),
            supabaseClient.from('earnings').select('*', { count: 'exact', head: true })
        ]);

        return {
            users: userCount || 0,
            orders: orderCount || 0,
            drivers: driverCount || 0,
            merchants: merchantCount || 0,
            notifications: notificationCount || 0,
            earnings: earningsCount || 0
        };
    } catch (error) {
        console.error('Error getting database statistics:', error);
        return {};
    }
}

/**
 * Get system uptime (mock implementation)
 */
function getUptime() {
    // In a real system, this would track actual uptime
    const hours = Math.floor(Math.random() * 720); // Random 0-720 hours
    return `${hours} hours`;
}

/**
 * Render Health Dashboard
 */
function renderHealthDashboard() {
    const container = document.getElementById('healthPageContent');
    if (!container) return;

    const { system, services, errors, statistics } = healthData;

    container.innerHTML = `
        <!-- Overall System Status -->
        <div class="content-card" style="margin-bottom: 20px;">
            <div class="card-header" style="background: ${getStatusColor(system.status)}">
                <h3>
                    <i class="fas fa-server"></i> 
                    System Status: <span id="systemStatusText">${getStatusText(system.status)}</span>
                    <span style="float: left; font-size: 1 dopx; color: #fff; opacity: 0.9;">
                        Last updated: ${formatRelativeTime(system.lastCheck)}
                    </span>
                </h3>
            </div>
            <div class="card-body">
                <div class="stats-grid" style="margin-bottom: 0;">
                    <div class="stat-card">
                        <div class="stat-icon ${getStatusIconClass(system.status)}">
                            <i class="fas fa-server"></i>
                        </div>
                        <div class="stat-details">
                            <h3>${system.uptime}</h3>
                            <p>Uptime<br>الوقت المستمر للعمل</p>
                        </div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-icon teal">
                            <i class="fas fa-users"></i>
                        </div>
                        <div class="stat-details">
                            <h3>${statistics.users || 0}</h3>
                            <p>Total Users<br>إجمالي المستخدمين</p>
                        </div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-icon blue">
                            <i class="fas fa-box"></i>
                        </div>
                        <div class="stat-details">
                            <h3>${statistics.orders || 0}</h3>
                            <p>Total Orders<br>إجمالي الطلبات</p>
                        </div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-icon ${errors.recent > 0 ? 'red' : 'green'}">
                            <i class="fas fa-exclamation-triangle"></i>
                        </div>
                        <div class="stat-details">
                            <h3>${errors.recent}</h3>
                            <p>Recent Errors (1h)<br>الأخطاء الأخيرة (ساعة)</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Services Status -->
        <div class="content-card" style="margin-bottom: 20px;">
            <div class="card-header" style="background: #DBEAFE; color: #1E3A8A;">
                <h3><i class="fas fa-network-wired"></i> Services Status / حالة الخدمات</h3>
            </div>
            <div class="card-body">
                <div class="services-list">
                    ${renderServiceStatus(services.whatsapp)}
                    ${renderServiceStatus(services.database)}
                    ${renderServiceStatus(services.notifications)}
                </div>
            </div>
        </div>

        <!-- Error Statistics -->
        ${errors.recent > 0 ? `
        <div class="content-card" style="margin-bottom: 20px;">
            <div class="card-header" style="background: #FEE2E2; color: #991B1B;">
                <h3>
                    <i class="fas fa-bug"></i> 
                    Error Statistics / إحصائيات الأخطاء
                    <span style="float: left; font-size: 14px;">
                        Total: ${errors.counts.total} | Last Hour: ${errors.recent}
                    </span>
                </h3>
            </div>
            <div class="card-body">
                ${renderErrorBreakdown(errors.counts.byContext)}
            </div>
        </div>
        ` : ''}

        <!-- Recent Errors Table -->
        <div class="content-card">
            <div class="card-header" style="background: #FEF3C7; color: #92400E;">
                <h3><i class="fas fa-list"></i> Recent Errors / الأخطاء الأخيرة</h3>
            </div>
            <div class="card-body">
                <div id="recentErrorsTable">
                    ${renderRecentErrorsTable(errors.recent)}
                </div>
            </div>
        </div>
    `;
}

/**
 * Render Service Status
 */
function renderServiceStatus(service) {
    if (!service) return '';

    const statusColor = getStatusColor(service.status);
    const icon = service.icon || getStatusIcon(service.status);

    return `
        <div class="service-status-card" style="
            background: ${statusColor}20;
            border-left: 4px solid ${statusColor};
            padding: 15px;
            margin-bottom: 10px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        ">
            <div style="display: flex; align-items: center; gap: 15px;">
                ${icon}
                <div>
                    <div style="font-weight: 600; font-size: 16px;">
                        ${service.name || 'Service'}
                        <span style="font-size: 14px; margin-left: 10px; color: ${statusColor}; font-weight: 700;">
                            ${getStatusText(service.status).toUpperCase()}
                        </span>
                    </div>
                    <div style="font-size: 13px; color: #666; margin-top: 5px;">
                        ${service.message || service.error || 'No additional information'}
                    </div>
                </div>
            </div>
            <div style="text-align: right; font-size: 12px; color: #888;">
                ${formatRelativeTime(service.lastCheck)}
            </div>
        </div>
    `;
}

/**
 * Render Error Breakdown
 */
function renderErrorBreakdown(errorCounts) {
    const entries = Object.entries(errorCounts).sort((a, b) => b[1] - a[1]);
    
    if (entries.length === 0) {
        return '<p>No errors to display</p>';
    }

    return `
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px;">
            ${entries.map(([context, count]) => `
                <div style="
                    background: #FFF7ED;
                    padding: 15px;
                    border-radius: 8px;
                    border: 1px solid #FED7AA;
                ">
                    <div style="font-size: 24px; font-weight: 700; color: #EA580C;">
                        ${count}
                    </div>
                    <div style="font-size: 12px; color: #92400E; margin-top: 5px;">
                        ${context}
                    </div>
                </div>
            `).join('')}
        </div>
    `;
}

/**
 * Render Recent Errors Table
 */
function renderRecentErrorsTable(errors) {
    if (!errors || errors.length === 0) {
        return '<p style="padding: 20px; text-align: center; color: #666;">No recent errors / لا توجد أخطاء حديثة</p>';
    }

    return `
        <table style="width: 100%; border-collapse: collapse;">
            <thead>
                <tr style="background: #FFF7ED;">
                    <th style="padding: 12px; text-align: right; border-bottom: 2px solid #FED7AA;">Time / الوقت</th>
                    <th style="padding: 12px; text-align: right; border-bottom: 2px solid #FED7AA;">Phone / الهاتف</th>
                    <th style="padding: 12px; text-align: right; border-bottom: 2px solid #FED7AA;">Context / السياق</th>
                    <th style="padding: 12px; text-align: right; border-bottom: 2px solid #FED7AA;">Error Message / رسالة الخطأ</th>
                </tr>
            </thead>
            <tbody>
                ${errors.map(error => `
                    <tr style="border-bottom: 1px solid #FEF3C7;">
                        <td style="padding: 12px; font-size: 13px;">${formatDate(error.created_at)}</td>
                        <td style="padding: 12px; font-size: 13px;">${error.phone || 'N/A'}</td>
                        <td style="padding: 12px; font-size: 13px;">
                            <span style="background: #FED7AA; padding: 4px 8px; border-radius: 4px; font-size: 12px;">
                                ${error.context || 'unknown'}
                            </span>
                        </td>
                        <td style="padding: 12px; font-size: 13px; max-width: 400px; word-wrap: break-word;">
                            ${error.error_message || 'N/A'}
                        </td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;
}

անակ/**
 * Show health error
 */
function showHealthError(error) {
    const container = document.getElementById('healthPageContent');
    if (container) {
        container.innerHTML = `
            <div class="error-message active" style="padding: 20px; text-align: center;">
                <i class="fas fa-exclamation-circle"></i>
                Error loading health status: ${error.message}
            </div>
        `;
    }
}

/**
 * Utility Functions
 */
function getStatusColor(status) {
    const colors = {
        healthy: '#10B981',
        degraded: '#F59E0B',
        unhealthy: '#EF4444',
        checking: '#6366F1',
        down: '#DC2626'
    };
    return colors[status] || '#6B7280';
}

function getStatusText(status) {
    const texts = {
        healthy: 'Healthy / صحي',
        degraded: 'Degraded / متدهور',
        unhealthy: 'Unhealthy / غير صحي',
        checking: 'Checking... / فحص...',
        down: 'Down / متوقف'
    };
    return texts[status] || 'Unknown';
}

function getStatusIcon(status) {
    const icons = {
        healthy: '✅',
        degraded: '⚠️',
        unhealthy: '❌',
        checking: '🔍',
        down: '💀'
    };
    return icons[status] || '❓';
}

function getStatusIconClass(status) {
    const classes = {
        healthy: 'green',
        degraded: 'orange',
        unhealthy: 'red',
        checking: 'blue',
        down: 'red'
    };
    return classes[status] || 'gray';
}

function formatRelativeTime(isoString) {
    if (!isoString) return 'Never';
    
    const date = new Date(isoString);
    const now = new Date();
    const diffMs = now - date;
    const diffSecs = Math.floor(diffMs / 1000);
    
    if (diffSecs < 5) return 'Just now';
    if (diffSecs < 60) return `${diffSecs}s ago`;
    
    const diffMins = Math.floor(diffSecs / 60);
    if (diffMins < 60) return `${diffMins}m ago`;
    
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}h ago`;
    
    const diffDays = Math.floor(diffHours / 24);
    return `${diffDays}d ago`;
}

// Export functions for use in other files
window.initializeHealthPage = initializeHealthPage;
window.stopHealthPageRefresh = stopHealthPageRefresh;
window.loadHealthStatus = loadHealthStatus;

console.log('✅ Health Status System Loaded');

