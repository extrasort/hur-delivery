/**
 * Emergency Monitoring - Track delayed orders and inactive drivers
 */

// =====================================================================================
// LOAD EMERGENCY DATA
// =====================================================================================

async function loadEmergency() {
    try {
        // Update last refresh time
        const now = new Date();
        document.getElementById('lastRefreshTime').textContent = now.toLocaleTimeString('en-US', { 
            hour: '2-digit', 
            minute: '2-digit' 
        });
        
        // Load both delayed orders and inactive drivers
        await Promise.all([
            loadDelayedOrders(),
            loadInactiveDrivers()
        ]);
        
    } catch (error) {
        console.error('Load emergency error:', error);
        showError('خطأ في تحميل بيانات الطوارئ / Error loading emergency data');
    }
}

// =====================================================================================
// DELAYED ORDERS (Over 1 Hour)
// =====================================================================================

async function loadDelayedOrders() {
    const container = document.getElementById('delayedOrdersTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        // Call the RPC function to get emergency orders
        const { data: orders, error } = await supabaseClient
            .rpc('get_emergency_orders');
        
        if (error) throw error;
        
        // Update count
        document.getElementById('delayedOrdersCount').textContent = orders?.length || 0;
        
        if (!orders || orders.length === 0) {
            container.innerHTML = '<div class="empty-state"><i class="fas fa-check-circle" style="color: #10B981; font-size: 48px;"></i><p>✅ لا توجد طلبات متأخرة / No delayed orders</p></div>';
            return;
        }
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>رقم الطلب / Order ID</th>
                        <th>الحالة / Status</th>
                        <th>التاجر / Merchant</th>
                        <th>السائق / Driver</th>
                        <th>الوقت المنقضي / Time Elapsed</th>
                        <th>تاريخ الإنشاء / Created</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${orders.map(order => {
                        const hours = Math.floor(order.minutes_elapsed / 60);
                        const minutes = order.minutes_elapsed % 60;
                        const timeElapsed = `${hours}h ${minutes}m`;
                        
                        const isCritical = order.severity === 'critical';
                        const urgencyColor = isCritical ? '#DC2626' : '#EA580C';
                        
                        return `
                            <tr class="${isCritical ? 'emergency-critical-row' : 'emergency-warning-row'}">
                                <td>
                                    <strong>#${order.order_number.substring(0, 8).toUpperCase()}</strong>
                                    ${isCritical ? '<br><span class="badge badge-critical">🚨 حرج / CRITICAL</span>' : ''}
                                </td>
                                <td><span class="badge badge-warning">${order.status}</span></td>
                                <td>
                                    ${order.merchant_name || 'N/A'}<br>
                                    <small>${order.merchant_phone || ''}</small>
                                    ${order.merchant_store ? `<br><small>${order.merchant_store}</small>` : ''}
                                </td>
                                <td>
                                    ${order.driver_name ? `
                                        ${order.driver_name}<br>
                                        <small>${order.driver_phone}</small>
                                    ` : '<span style="color: #DC2626;">⚠️ لا يوجد سائق / No driver</span>'}
                                </td>
                                <td>
                                    <strong style="color: ${urgencyColor}; font-size: 1.1em;">${timeElapsed}</strong>
                                    <br><small>${order.minutes_elapsed} minutes</small>
                                </td>
                                <td><small>${new Date(order.created_at).toLocaleString('ar-IQ')}</small></td>
                                <td>
                                    <div class="action-buttons">
                                        <button class="btn btn-sm btn-primary" onclick="viewOrder('${order.id}')" title="View Details">
                                            <i class="fas fa-eye"></i>
                                        </button>
                                        ${!order.driver_id ? `
                                            <button class="btn btn-sm btn-warning" onclick="assignDriver('${order.id}')" title="Assign Driver">
                                                <i class="fas fa-user-plus"></i> تعيين / Assign
                                            </button>
                                        ` : `
                                            <button class="btn btn-sm btn-info" onclick="callDriver('${order.driver_phone}')" title="Call Driver">
                                                <i class="fas fa-phone"></i> اتصال / Call
                                            </button>
                                            <button class="btn btn-sm btn-warning" onclick="reassignOrder('${order.id}')" title="Reassign">
                                                <i class="fas fa-exchange-alt"></i> إعادة تعيين / Reassign
                                            </button>
                                        `}
                                        <button class="btn btn-sm btn-danger" onclick="cancelOrderWithRefund('${order.id}')" title="Cancel with Refund">
                                            <i class="fas fa-times-circle"></i> إلغاء / Cancel
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        `;
                    }).join('')}
                </tbody>
            </table>
        `;
        
        container.innerHTML = table;
        
    } catch (error) {
        console.error('Load delayed orders error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

// =====================================================================================
// INACTIVE DRIVERS (Location not updated in 5+ minutes with active orders)
// =====================================================================================

async function loadInactiveDrivers() {
    const container = document.getElementById('inactiveDriversTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        // Call the RPC function to get inactive drivers
        const { data: drivers, error } = await supabaseClient
            .rpc('get_inactive_drivers');
        
        if (error) throw error;
        
        // Update counts
        document.getElementById('inactiveDriversCount').textContent = drivers?.length || 0;
        
        if (!drivers || drivers.length === 0) {
            container.innerHTML = '<div class="empty-state"><i class="fas fa-check-circle" style="color: #10B981; font-size: 48px;"></i><p>✅ جميع السائقين نشطون / All drivers active</p></div>';
            return;
        }
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>السائق / Driver</th>
                        <th>الحالة / Status</th>
                        <th>آخر تحديث موقع / Last Location Update</th>
                        <th>الوقت المنقضي / Time Since Update</th>
                        <th>الطلبات النشطة / Active Orders</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${drivers.map(driver => {
                        const isCritical = driver.severity === 'critical';
                        
                        return `
                            <tr class="${isCritical ? 'emergency-critical-row' : 'emergency-warning-row'}">
                                <td>
                                    <strong>${driver.driver_name}</strong><br>
                                    <small>${driver.driver_phone}</small>
                                    ${driver.driver_vehicle ? `<br><small>${driver.driver_vehicle}</small>` : ''}
                                    ${isCritical ? '<br><span class="badge badge-critical">🚨 حرج / CRITICAL</span>' : ''}
                                </td>
                                <td>
                                    <span class="badge badge-${driver.is_online ? 'success' : 'danger'}">
                                        ${driver.is_online ? '🟢 متصل / Online' : '🔴 غير متصل / Offline'}
                                    </span>
                                </td>
                                <td><small>${driver.last_location_update ? new Date(driver.last_location_update).toLocaleString('ar-IQ') : 'لا يوجد / None'}</small></td>
                                <td>
                                    <strong style="color: ${isCritical ? '#DC2626' : '#EA580C'}; font-size: 1.1em;">
                                        ${driver.minutes_since_update || 'N/A'} دقيقة / min
                                    </strong>
                                </td>
                                <td>
                                    <div>
                                        <span class="badge badge-warning">${driver.order_status}</span>
                                        <br><small>#${driver.active_order_number.substring(0, 8).toUpperCase()}</small>
                                        <br><small>${driver.customer_name}</small>
                                        ${driver.merchant_name ? `<br><small>من / From: ${driver.merchant_name}</small>` : ''}
                                    </div>
                                </td>
                                <td>
                                    <div class="action-buttons">
                                        <button class="btn btn-sm btn-danger" onclick="callDriver('${driver.driver_phone}')" title="Call Driver">
                                            <i class="fas fa-phone"></i> اتصال / Call
                                        </button>
                                        <button class="btn btn-sm btn-warning" onclick="sendEmergencyAlert('${driver.driver_id}')" title="Send Emergency Alert">
                                            <i class="fas fa-exclamation-triangle"></i> تنبيه / Alert
                                        </button>
                                        <button class="btn btn-sm btn-info" onclick="reassignOrder('${driver.active_order_id}')" title="Reassign Order">
                                            <i class="fas fa-exchange-alt"></i> إعادة تعيين / Reassign
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        `;
                    }).join('')}
                </tbody>
            </table>
        `;
        
        container.innerHTML = table;
        
    } catch (error) {
        console.error('Load inactive drivers error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

// =====================================================================================
// HELPER FUNCTIONS
// =====================================================================================

function callDriver(phone) {
    if (!phone) {
        showError('رقم الهاتف غير متوفر / Phone number not available');
        return;
    }
    
    // Show confirmation with call option
    const confirmed = confirm(`
        هل تريد الاتصال بالسائق؟
        Do you want to call the driver?
        
        Phone: ${phone}
    `);
    
    if (confirmed) {
        // Open phone dialer (works on mobile devices)
        window.location.href = `tel:${phone}`;
    }
}

async function sendEmergencyAlert(driverId) {
    if (!driverId) {
        showError('معرف السائق غير متوفر / Driver ID not available');
        return;
    }
    
    const message = prompt(`
        أدخل رسالة التنبيه للسائق:
        Enter alert message for driver:
    `, 'يرجى تحديث موقعك فوراً. لديك طلب نشط. / Please update your location immediately. You have an active order.');
    
    if (!message) return;
    
    try {
        const { data, error } = await supabaseClient
            .rpc('send_emergency_alert_to_driver', {
                p_driver_id: driverId,
                p_message: message
            });
        
        if (error) throw error;
        
        if (data) {
            alert('✅ تم إرسال التنبيه بنجاح / Alert sent successfully');
        } else {
            throw new Error('Failed to send alert');
        }
    } catch (error) {
        console.error('Send emergency alert error:', error);
        showError('خطأ في إرسال التنبيه / Error sending alert');
    }
}

// =====================================================================================
// AUTO-REFRESH EMERGENCY DATA
// =====================================================================================

let emergencyRefreshInterval = null;

function startEmergencyAutoRefresh() {
    // Refresh every 30 seconds
    if (emergencyRefreshInterval) {
        clearInterval(emergencyRefreshInterval);
    }
    
    emergencyRefreshInterval = setInterval(() => {
        loadEmergency();
    }, 30000); // 30 seconds
    
    console.log('✅ Emergency auto-refresh started (30 seconds)');
}

function stopEmergencyAutoRefresh() {
    if (emergencyRefreshInterval) {
        clearInterval(emergencyRefreshInterval);
        emergencyRefreshInterval = null;
        console.log('⏸️ Emergency auto-refresh stopped');
    }
}

// =====================================================================================
// EXPORT FUNCTIONS
// =====================================================================================

window.loadEmergency = loadEmergency;
window.loadDelayedOrders = loadDelayedOrders;
window.loadInactiveDrivers = loadInactiveDrivers;
// =====================================================================================
// SYSTEM SHUTDOWN / MAINTENANCE MODE
// =====================================================================================

async function checkSystemStatus() {
    try {
        const { data, error } = await supabaseClient
            .from('system_settings')
            .select('value')
            .eq('key', 'system_enabled')
            .single();
        
        if (error) throw error;
        
        const isEnabled = data.value === 'true';
        updateSystemStatusUI(isEnabled);
        return isEnabled;
    } catch (error) {
        console.error('Check system status error:', error);
        return true; // Assume enabled on error
    }
}

function updateSystemStatusUI(isEnabled) {
    const header = document.getElementById('systemStatusHeader');
    const icon = document.getElementById('systemStatusIcon');
    const text = document.getElementById('systemStatusText');
    const description = document.getElementById('systemStatusDescription');
    const btnText = document.getElementById('shutdownBtnText');
    const btn = document.getElementById('systemShutdownBtn');
    
    if (isEnabled) {
        header.style.background = '#DCFCE7';
        header.style.color = '#166534';
        icon.style.color = '#22C55E';
        text.textContent = 'النظام نشط / System Active';
        description.textContent = 'النظام يعمل بشكل طبيعي. جميع الميزات متاحة. / System is operating normally. All features available.';
        btnText.textContent = 'إيقاف النظام / Shutdown System';
        btn.className = 'btn btn-danger';
    } else {
        header.style.background = '#FEE2E2';
        header.style.color = '#991B1B';
        icon.style.color = '#EF4444';
        text.textContent = '⚠️ النظام في وضع الصيانة / System in Maintenance Mode';
        description.textContent = '🔧 النظام حالياً متوقف للصيانة. لا يمكن إنشاء أو قبول طلبات جديدة. السائقون لا يمكنهم الاتصال. / System is currently down for maintenance. No new orders can be created or accepted. Drivers cannot go online.';
        btnText.textContent = 'تفعيل النظام / Activate System';
        btn.className = 'btn btn-success';
    }
}

async function toggleSystemShutdown() {
    try {
        // Get current status
        const { data: current, error: fetchError } = await supabaseClient
            .from('system_settings')
            .select('value')
            .eq('key', 'system_enabled')
            .single();
        
        if (fetchError) throw fetchError;
        
        const currentlyEnabled = current.value === 'true';
        const newStatus = !currentlyEnabled;
        
        // Confirm action
        const action = newStatus ? 'تفعيل' : 'إيقاف';
        const confirmMessage = newStatus
            ? '✅ هل أنت متأكد من تفعيل النظام؟\n\nسيتمكن السائقون من الاتصال والمستخدمون من إنشاء الطلبات.\n\nAre you sure you want to activate the system?\n\nDrivers will be able to go online and users can create orders.'
            : '⚠️ هل أنت متأكد من إيقاف النظام؟\n\nسيتم:\n• فصل جميع السائقين المتصلين\n• منع إنشاء طلبات جديدة\n• منع السائقين من الاتصال\n\nAre you sure you want to shutdown the system?\n\nThis will:\n• Force all drivers offline\n• Prevent new orders\n• Block drivers from going online';
        
        if (!confirm(confirmMessage)) {
            return;
        }
        
        // Update system status
        const { error: updateError } = await supabaseClient
            .from('system_settings')
            .update({ value: newStatus.toString() })
            .eq('key', 'system_enabled');
        
        if (updateError) throw updateError;
        
        // If disabling system, force all drivers offline
        if (!newStatus) {
            const { data: result, error: forceError } = await supabaseClient
                .rpc('force_all_drivers_offline');
            
            if (forceError) {
                console.error('Force offline error:', forceError);
            } else {
                const driversCount = result || 0;
                document.getElementById('onlineDriversInfo').innerHTML = `
                    <div style="margin-top: 12px; padding: 12px; background: #FEE2E2; border-radius: 8px; color: #991B1B;">
                        <i class="fas fa-check-circle"></i> تم فصل ${driversCount} سائق من الخدمة / ${driversCount} driver(s) forced offline
                    </div>
                `;
            }
        } else {
            document.getElementById('onlineDriversInfo').innerHTML = '';
        }
        
        // Update UI
        updateSystemStatusUI(newStatus);
        
        // Show success message
        alert(newStatus 
            ? '✅ تم تفعيل النظام بنجاح / System activated successfully'
            : '⚠️ تم إيقاف النظام / System shutdown complete'
        );
        
        // Reload emergency data
        loadEmergency();
        
    } catch (error) {
        console.error('Toggle system shutdown error:', error);
        alert('❌ خطأ / Error: ' + (error.message || error));
    }
}

// =====================================================================================
// APP VERSION CONTROL
// =====================================================================================

async function loadMinAppVersion() {
    try {
        const { data, error } = await supabaseClient
            .from('system_settings')
            .select('value')
            .eq('key', 'min_app_version')
            .single();
        
        if (error) throw error;
        
        const version = data?.value || '1.0.0';
        document.getElementById('minAppVersion').value = version;
        console.log('Current min app version:', version);
    } catch (error) {
        console.error('Load min app version error:', error);
        document.getElementById('minAppVersion').value = '1.0.0';
    }
}

async function updateMinAppVersion() {
    const statusDiv = document.getElementById('versionUpdateStatus');
    const versionInput = document.getElementById('minAppVersion');
    const newVersion = versionInput.value.trim();
    
    // Validate semantic versioning format
    const versionPattern = /^\d+\.\d+\.\d+$/;
    if (!versionPattern.test(newVersion)) {
        statusDiv.innerHTML = `
            <div style="padding: 12px; background: #FEE2E2; border-radius: 8px; color: #991B1B;">
                <i class="fas fa-exclamation-circle"></i> خطأ: الرجاء استخدام صيغة الإصدار الصحيحة (مثال: 1.0.0) / Error: Use valid version format (e.g., 1.0.0)
            </div>
        `;
        return;
    }
    
    try {
        statusDiv.innerHTML = '<p class="loading">جاري الحفظ...</p>';
        
        // Update the min_app_version in system_settings
        const { error } = await supabaseClient
            .from('system_settings')
            .update({ value: newVersion })
            .eq('key', 'min_app_version');
        
        if (error) throw error;
        
        statusDiv.innerHTML = `
            <div style="padding: 12px; background: #DCFCE7; border-radius: 8px; color: #166534;">
                <i class="fas fa-check-circle"></i> ✅ تم تحديث الإصدار المطلوب بنجاح / Minimum version updated successfully to ${newVersion}
                <br><small style="margin-top: 8px; display: block;">المستخدمون الذين لديهم إصدار أقل من ${newVersion} سيُطالبون بالتحديث / Users with versions below ${newVersion} will be forced to update</small>
            </div>
        `;
        
        console.log('Min app version updated to:', newVersion);
    } catch (error) {
        console.error('Update min app version error:', error);
        statusDiv.innerHTML = `
            <div style="padding: 12px; background: #FEE2E2; border-radius: 8px; color: #991B1B;">
                <i class="fas fa-exclamation-circle"></i> ❌ خطأ / Error: ${error.message}
            </div>
        `;
    }
}

// Check system status when emergency page loads
function initializeEmergencyPage() {
    checkSystemStatus();
    loadMinAppVersion();
    loadEmergency();
}

window.callDriver = callDriver;
window.sendEmergencyAlert = sendEmergencyAlert;
window.startEmergencyAutoRefresh = startEmergencyAutoRefresh;
window.stopEmergencyAutoRefresh = stopEmergencyAutoRefresh;
window.toggleSystemShutdown = toggleSystemShutdown;
window.checkSystemStatus = checkSystemStatus;
window.updateMinAppVersion = updateMinAppVersion;
window.initializeEmergencyPage = initializeEmergencyPage;

