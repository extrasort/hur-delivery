// =====================================================================================
// ADMIN PANEL - ALL NEW FEATURES
// =====================================================================================
// This file contains all logic for the new admin features
// =====================================================================================

// =====================================================================================
// FINANCIAL DASHBOARD
// =====================================================================================

async function loadFinancialDashboard() {
    const summaryContainer = document.getElementById('financialSummary');
    const tableContainer = document.getElementById('dailyRevenueTable');
    
    summaryContainer.innerHTML = '<p class="loading">جاري التحميل...</p>';
    tableContainer.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        // Get financial summary for last 30 days
        const { data: summary, error: summaryError } = await supabaseClient
            .rpc('get_financial_summary', {
                p_start_date: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
                p_end_date: new Date().toISOString()
            });
        
        if (summaryError) throw summaryError;
        
        // Display summary cards
        summaryContainer.innerHTML = `
            <div class="card">
                <div class="card-icon" style="background: linear-gradient(135deg, #10B981 0%, #059669 100%);">
                    <i class="fas fa-dollar-sign"></i>
                </div>
                <div class="card-info">
                    <h3>${formatCurrency(summary.revenue.total)}</h3>
                    <p>إجمالي الإيرادات / Total Revenue</p>
                    <small>(آخر 30 يوم / Last 30 days)</small>
                </div>
            </div>
            
            <div class="card">
                <div class="card-icon" style="background: linear-gradient(135deg, #3B82F6 0%, #2563EB 100%);">
                    <i class="fas fa-percentage"></i>
                </div>
                <div class="card-info">
                    <h3>${formatCurrency(summary.revenue.commission)}</h3>
                    <p>العمولات / Commission</p>
                    <small>(10% من الإيرادات)</small>
                </div>
            </div>
            
            <div class="card">
                <div class="card-icon" style="background: linear-gradient(135deg, #8B5CF6 0%, #7C3AED 100%);">
                    <i class="fas fa-box"></i>
                </div>
                <div class="card-info">
                    <h3>${summary.orders.completed}</h3>
                    <p>الطلبات المكتملة / Completed Orders</p>
                    <small>(${summary.orders.completion_rate}% معدل الإكمال)</small>
                </div>
            </div>
            
            <div class="card">
                <div class="card-icon" style="background: linear-gradient(135deg, #EF4444 0%, #DC2626 100%);">
                    <i class="fas fa-wallet"></i>
                </div>
                <div class="card-info">
                    <h3>${formatCurrency(summary.balances.outstanding_driver_payments)}</h3>
                    <p>المدفوعات المعلقة / Outstanding Payments</p>
                    <small>(للسائقين)</small>
                </div>
            </div>
        `;
        
        // Get daily revenue report
        const { data: dailyReport, error: reportError } = await supabaseClient
            .rpc('get_daily_revenue_report', { p_days: 30 });
        
        if (reportError) throw reportError;
        
        // Display daily report table
        tableContainer.innerHTML = `
            <table>
                <thead>
                    <tr>
                        <th>التاريخ / Date</th>
                        <th>إجمالي الطلبات / Total Orders</th>
                        <th>المكتملة / Completed</th>
                        <th>الإيرادات / Revenue</th>
                        <th>العمولة / Commission</th>
                    </tr>
                </thead>
                <tbody>
                    ${dailyReport.map(day => `
                        <tr>
                            <td><strong>${new Date(day.report_date).toLocaleDateString('ar-IQ')}</strong></td>
                            <td>${day.total_orders}</td>
                            <td><span class="badge badge-success">${day.completed_orders}</span></td>
                            <td style="color: var(--success)">${formatCurrency(day.total_revenue)}</td>
                            <td>${formatCurrency(day.commission_earned)}</td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;
        
    } catch (error) {
        console.error('Load financial dashboard error:', error);
        summaryContainer.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

// =====================================================================================
// REVIEWS & RATINGS
// =====================================================================================

async function loadReviews() {
    const container = document.getElementById('reviewsContent');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        const { data: reviews, error } = await supabaseClient
            .rpc('get_recent_reviews', { p_limit: 100 });
        
        if (error) throw error;
        
        if (!reviews || reviews.length === 0) {
            container.innerHTML = '<p class="loading">لا توجد مراجعات / No reviews yet</p>';
            return;
        }
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>النوع / Type</th>
                        <th>المستخدم / User</th>
                        <th>العميل / Customer</th>
                        <th>التقييم / Rating</th>
                        <th>المراجعة / Review</th>
                        <th>الحالة / Status</th>
                        <th>التاريخ / Date</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${reviews.map(review => {
                        const stars = '⭐'.repeat(review.rating);
                        return `
                            <tr style="${review.is_flagged ? 'background: #FEE2E2;' : ''}">
                                <td><span class="badge badge-${review.review_type === 'driver' ? 'primary' : 'warning'}">${review.review_type === 'driver' ? 'سائق / Driver' : 'تاجر / Merchant'}</span></td>
                                <td><strong>${review.rated_user_name}</strong></td>
                                <td>${review.customer_name}</td>
                                <td><span style="font-size: 1.2em;">${stars}</span><br><small>${review.rating}/5</small></td>
                                <td><small>${review.review_text || 'لا يوجد نص / No text'}</small></td>
                                <td>${review.is_flagged ? '<span class="badge" style="background: #EF4444;">⚠️ مبلغ عنه / Flagged</span>' : '<span class="badge badge-success">✅ عادي / Normal</span>'}</td>
                                <td><small>${new Date(review.created_at).toLocaleDateString('ar-IQ')}</small></td>
                                <td>
                                    <div class="action-buttons">
                                        ${!review.is_flagged ? `
                                            <button class="btn btn-sm btn-danger" onclick="flagReview('${review.review_id}', '${review.review_type}', true)">
                                                <i class="fas fa-flag"></i> إبلاغ / Flag
                                            </button>
                                        ` : `
                                            <button class="btn btn-sm btn-success" onclick="flagReview('${review.review_id}', '${review.review_type}', false)">
                                                <i class="fas fa-check"></i> إلغاء الإبلاغ / Unflag
                                            </button>
                                        `}
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
        console.error('Load reviews error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

async function flagReview(reviewId, reviewType, isFlagged) {
    let reason = null;
    if (isFlagged) {
        reason = prompt('سبب الإبلاغ / Flag reason:', 'Inappropriate content');
        if (!reason) return;
    }
    
    try {
        const { data, error } = await supabaseClient
            .rpc('admin_flag_review', {
                p_review_id: reviewId,
                p_review_type: reviewType,
                p_is_flagged: isFlagged,
                p_flag_reason: reason
            });
        
        if (error) throw error;
        
        alert(isFlagged ? '✅ تم الإبلاغ / Review flagged' : '✅ تم إلغاء الإبلاغ / Review unflagged');
        loadReviews();
    } catch (error) {
        console.error('Flag review error:', error);
        alert('❌ خطأ / Error');
    }
}

// =====================================================================================
// PROMO CODES
// =====================================================================================

async function loadPromoCodes() {
    const container = document.getElementById('promoCodesTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        const { data: promoCodes, error } = await supabaseClient
            .rpc('get_promo_codes_with_stats');
        
        if (error) throw error;
        
        if (!promoCodes || promoCodes.length === 0) {
            container.innerHTML = '<p class="loading">لا توجد أكواد / No promo codes yet</p>';
            return;
        }
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>الكود / Code</th>
                        <th>الوصف / Description</th>
                        <th>الخصم / Discount</th>
                        <th>الاستخدام / Usage</th>
                        <th>الحالة / Status</th>
                        <th>الصلاحية / Validity</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${promoCodes.map(promo => {
                        const discountText = promo.discount_type === 'percentage' 
                            ? `${promo.discount_value}%` 
                            : `${formatCurrency(promo.discount_value)}`;
                        const usageText = promo.usage_limit 
                            ? `${promo.usage_count} / ${promo.usage_limit}` 
                            : `${promo.usage_count}`;
                        const isExpired = promo.valid_until && new Date(promo.valid_until) < new Date();
                        
                        return `
                            <tr>
                                <td><strong style="font-family: monospace; font-size: 1.1em;">${promo.code}</strong></td>
                                <td><small>${promo.description || 'لا يوجد'}</small></td>
                                <td><span class="badge badge-primary">${discountText}</span></td>
                                <td>${usageText}</td>
                                <td>
                                    ${promo.is_active && !isExpired 
                                        ? '<span class="badge badge-success">✅ نشط / Active</span>' 
                                        : '<span class="badge badge-danger">❌ غير نشط / Inactive</span>'}
                                    ${isExpired ? '<br><small style="color: #EF4444;">منتهي الصلاحية / Expired</small>' : ''}
                                </td>
                                <td>
                                    <small>من / From: ${new Date(promo.valid_from).toLocaleDateString('ar-IQ')}</small><br>
                                    <small>إلى / To: ${promo.valid_until ? new Date(promo.valid_until).toLocaleDateString('ar-IQ') : '∞'}</small>
                                </td>
                                <td>
                                    <div class="action-buttons">
                                        <button class="btn btn-sm btn-${promo.is_active ? 'danger' : 'success'}" 
                                                onclick="togglePromoCode('${promo.id}', ${!promo.is_active})">
                                            <i class="fas fa-${promo.is_active ? 'stop' : 'play'}"></i> 
                                            ${promo.is_active ? 'إيقاف / Deactivate' : 'تفعيل / Activate'}
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
        console.error('Load promo codes error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

function openCreatePromoModal() {
    const modalBody = document.getElementById('walletModalBody');
    modalBody.innerHTML = `
        <form id="createPromoForm" class="form-container">
            <div class="form-group">
                <label>الكود / Code *</label>
                <input type="text" id="promoCode" class="form-control" required 
                       placeholder="WELCOME10" style="text-transform: uppercase;">
                <small>أحرف كبيرة وأرقام فقط / Uppercase letters and numbers only</small>
            </div>
            
            <div class="form-group">
                <label>الوصف / Description</label>
                <input type="text" id="promoDescription" class="form-control" 
                       placeholder="Welcome discount for new users">
            </div>
            
            <div class="form-group">
                <label>نوع الخصم / Discount Type *</label>
                <select id="promoDiscountType" class="form-control" required>
                    <option value="percentage">نسبة مئوية / Percentage (%)</option>
                    <option value="fixed">قيمة ثابتة / Fixed Amount (IQD)</option>
                </select>
            </div>
            
            <div class="form-group">
                <label>قيمة الخصم / Discount Value *</label>
                <input type="number" id="promoDiscountValue" class="form-control" required min="0" step="1">
                <small id="discountHelper">مثال: 10 للحصول على خصم 10% / Example: 10 for 10% discount</small>
            </div>
            
            <div class="form-group">
                <label>الحد الأدنى للطلب / Minimum Order (IQD)</label>
                <input type="number" id="promoMinOrder" class="form-control" value="0" min="0" step="1000">
            </div>
            
            <div class="form-group">
                <label>الحد الأقصى للخصم / Maximum Discount (IQD)</label>
                <input type="number" id="promoMaxDiscount" class="form-control" min="0" step="1000">
                <small>اختياري / Optional</small>
            </div>
            
            <div class="form-group">
                <label>حد الاستخدام الكلي / Total Usage Limit</label>
                <input type="number" id="promoUsageLimit" class="form-control" min="1" step="1">
                <small>اختياري - اتركه فارغاً لاستخدام غير محدود / Optional - leave empty for unlimited</small>
            </div>
            
            <div class="form-group">
                <label>حد الاستخدام لكل مستخدم / Per User Limit</label>
                <input type="number" id="promoPerUserLimit" class="form-control" value="1" min="1" step="1">
            </div>
            
            <div class="form-group">
                <label>صالح حتى / Valid Until</label>
                <input type="datetime-local" id="promoValidUntil" class="form-control">
                <small>اختياري / Optional</small>
            </div>
            
            <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                    <i class="fas fa-check"></i> إنشاء الكود / Create Code
                </button>
                <button type="button" class="btn btn-secondary" onclick="closeAllModals()">
                    <i class="fas fa-times"></i> إلغاء / Cancel
                </button>
            </div>
        </form>
    `;
    
    // Update helper text based on discount type
    document.getElementById('promoDiscountType').addEventListener('change', (e) => {
        const helper = document.getElementById('discountHelper');
        if (e.target.value === 'percentage') {
            helper.textContent = 'مثال: 10 للحصول على خصم 10% / Example: 10 for 10% discount';
        } else {
            helper.textContent = 'مثال: 5000 للحصول على خصم 5000 IQD / Example: 5000 for 5000 IQD discount';
        }
    });
    
    document.getElementById('createPromoForm').onsubmit = async (e) => {
        e.preventDefault();
        
        const code = document.getElementById('promoCode').value.toUpperCase();
        const description = document.getElementById('promoDescription').value;
        const discountType = document.getElementById('promoDiscountType').value;
        const discountValue = parseFloat(document.getElementById('promoDiscountValue').value);
        const minOrder = parseFloat(document.getElementById('promoMinOrder').value) || 0;
        const maxDiscount = document.getElementById('promoMaxDiscount').value ? 
            parseFloat(document.getElementById('promoMaxDiscount').value) : null;
        const usageLimit = document.getElementById('promoUsageLimit').value ? 
            parseInt(document.getElementById('promoUsageLimit').value) : null;
        const perUserLimit = parseInt(document.getElementById('promoPerUserLimit').value);
        const validUntil = document.getElementById('promoValidUntil').value ? 
            new Date(document.getElementById('promoValidUntil').value).toISOString() : null;
        
        try {
            const { data, error } = await supabaseClient
                .rpc('create_promo_code', {
                    p_code: code,
                    p_description: description,
                    p_discount_type: discountType,
                    p_discount_value: discountValue,
                    p_min_order_amount: minOrder,
                    p_max_discount_amount: maxDiscount,
                    p_usage_limit: usageLimit,
                    p_per_user_limit: perUserLimit,
                    p_valid_from: new Date().toISOString(),
                    p_valid_until: validUntil
                });
            
            if (error) throw error;
            
            alert('✅ تم إنشاء الكود بنجاح / Promo code created successfully');
            closeAllModals();
            loadPromoCodes();
        } catch (error) {
            console.error('Create promo code error:', error);
            alert('❌ خطأ في إنشاء الكود / Error creating code\n' + (error.message || ''));
        }
    };
    
    openModal('walletModal');
}

async function togglePromoCode(promoId, isActive) {
    if (!confirm(`${isActive ? 'تفعيل' : 'إيقاف'} الكود؟ / ${isActive ? 'Activate' : 'Deactivate'} code?`)) {
        return;
    }
    
    try {
        const { data, error } = await supabaseClient
            .rpc('toggle_promo_code_status', {
                p_promo_id: promoId,
                p_is_active: isActive
            });
        
        if (error) throw error;
        
        alert('✅ تم التحديث / Updated successfully');
        loadPromoCodes();
    } catch (error) {
        console.error('Toggle promo code error:', error);
        alert('❌ خطأ / Error');
    }
}

// =====================================================================================
// DELIVERY ZONES
// =====================================================================================

async function loadDeliveryZones() {
    const container = document.getElementById('zonesTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        const { data: zones, error } = await supabaseClient
            .from('delivery_zones')
            .select('*')
            .order('priority', { ascending: false });
        
        if (error) throw error;
        
        if (!zones || zones.length === 0) {
            container.innerHTML = '<p class="loading">لا توجد مناطق / No zones yet</p>';
            return;
        }
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>المنطقة / Zone</th>
                        <th>الوصف / Description</th>
                        <th>رسوم التوصيل / Delivery Fee</th>
                        <th>معامل الذروة / Peak Multiplier</th>
                        <th>الأولوية / Priority</th>
                        <th>الحالة / Status</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${zones.map(zone => `
                        <tr>
                            <td><strong>${zone.name}</strong></td>
                            <td><small>${zone.description || 'لا يوجد'}</small></td>
                            <td>${formatCurrency(zone.base_delivery_fee)}</td>
                            <td><span class="badge badge-info">×${zone.peak_hour_multiplier}</span></td>
                            <td><span class="badge badge-secondary">${zone.priority}</span></td>
                            <td>${zone.is_active ? '<span class="badge badge-success">✅ نشط</span>' : '<span class="badge badge-danger">❌ غير نشط</span>'}</td>
                            <td>
                                <div class="action-buttons">
                                    <button class="btn btn-sm btn-warning" onclick="editZone('${zone.id}')">
                                        <i class="fas fa-edit"></i> تعديل / Edit
                                    </button>
                                    <button class="btn btn-sm btn-${zone.is_active ? 'danger' : 'success'}" 
                                            onclick="toggleZone('${zone.id}', ${!zone.is_active})">
                                        <i class="fas fa-${zone.is_active ? 'stop' : 'play'}"></i>
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
        console.error('Load zones error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

function openCreateZoneModal() {
    alert('⚠️ Zone creation with map drawing will be implemented in Phase 2\nFor now, use direct SQL to create zones.');
}

function editZone(zoneId) {
    alert('⚠️ Zone editing UI will be implemented in Phase 2');
}

async function toggleZone(zoneId, isActive) {
    try {
        const { error } = await supabaseClient
            .from('delivery_zones')
            .update({ is_active: isActive, updated_at: new Date().toISOString() })
            .eq('id', zoneId);
        
        if (error) throw error;
        
        alert('✅ تم التحديث / Updated successfully');
        loadDeliveryZones();
    } catch (error) {
        console.error('Toggle zone error:', error);
        alert('❌ خطأ / Error');
    }
}

// =====================================================================================
// BLACKLIST MANAGEMENT
// =====================================================================================

async function loadBlacklist() {
    const container = document.getElementById('blacklistTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        const { data: blacklist, error } = await supabaseClient
            .from('blacklist')
            .select(`
                *,
                user:users!blacklist_user_id_fkey(name)
            `)
            .order('created_at', { ascending: false });
        
        if (error) throw error;
        
        if (!blacklist || blacklist.length === 0) {
            container.innerHTML = '<p class="loading">القائمة فارغة / No blacklisted users</p>';
            return;
        }
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>الهاتف / Phone</th>
                        <th>المستخدم / User</th>
                        <th>السبب / Reason</th>
                        <th>النوع / Type</th>
                        <th>الحالة / Status</th>
                        <th>التاريخ / Date</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${blacklist.map(item => {
                        const isExpired = item.ban_type === 'temporary' && 
                            item.banned_until && 
                            new Date(item.banned_until) < new Date();
                        const isActive = item.is_active && !isExpired;
                        
                        return `
                            <tr style="${isActive ? 'background: #FEE2E2;' : ''}">
                                <td><strong>${item.phone}</strong></td>
                                <td>${item.user?.name || 'غير مسجل / Not registered'}</td>
                                <td><small>${item.reason}</small></td>
                                <td>
                                    <span class="badge badge-${item.ban_type === 'permanent' ? 'danger' : 'warning'}">
                                        ${item.ban_type === 'permanent' ? '🚫 دائم / Permanent' : '⏰ مؤقت / Temporary'}
                                    </span>
                                    ${item.ban_type === 'temporary' && item.banned_until ? 
                                        `<br><small>حتى / Until: ${new Date(item.banned_until).toLocaleDateString('ar-IQ')}</small>` : ''}
                                </td>
                                <td>
                                    ${isActive 
                                        ? '<span class="badge badge-danger">🔴 محظور / Blocked</span>' 
                                        : '<span class="badge badge-success">🟢 غير محظور / Unblocked</span>'}
                                </td>
                                <td><small>${new Date(item.created_at).toLocaleDateString('ar-IQ')}</small></td>
                                <td>
                                    <div class="action-buttons">
                                        ${isActive ? `
                                            <button class="btn btn-sm btn-success" onclick="removeFromBlacklist('${item.id}')">
                                                <i class="fas fa-unlock"></i> إلغاء الحظر / Unblock
                                            </button>
                                        ` : ''}
                                        ${item.notes ? `
                                            <button class="btn btn-sm btn-info" onclick="alert('الملاحظات:\\n${item.notes}')">
                                                <i class="fas fa-sticky-note"></i> ملاحظات / Notes
                                            </button>
                                        ` : ''}
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
        console.error('Load blacklist error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

function openAddBlacklistModal() {
    const modalBody = document.getElementById('walletModalBody');
    modalBody.innerHTML = `
        <form id="addBlacklistForm" class="form-container">
            <div class="form-group">
                <label>رقم الهاتف / Phone Number *</label>
                <input type="tel" id="blacklistPhone" class="form-control" required 
                       placeholder="07701234567" pattern="[0-9]{11}">
            </div>
            
            <div class="form-group">
                <label>السبب / Reason *</label>
                <select id="blacklistReason" class="form-control" required>
                    <option value="">-- اختر السبب / Select Reason --</option>
                    <option value="fraud">احتيال / Fraud</option>
                    <option value="spam">إزعاج / Spam</option>
                    <option value="abuse">سوء استخدام / Abuse</option>
                    <option value="fake_orders">طلبات وهمية / Fake Orders</option>
                    <option value="payment_issues">مشاكل دفع / Payment Issues</option>
                    <option value="other">أخرى / Other</option>
                </select>
            </div>
            
            <div class="form-group">
                <label>نوع الحظر / Ban Type *</label>
                <select id="blacklistBanType" class="form-control" required>
                    <option value="permanent">دائم / Permanent</option>
                    <option value="temporary">مؤقت / Temporary</option>
                </select>
            </div>
            
            <div class="form-group" id="bannedUntilGroup" style="display: none;">
                <label>محظور حتى / Banned Until</label>
                <input type="datetime-local" id="blacklistBannedUntil" class="form-control">
            </div>
            
            <div class="form-group">
                <label>ملاحظات / Notes</label>
                <textarea id="blacklistNotes" class="form-control" rows="3"></textarea>
            </div>
            
            <div class="form-actions">
                <button type="submit" class="btn btn-danger">
                    <i class="fas fa-ban"></i> حظر المستخدم / Block User
                </button>
                <button type="button" class="btn btn-secondary" onclick="closeAllModals()">
                    <i class="fas fa-times"></i> إلغاء / Cancel
                </button>
            </div>
        </form>
    `;
    
    // Show/hide banned_until field
    document.getElementById('blacklistBanType').addEventListener('change', (e) => {
        document.getElementById('bannedUntilGroup').style.display = 
            e.target.value === 'temporary' ? 'block' : 'none';
    });
    
    document.getElementById('addBlacklistForm').onsubmit = async (e) => {
        e.preventDefault();
        
        const phone = document.getElementById('blacklistPhone').value;
        const reason = document.getElementById('blacklistReason').value;
        const banType = document.getElementById('blacklistBanType').value;
        const bannedUntil = document.getElementById('blacklistBannedUntil').value ?
            new Date(document.getElementById('blacklistBannedUntil').value).toISOString() : null;
        const notes = document.getElementById('blacklistNotes').value;
        
        if (!confirm(`تأكيد حظر ${phone}؟\nConfirm blocking ${phone}?`)) return;
        
        try {
            const { data, error } = await supabaseClient
                .rpc('add_to_blacklist', {
                    p_phone: phone,
                    p_user_id: null,
                    p_reason: reason,
                    p_ban_type: banType,
                    p_banned_until: bannedUntil,
                    p_notes: notes
                });
            
            if (error) throw error;
            
            alert('✅ تم حظر المستخدم / User blocked successfully');
            closeAllModals();
            loadBlacklist();
        } catch (error) {
            console.error('Add to blacklist error:', error);
            alert('❌ خطأ / Error: ' + (error.message || ''));
        }
    };
    
    openModal('walletModal');
}

async function removeFromBlacklist(blacklistId) {
    if (!confirm('إلغاء الحظر؟ / Remove from blacklist?')) return;
    
    try {
        const { data, error } = await supabaseClient
            .rpc('remove_from_blacklist', {
                p_blacklist_id: blacklistId
            });
        
        if (error) throw error;
        
        alert('✅ تم إلغاء الحظر / Unblocked successfully');
        loadBlacklist();
    } catch (error) {
        console.error('Remove from blacklist error:', error);
        alert('❌ خطأ / Error');
    }
}

// =====================================================================================
// DISPUTES MANAGEMENT
// =====================================================================================

async function loadDisputes() {
    const container = document.getElementById('disputesTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        const { data: disputes, error } = await supabaseClient
            .from('disputes')
            .select(`
                *,
                filed_by_user:users!filed_by(name, phone),
                order:orders(id, status, total_amount)
            `)
            .order('created_at', { ascending: false });
        
        if (error) throw error;
        
        if (!disputes || disputes.length === 0) {
            container.innerHTML = '<p class="loading">لا توجد نزاعات / No disputes</p>';
            return;
        }
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>رقم النزاع / Dispute ID</th>
                        <th>المبلغ عنه / Filed By</th>
                        <th>النوع / Type</th>
                        <th>الوصف / Description</th>
                        <th>الحالة / Status</th>
                        <th>التاريخ / Date</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${disputes.map(dispute => {
                        const statusColors = {
                            pending: 'warning',
                            investigating: 'info',
                            resolved: 'success',
                            rejected: 'danger'
                        };
                        
                        return `
                            <tr>
                                <td><small>${dispute.id.substring(0, 8)}</small></td>
                                <td>
                                    <strong>${dispute.filed_by_user?.name || 'N/A'}</strong><br>
                                    <small>${dispute.filed_by_user?.phone || ''}</small><br>
                                    <span class="badge badge-secondary">${dispute.filed_by_role}</span>
                                </td>
                                <td><span class="badge badge-info">${dispute.dispute_type}</span></td>
                                <td><small>${dispute.description.substring(0, 100)}...</small></td>
                                <td><span class="badge badge-${statusColors[dispute.status]}">${dispute.status}</span></td>
                                <td><small>${new Date(dispute.created_at).toLocaleDateString('ar-IQ')}</small></td>
                                <td>
                                    <div class="action-buttons">
                                        <button class="btn btn-sm btn-primary" onclick="viewDispute('${dispute.id}')">
                                            <i class="fas fa-eye"></i> عرض / View
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
        console.error('Load disputes error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

function viewDispute(disputeId) {
    alert('⚠️ Dispute details view will be implemented in Phase 2');
}

// =====================================================================================
// CUSTOMER MANAGEMENT
// =====================================================================================

async function loadCustomers() {
    const container = document.getElementById('customersTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        // Get customers (users without driver/merchant/admin roles)
        const { data: customers, error } = await supabaseClient
            .from('users')
            .select('*')
            .is('role', null)
            .order('created_at', { ascending: false })
            .limit(100);
        
        if (error) throw error;
        
        if (!customers || customers.length === 0) {
            container.innerHTML = '<p class="loading">لا يوجد عملاء / No customers</p>';
            return;
        }
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>الاسم / Name</th>
                        <th>الهاتف / Phone</th>
                        <th>تاريخ التسجيل / Registered</th>
                        <th>آخر ظهور / Last Seen</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${customers.map(customer => `
                        <tr>
                            <td><strong>${customer.name || 'N/A'}</strong></td>
                            <td>${customer.phone}</td>
                            <td><small>${new Date(customer.created_at).toLocaleDateString('ar-IQ')}</small></td>
                            <td><small>${customer.last_seen_at ? new Date(customer.last_seen_at).toLocaleString('ar-IQ') : 'لم يسجل دخول'}</small></td>
                            <td>
                                <div class="action-buttons">
                                    <button class="btn btn-sm btn-primary" onclick="viewCustomerDetails('${customer.id}')">
                                        <i class="fas fa-eye"></i> التفاصيل / Details
                                    </button>
                                    <button class="btn btn-sm btn-warning" onclick="addCustomerNote('${customer.id}')">
                                        <i class="fas fa-sticky-note"></i> ملاحظة / Note
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
        console.error('Load customers error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

async function viewCustomerDetails(customerId) {
    try {
        const { data: details, error } = await supabaseClient
            .rpc('get_customer_details', { p_customer_id: customerId });
        
        if (error) throw error;
        
        const modalBody = document.getElementById('walletModalBody');
        modalBody.innerHTML = `
            <div class="form-container">
                <h3>معلومات العميل / Customer Information</h3>
                <div class="form-group">
                    <label>الاسم / Name:</label>
                    <p>${details.customer_info.name || 'N/A'}</p>
                </div>
                <div class="form-group">
                    <label>الهاتف / Phone:</label>
                    <p>${details.customer_info.phone}</p>
                </div>
                
                <h3>إحصائيات الطلبات / Order Statistics</h3>
                <div class="cards-grid">
                    <div class="info-box" style="background: #EFF6FF;">
                        <strong>إجمالي الطلبات / Total Orders:</strong> ${details.order_stats.total_orders}
                    </div>
                    <div class="info-box" style="background: #F0FDF4;">
                        <strong>المكتملة / Completed:</strong> ${details.order_stats.completed_orders}
                    </div>
                    <div class="info-box" style="background: #FEF3C7;">
                        <strong>إجمالي المصروف / Total Spent:</strong> ${formatCurrency(details.order_stats.total_spent)}
                    </div>
                    <div class="info-box" style="background: #F3E8FF;">
                        <strong>متوسط الطلب / Avg Order:</strong> ${formatCurrency(details.order_stats.average_order_value)}
                    </div>
                </div>
                
                <h3>آخر الطلبات / Recent Orders</h3>
                <table>
                    <thead>
                        <tr>
                            <th>الحالة / Status</th>
                            <th>المبلغ / Amount</th>
                            <th>التاريخ / Date</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${details.recent_orders.map(order => `
                            <tr>
                                <td><span class="badge badge-info">${order.status}</span></td>
                                <td>${formatCurrency(order.total_amount)}</td>
                                <td><small>${new Date(order.created_at).toLocaleDateString('ar-IQ')}</small></td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>
                
                <button class="btn btn-secondary" onclick="closeAllModals()" style="margin-top: 20px;">
                    <i class="fas fa-times"></i> إغلاق / Close
                </button>
            </div>
        `;
        
        openModal('walletModal');
    } catch (error) {
        console.error('View customer details error:', error);
        alert('❌ خطأ / Error');
    }
}

function addCustomerNote(customerId) {
    const note = prompt('أضف ملاحظة عن العميل:\nAdd note about customer:');
    if (!note) return;
    
    const isImportant = confirm('هل هذه ملاحظة مهمة؟\nIs this an important note?');
    
    try {
        supabaseClient
            .rpc('add_customer_note', {
                p_customer_id: customerId,
                p_note: note,
                p_is_important: isImportant
            })
            .then(({ error }) => {
                if (error) throw error;
                alert('✅ تمت إضافة الملاحظة / Note added');
            });
    } catch (error) {
        console.error('Add customer note error:', error);
        alert('❌ خطأ / Error');
    }
}

// =====================================================================================
// SYSTEM-WIDE ANNOUNCEMENTS (SCREEN NOTIFICATIONS)
// =====================================================================================

async function loadAnnouncements() {
    const container = document.getElementById('announcementsTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        const { data: announcements, error } = await supabaseClient
            .from('system_announcements')
            .select('*')
            .order('created_at', { ascending: false });
        
        if (error) throw error;
        
        if (!announcements || announcements.length === 0) {
            container.innerHTML = '<p class="loading">لا توجد إعلانات / No announcements</p>';
            return;
        }
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>العنوان / Title</th>
                        <th>الأدوار / Roles</th>
                        <th>النوع / Type</th>
                        <th>يمكن إغلاقه / Dismissable</th>
                        <th>الحالة / Status</th>
                        <th>الفترة الزمنية / Time Period</th>
                        <th>الإجراءات / Dismissals</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${announcements.map(ann => {
                        const now = new Date();
                        const startTime = ann.start_time ? new Date(ann.start_time) : null;
                        const endTime = ann.end_time ? new Date(ann.end_time) : null;
                        
                        const isCurrentlyActive = ann.is_active && 
                            (!startTime || startTime <= now) &&
                            (!endTime || endTime > now);
                        
                        const typeColors = {
                            'maintenance': 'warning',
                            'event': 'info',
                            'update': 'primary',
                            'info': 'info',
                            'warning': 'danger',
                            'success': 'success'
                        };
                        
                        const typeLabels = {
                            'maintenance': '🔧 صيانة',
                            'event': '🎉 حدث',
                            'update': '📱 تحديث',
                            'info': 'ℹ️ معلومات',
                            'warning': '⚠️ تحذير',
                            'success': '✅ نجاح'
                        };
                        
                        return `
                            <tr>
                                <td><strong>${ann.title}</strong></td>
                                <td><span class="badge badge-info">${ann.target_roles ? ann.target_roles.join(', ') : 'all'}</span></td>
                                <td><span class="badge badge-${typeColors[ann.type] || 'secondary'}">${typeLabels[ann.type] || ann.type}</span></td>
                                <td>${ann.is_dismissable ? '<span class="badge badge-success">✅ نعم</span>' : '<span class="badge badge-danger">❌ لا</span>'}</td>
                                <td>${isCurrentlyActive ? '<span class="badge badge-success">✅ نشط</span>' : '<span class="badge badge-secondary">⏸️ غير نشط</span>'}</td>
                                <td>
                                    <small>${startTime ? startTime.toLocaleDateString('ar-IQ') : 'الآن'}</small><br>
                                    <small>→ ${endTime ? endTime.toLocaleDateString('ar-IQ') : '∞'}</small>
                                </td>
                                <td>
                                    <button class="btn btn-sm btn-info" onclick="viewAnnouncementDismissals('${ann.id}', '${ann.title.replace(/'/g, "\\'")}')">
                                        <i class="fas fa-eye"></i> عرض / View
                                    </button>
                                </td>
                                <td>
                                    <div class="action-buttons">
                                        <button class="btn btn-sm btn-${ann.is_active ? 'danger' : 'success'}" 
                                                onclick="toggleAnnouncement('${ann.id}', ${!ann.is_active})"
                                                title="${ann.is_active ? 'تعطيل' : 'تفعيل'}">
                                            <i class="fas fa-${ann.is_active ? 'stop' : 'play'}"></i>
                                        </button>
                                        <button class="btn btn-sm btn-info" onclick="viewAnnouncementDetails('${ann.id}')">
                                            <i class="fas fa-eye"></i>
                                        </button>
                                        <button class="btn btn-sm btn-danger" onclick="deleteAnnouncement('${ann.id}')">
                                            <i class="fas fa-trash"></i>
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
        console.error('Load announcements error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

function openCreateAnnouncementModal() {
    const modalBody = document.getElementById('walletModalBody');
    modalBody.innerHTML = `
        <form id="createAnnouncementForm" class="form-container">
            <div class="form-group">
                <label>العنوان / Title *</label>
                <input type="text" id="annTitle" class="form-control" required placeholder="مثال: صيانة مجدولة">
            </div>
            
            <div class="form-group">
                <label>الرسالة / Message *</label>
                <textarea id="annMessage" class="form-control" rows="4" required placeholder="أدخل رسالة مفصلة للمستخدمين"></textarea>
            </div>
            
            <div class="form-group">
                <label>النوع / Type *</label>
                <select id="annType" class="form-control" required>
                    <option value="info">ℹ️ معلومات / Info</option>
                    <option value="maintenance">🔧 صيانة / Maintenance</option>
                    <option value="event">🎉 حدث / Event</option>
                    <option value="update">📱 تحديث / Update</option>
                    <option value="warning">⚠️ تحذير / Warning</option>
                    <option value="success">✅ نجاح / Success</option>
                </select>
            </div>
            
            <div class="form-group">
                <label>الأدوار المستهدفة / Target Roles *</label>
                <div style="padding: 10px; background: #f5f5f5; border-radius: 8px;">
                    <label style="display: block; margin-bottom: 8px;">
                        <input type="checkbox" id="role_merchant" value="merchant" checked>
                        <span>التجار / Merchants</span>
                    </label>
                    <label style="display: block; margin-bottom: 8px;">
                        <input type="checkbox" id="role_driver" value="driver" checked>
                        <span>السائقون / Drivers</span>
                    </label>
                    <label style="display: block;">
                        <input type="checkbox" id="role_admin" value="admin">
                        <span>الإداريون / Admins</span>
                    </label>
                </div>
            </div>
            
            <div class="form-group">
                <label>يمكن إغلاقه / Dismissable *</label>
                <select id="annDismissable" class="form-control" required>
                    <option value="true">✅ نعم - يمكن للمستخدمين إغلاقه / Yes - Users can dismiss</option>
                    <option value="false">❌ لا - لا يمكن إغلاقه (مهم جداً) / No - Cannot be dismissed (critical)</option>
                </select>
                <small>إذا كان لا يمكن إغلاقه، سيظهر في كل مرة حتى ينتهي وقته</small>
            </div>
            
            <div class="form-group">
                <label>وقت البدء / Start Time</label>
                <input type="datetime-local" id="annStartTime" class="form-control">
                <small>اتركه فارغاً ليبدأ فوراً / Leave empty to start immediately</small>
            </div>
            
            <div class="form-group">
                <label>وقت الانتهاء / End Time</label>
                <input type="datetime-local" id="annEndTime" class="form-control">
                <small>اتركه فارغاً ليستمر للأبد / Leave empty for indefinite</small>
            </div>
            
            <div class="form-actions">
                <button type="submit" class="btn btn-primary">
                    <i class="fas fa-check"></i> إنشاء الإعلان / Create Announcement
                </button>
                <button type="button" class="btn btn-secondary" onclick="closeAllModals()">
                    <i class="fas fa-times"></i> إلغاء / Cancel
                </button>
            </div>
        </form>
    `;
    
    document.getElementById('createAnnouncementForm').onsubmit = async (e) => {
        e.preventDefault();
        
        const title = document.getElementById('annTitle').value;
        const message = document.getElementById('annMessage').value;
        const type = document.getElementById('annType').value;
        const isDismissable = document.getElementById('annDismissable').value === 'true';
        
        // Get selected roles
        const targetRoles = [];
        if (document.getElementById('role_merchant').checked) targetRoles.push('merchant');
        if (document.getElementById('role_driver').checked) targetRoles.push('driver');
        if (document.getElementById('role_admin').checked) targetRoles.push('admin');
        
        if (targetRoles.length === 0) {
            alert('❌ الرجاء اختيار دور واحد على الأقل / Please select at least one role');
            return;
        }
        
        const startTime = document.getElementById('annStartTime').value ?
            new Date(document.getElementById('annStartTime').value).toISOString() : null;
        const endTime = document.getElementById('annEndTime').value ?
            new Date(document.getElementById('annEndTime').value).toISOString() : null;
        
        try {
            const { data: { user } } = await supabaseClient.auth.getUser();
            
            const { error } = await supabaseClient
                .from('system_announcements')
                .insert({
                    title,
                    message,
                    type,
                    is_dismissable: isDismissable,
                    target_roles: targetRoles,
                    start_time: startTime,
                    end_time: endTime,
                    created_by: user?.id
                });
            
            if (error) throw error;
            
            alert('✅ تم إنشاء الإعلان / Announcement created');
            closeAllModals();
            loadAnnouncements();
        } catch (error) {
            console.error('Create announcement error:', error);
            alert('❌ خطأ / Error: ' + (error.message || ''));
        }
    };
    
    openModal('walletModal');
}

async function toggleAnnouncement(announcementId, isActive) {
    try {
        const { error } = await supabaseClient
            .from('system_announcements')
            .update({ is_active: isActive })
            .eq('id', announcementId);
        
        if (error) throw error;
        
        alert(`✅ ${isActive ? 'تم التفعيل / Activated' : 'تم التعطيل / Deactivated'}`);
        loadAnnouncements();
    } catch (error) {
        console.error('Toggle announcement error:', error);
        alert('❌ خطأ / Error');
    }
}

async function viewAnnouncementDetails(announcementId) {
    try {
        const { data: announcement, error } = await supabaseClient
            .from('system_announcements')
            .select('*')
            .eq('id', announcementId)
            .single();
        
        if (error) throw error;
        
        const startTime = announcement.start_time ? new Date(announcement.start_time).toLocaleString('ar-IQ') : 'فوراً';
        const endTime = announcement.end_time ? new Date(announcement.end_time).toLocaleString('ar-IQ') : 'دون نهاية';
        
        alert(`
📢 تفاصيل الإعلان / Announcement Details

📌 العنوان / Title:
${announcement.title}

📝 الرسالة / Message:
${announcement.message}

🎯 النوع / Type: ${announcement.type}
👥 الأدوار / Roles: ${announcement.target_roles.join(', ')}
✅ يمكن إغلاقه / Dismissable: ${announcement.is_dismissable ? 'نعم' : 'لا'}
🟢 نشط / Active: ${announcement.is_active ? 'نعم' : 'لا'}

⏰ وقت البدء / Start: ${startTime}
⏱️ وقت الانتهاء / End: ${endTime}

📅 تم الإنشاء / Created: ${new Date(announcement.created_at).toLocaleString('ar-IQ')}
        `);
    } catch (error) {
        console.error('View announcement error:', error);
        alert('❌ خطأ / Error');
    }
}

async function deleteAnnouncement(announcementId) {
    if (!confirm('⚠️ هل أنت متأكد من حذف هذا الإعلان؟ / Are you sure you want to delete this announcement?')) {
        return;
    }
    
    try {
        const { error } = await supabaseClient
            .from('system_announcements')
            .delete()
            .eq('id', announcementId);
        
        if (error) throw error;
        
        alert('✅ تم الحذف / Deleted');
        loadAnnouncements();
    } catch (error) {
        console.error('Delete announcement error:', error);
        alert('❌ خطأ / Error');
    }
}

async function viewAnnouncementDismissals(announcementId, title) {
    try {
        const { data: dismissals, error } = await supabaseClient
            .from('announcement_dismissals')
            .select(`
                *,
                users:user_id (
                    name,
                    phone,
                    role
                )
            `)
            .eq('announcement_id', announcementId)
            .order('dismissed_at', { ascending: false });
        
        if (error) throw error;
        
        const modalBody = document.getElementById('walletModalBody');
        
        if (!dismissals || dismissals.length === 0) {
            modalBody.innerHTML = `
                <div class="card">
                    <h3>إجراءات الإعلان / Announcement Dismissals</h3>
                    <p><strong>${title}</strong></p>
                    <p class="loading">لم يقم أحد بإغلاق هذا الإعلان بعد / No dismissals yet</p>
                </div>
            `;
        } else {
            modalBody.innerHTML = `
                <div class="card">
                    <h3>إجراءات الإعلان / Announcement Dismissals</h3>
                    <p><strong>${title}</strong></p>
                    <p>إجمالي الإغلاقات / Total Dismissals: <strong>${dismissals.length}</strong></p>
                    <table>
                        <thead>
                            <tr>
                                <th>المستخدم / User</th>
                                <th>الدور / Role</th>
                                <th>رقم الهاتف / Phone</th>
                                <th>وقت الإغلاق / Dismissed At</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${dismissals.map(d => `
                                <tr>
                                    <td>${d.users?.name || 'غير معروف'}</td>
                                    <td><span class="badge badge-info">${d.users?.role || '-'}</span></td>
                                    <td>${d.users?.phone || '-'}</td>
                                    <td>${new Date(d.dismissed_at).toLocaleString('ar-IQ')}</td>
                                </tr>
                            `).join('')}
                        </tbody>
                    </table>
                </div>
            `;
        }
        
        openModal('walletModal');
    } catch (error) {
        console.error('View dismissals error:', error);
        alert('❌ خطأ / Error');
    }
}

// =====================================================================================
// DRIVER PERFORMANCE
// =====================================================================================

async function loadPerformance() {
    const container = document.getElementById('topDriversTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        const { data: topDrivers, error } = await supabaseClient
            .rpc('get_top_drivers', { p_limit: 20, p_days: 30 });
        
        if (error) throw error;
        
        if (!topDrivers || topDrivers.length === 0) {
            container.innerHTML = '<p class="loading">لا توجد بيانات / No data</p>';
            return;
        }
        
        const table = `
            <h3>🏆 أفضل السائقين / Top Drivers (آخر 30 يوم / Last 30 Days)</h3>
            <table>
                <thead>
                    <tr>
                        <th>المرتبة / Rank</th>
                        <th>السائق / Driver</th>
                        <th>الطلبات المكتملة / Completed Orders</th>
                        <th>الأرباح / Earnings</th>
                        <th>متوسط التقييم / Avg Rating</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${topDrivers.map((driver, index) => {
                        const medal = index === 0 ? '🥇' : index === 1 ? '🥈' : index === 2 ? '🥉' : '';
                        return `
                            <tr>
                                <td><strong style="font-size: 1.5em;">${medal} ${index + 1}</strong></td>
                                <td>
                                    <strong>${driver.driver_name}</strong><br>
                                    <small>${driver.driver_phone}</small>
                                </td>
                                <td><span class="badge badge-success">${driver.completed_orders}</span></td>
                                <td style="color: var(--success)"><strong>${formatCurrency(driver.total_earnings)}</strong></td>
                                <td>
                                    ${'⭐'.repeat(Math.round(driver.average_rating))}<br>
                                    <small>${driver.average_rating.toFixed(2)}/5.00</small>
                                </td>
                                <td>
                                    <button class="btn btn-sm btn-primary" onclick="viewDriverPerformance('${driver.driver_id}')">
                                        <i class="fas fa-chart-line"></i> التفاصيل / Details
                                    </button>
                                </td>
                            </tr>
                        `;
                    }).join('')}
                </tbody>
            </table>
        `;
        
        container.innerHTML = table;
        
    } catch (error) {
        console.error('Load performance error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

async function viewDriverPerformance(driverId) {
    const container = document.getElementById('driverPerformanceDetails');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        const { data: performance, error } = await supabaseClient
            .rpc('get_driver_performance', { p_driver_id: driverId, p_days: 30 });
        
        if (error) throw error;
        
        container.innerHTML = `
            <div class="cards-grid">
                <div class="info-box" style="background: #EFF6FF;">
                    <i class="fas fa-box"></i>
                    <div>
                        <strong>الطلبات الكلية / Total Orders</strong>
                        <h3>${performance.total_orders}</h3>
                    </div>
                </div>
                
                <div class="info-box" style="background: #F0FDF4;">
                    <i class="fas fa-check-circle"></i>
                    <div>
                        <strong>المكتملة / Completed</strong>
                        <h3>${performance.completed_orders}</h3>
                    </div>
                </div>
                
                <div class="info-box" style="background: #FEF3C7;">
                    <i class="fas fa-percentage"></i>
                    <div>
                        <strong>معدل القبول / Acceptance Rate</strong>
                        <h3>${performance.acceptance_rate}%</h3>
                    </div>
                </div>
                
                <div class="info-box" style="background: #FEE2E2;">
                    <i class="fas fa-times-circle"></i>
                    <div>
                        <strong>الملغية / Cancelled</strong>
                        <h3>${performance.cancelled_orders}</h3>
                    </div>
                </div>
                
                <div class="info-box" style="background: #F3E8FF;">
                    <i class="fas fa-dollar-sign"></i>
                    <div>
                        <strong>الأرباح / Earnings</strong>
                        <h3>${formatCurrency(performance.total_earnings)}</h3>
                    </div>
                </div>
                
                <div class="info-box" style="background: #FFEDD5;">
                    <i class="fas fa-star"></i>
                    <div>
                        <strong>متوسط التقييم / Avg Rating</strong>
                        <h3>${performance.average_rating.toFixed(2)}/5.00</h3>
                    </div>
                </div>
            </div>
        `;
        
    } catch (error) {
        console.error('View driver performance error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

// =====================================================================================
// SYSTEM CONFIGURATION
// =====================================================================================

async function loadSystemConfig() {
    const container = document.getElementById('systemConfigTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        const { data: configs, error } = await supabaseClient
            .rpc('get_app_configs');
        
        if (error) throw error;
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>المفتاح / Key</th>
                        <th>القيمة / Value</th>
                        <th>النوع / Type</th>
                        <th>الوصف / Description</th>
                        <th>عام؟ / Public?</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${configs.map(config => `
                        <tr>
                            <td><code>${config.config_key}</code></td>
                            <td><strong>${config.config_value}</strong></td>
                            <td><span class="badge badge-secondary">${config.value_type}</span></td>
                            <td><small>${config.description || 'لا يوجد'}</small></td>
                            <td>${config.is_public ? '✅' : '❌'}</td>
                            <td>
                                <button class="btn btn-sm btn-warning" onclick="editConfig('${config.config_key}', '${config.config_value}', '${config.value_type}')">
                                    <i class="fas fa-edit"></i> تعديل / Edit
                                </button>
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;
        
        container.innerHTML = table;
        
    } catch (error) {
        console.error('Load system config error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

function editConfig(key, currentValue, valueType) {
    let newValue;
    
    if (valueType === 'boolean') {
        newValue = confirm(`القيمة الحالية: ${currentValue}\n\nتعيين إلى true؟\nSet to true?`) ? 'true' : 'false';
    } else {
        newValue = prompt(`تعديل ${key}\nEdit ${key}:\n\nالقيمة الحالية / Current: ${currentValue}`, currentValue);
        if (!newValue) return;
    }
    
    if (valueType === 'number' && isNaN(newValue)) {
        alert('❌ يجب أن تكون القيمة رقماً / Value must be a number');
        return;
    }
    
    if (!confirm(`تأكيد التغيير؟\nConfirm change?\n\n${key}: ${currentValue} → ${newValue}`)) {
        return;
    }
    
    try {
        supabaseClient
            .rpc('update_app_config', {
                p_config_key: key,
                p_config_value: newValue
            })
            .then(({ data, error }) => {
                if (error) throw error;
                if (data) {
                    alert('✅ تم التحديث / Updated successfully');
                    loadSystemConfig();
                } else {
                    alert('❌ فشل التحديث / Update failed');
                }
            });
    } catch (error) {
        console.error('Update config error:', error);
        alert('❌ خطأ / Error');
    }
}

// =====================================================================================
// EXPORT FUNCTIONS TO WINDOW
// =====================================================================================

window.loadFinancialDashboard = loadFinancialDashboard;
window.loadReviews = loadReviews;
window.flagReview = flagReview;
window.loadPromoCodes = loadPromoCodes;
window.openCreatePromoModal = openCreatePromoModal;
window.togglePromoCode = togglePromoCode;
window.loadDeliveryZones = loadDeliveryZones;
window.openCreateZoneModal = openCreateZoneModal;
window.editZone = editZone;
window.toggleZone = toggleZone;
window.loadBlacklist = loadBlacklist;
window.openAddBlacklistModal = openAddBlacklistModal;
window.removeFromBlacklist = removeFromBlacklist;
window.loadDisputes = loadDisputes;
window.viewDispute = viewDispute;
window.loadCustomers = loadCustomers;
window.viewCustomerDetails = viewCustomerDetails;
window.addCustomerNote = addCustomerNote;
window.loadAnnouncements = loadAnnouncements;
window.openCreateAnnouncementModal = openCreateAnnouncementModal;
window.toggleAnnouncement = toggleAnnouncement;
window.viewAnnouncementDetails = viewAnnouncementDetails;
window.deleteAnnouncement = deleteAnnouncement;
window.viewAnnouncementDismissals = viewAnnouncementDismissals;
window.loadPerformance = loadPerformance;
window.viewDriverPerformance = viewDriverPerformance;
window.loadSystemConfig = loadSystemConfig;
window.editConfig = editConfig;

// =====================================================================================
// END OF FILE
// =====================================================================================

