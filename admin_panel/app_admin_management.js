/**
 * Admin User Management & FCM Notifications
 * Create admins and send FCM notifications
 */

// =====================================================================================
// CREATE ADMIN USER
// =====================================================================================

function openCreateAdminModal() {
    const modalBody = document.getElementById('orderActionModalBody');
    modalBody.innerHTML = `
        <h3>إنشاء مدير جديد / Create New Admin</h3>
        <p class="info-box">
            <i class="fas fa-info-circle"></i>
            سيتم إنشاء حساب مدير جديد بصلاحيات كاملة
            <br>
            A new admin account with full permissions will be created
        </p>
        
        <form id="createAdminForm" onsubmit="return false;">
            <div class="form-grid">
                <div class="form-group">
                    <label>الاسم / Name *</label>
                    <input type="text" id="adminName" required placeholder="Admin Name" />
                </div>
                
                <div class="form-group">
                    <label>البريد الإلكتروني / Email *</label>
                    <input type="email" id="adminEmail" required placeholder="admin@company.com" />
                </div>
                
                <div class="form-group">
                    <label>رقم الهاتف / Phone *</label>
                    <input type="tel" id="adminPhone" required placeholder="9647XXXXXXXX" pattern="^964[0-9]{10}$" />
                </div>
                
                <div class="form-group">
                    <label>كلمة المرور / Password *</label>
                    <input type="password" id="adminPassword" required minlength="8" placeholder="••••••••" />
                </div>
            </div>
            
            <div class="warning-box">
                <i class="fas fa-shield-alt"></i>
                <p>⚠️ سيحصل المدير الجديد على صلاحيات كاملة<br>New admin will have full permissions</p>
            </div>
            
            <button type="button" class="btn btn-success" onclick="createAdminUser()">
                <i class="fas fa-user-shield"></i> إنشاء المدير / Create Admin
            </button>
        </form>
    `;
    
    openModal('orderActionModal');
}

async function createAdminUser() {
    const name = document.getElementById('adminName')?.value;
    const email = document.getElementById('adminEmail')?.value;
    const phone = document.getElementById('adminPhone')?.value;
    const password = document.getElementById('adminPassword')?.value;
    
    if (!name || !email || !phone || !password) {
        alert('⚠️ يرجى ملء جميع الحقول / Please fill all fields');
        return;
    }
    
    if (password.length < 8) {
        alert('⚠️ كلمة المرور يجب أن تكون 8 أحرف على الأقل / Password must be at least 8 characters');
        return;
    }
    
    if (!confirm(`إنشاء مدير جديد: ${name}؟\nCreate new admin: ${name}?`)) return;
    
    try {
        // Step 1: Create user in Supabase Auth
        const { data: authData, error: authError } = await supabaseClient.auth.admin.createUser({
            email: email,
            password: password,
            email_confirm: true,
            user_metadata: {
                name: name,
                phone: phone,
                role: 'admin'
            }
        });
        
        if (authError) throw authError;
        
        const userId = authData.user.id;
        
        // Step 2: Add to users table with admin role
        const { data: userData, error: userError } = await supabaseClient
            .rpc('admin_create_admin_user', {
                p_user_id: userId,
                p_name: name,
                p_phone: phone,
                p_email: email,
                p_creator_admin_id: currentUser.id
            });
        
        if (userError) throw userError;
        
        if (userData.success) {
            alert(`✅ ${userData.message}\n\nEmail: ${email}\nPassword: ${password}\n\n⚠️ يرجى حفظ كلمة المرور / Please save the password!`);
            closeAllModals();
            loadUsers();
        } else {
            // Rollback: delete auth user if database insert failed
            await supabaseClient.auth.admin.deleteUser(userId);
            alert('❌ ' + userData.message);
        }
    } catch (error) {
        console.error('Create admin error:', error);
        alert('❌ خطأ / Error: ' + error.message);
    }
}

// =====================================================================================
// PROMOTE USER TO ADMIN
// =====================================================================================

async function promoteToAdmin(userId, userName) {
    if (!confirm(`⚠️ ترقية ${userName} إلى مدير؟\nPromote ${userName} to admin?\n\nسيحصل على صلاحيات كاملة / Will get full permissions`)) return;
    
    try {
        const { data, error } = await supabaseClient
            .rpc('admin_update_user_role', {
                p_user_id: userId,
                p_new_role: 'admin',
                p_admin_id: currentUser.id
            });
        
        if (error) throw error;
        
        if (data.success) {
            alert('✅ ' + data.message);
            loadUsers();
        } else {
            alert('❌ ' + data.message);
        }
    } catch (error) {
        console.error('Promote to admin error:', error);
        alert('❌ خطأ / Error: ' + error.message);
    }
}

// =====================================================================================
// FUNCTIONAL FCM NOTIFICATIONS
// =====================================================================================

async function handleSendNotification(e) {
    e.preventDefault();
    
    const recipient = document.getElementById('notifRecipient').value;
    const title = document.getElementById('notifTitle').value;
    const body = document.getElementById('notifBody').value;
    
    if (!title || !body) {
        alert('⚠️ يرجى ملء جميع الحقول / Please fill all fields');
        return;
    }
    
    try {
        // Get target users
        let targetUsers = [];
        if (recipient === 'all') {
            const { data } = await supabaseClient.from('users').select('id');
            targetUsers = data.map(u => u.id);
        } else {
            // merchants -> merchant, drivers -> driver, customers -> customer
            const role = recipient.replace('s', '');
            const { data } = await supabaseClient
                .from('users')
                .select('id')
                .eq('role', role);
            targetUsers = data.map(u => u.id);
        }
        
        if (targetUsers.length === 0) {
            alert('⚠️ لا يوجد مستخدمون في هذه الفئة / No users in this category');
            return;
        }
        
        if (!confirm(`إرسال ${targetUsers.length} إشعار؟\nSend ${targetUsers.length} notifications?`)) return;
        
        // Show progress
        const progressDiv = document.createElement('div');
        progressDiv.className = 'progress-box';
        progressDiv.innerHTML = `
            <p>جاري الإرسال... / Sending...</p>
            <div class="progress-bar">
                <div class="progress-fill" id="notifProgress"></div>
            </div>
            <p id="notifProgressText">0 / ${targetUsers.length}</p>
        `;
        document.getElementById('notificationForm').appendChild(progressDiv);
        
        // Send notifications to database ONLY
        // The database trigger will automatically call the edge function for FCM
        const notifications = targetUsers.map(userId => ({
            user_id: userId,
            title: title,
            body: body,
            type: 'system',
            is_read: false,
            data: { sent_by: 'admin', admin_id: currentUser.id }
        }));
        
        // Update progress to show inserting
        document.getElementById('notifProgress').style.width = '50%';
        document.getElementById('notifProgressText').textContent = `إدراج ${targetUsers.length} إشعار / Inserting ${targetUsers.length} notifications...`;
        
        // Insert into database (trigger will handle FCM automatically)
        const { error: dbError } = await supabaseClient
            .from('notifications')
            .insert(notifications);
        
        if (dbError) throw dbError;
        
        // Update progress to complete
        document.getElementById('notifProgress').style.width = '100%';
        document.getElementById('notifProgressText').textContent = `✅ ${targetUsers.length} إشعار / ${targetUsers.length} notifications`;
        
        // Show success message
        setTimeout(() => {
            progressDiv.remove();
            alert(`✅ تم إرسال ${targetUsers.length} إشعار بنجاح!\nSuccessfully sent ${targetUsers.length} notifications!\n\n📱 سيتم إرسال الإشعارات الفورية تلقائياً عبر FCM\n📱 Push notifications will be sent automatically via FCM trigger`);
            closeAllModals();
            document.getElementById('notificationForm').reset();
        }, 500);
        
    } catch (error) {
        console.error('Send notification error:', error);
        alert('❌ خطأ / Error: ' + error.message);
    }
}

// =====================================================================================
// SEND SINGLE FCM NOTIFICATION (Helper)
// =====================================================================================
// NOTE: This function is no longer used for bulk notifications
// Database triggers now handle FCM automatically when notifications are inserted
// Kept here for potential future direct FCM calls if needed

async function sendSingleFCMNotification(userId, title, body, data = {}) {
    try {
        const response = await fetch(`${CONFIG.SUPABASE_URL}/functions/v1/send-push-notification`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${CONFIG.SUPABASE_ANON_KEY}`
            },
            body: JSON.stringify({
                user_id: userId,
                title: title,
                body: body,
                data: data
            })
        });
        
        const result = await response.json();
        
        if (response.ok) {
            console.log('✅ FCM sent to user:', userId);
            return { success: true, result };
        } else {
            console.warn('⚠️ FCM failed for user:', userId, result);
            return { success: false, error: result };
        }
    } catch (error) {
        console.error('FCM error:', error);
        return { success: false, error: error.message };
    }
}

// Export to global scope
window.openCreateAdminModal = openCreateAdminModal;
window.createAdminUser = createAdminUser;
window.promoteToAdmin = promoteToAdmin;
window.handleSendNotification = handleSendNotification;
window.sendSingleFCMNotification = sendSingleFCMNotification;
