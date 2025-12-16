/**
 * Verification Page and Mapbox Tracking - Additional Functions
 * Add this to app.js or include it separately
 */

// =====================================================================================
// VERIFICATION PAGE - For Pending User Verifications
// =====================================================================================

async function loadVerification() {
    const roleFilter = document.getElementById('verificationRoleFilter')?.value;
    const container = document.getElementById('verificationTable');
    container.innerHTML = '<p class="loading">جاري التحميل...</p>';
    
    try {
        let query = supabaseClient
            .from('users')
            .select('*')
            .eq('manual_verified', false)
            .order('created_at', { ascending: false });
        
        if (roleFilter) {
            query = query.eq('role', roleFilter);
        }
        
        const { data: users, error } = await query;
        
        if (error) throw error;
        
        if (!users || users.length === 0) {
            container.innerHTML = '<p class="loading">لا توجد مستخدمين معلقين / No pending users</p>';
            return;
        }
        
        const table = `
            <table>
                <thead>
                    <tr>
                        <th>الاسم / Name</th>
                        <th>الهاتف / Phone</th>
                        <th>الدور / Role</th>
                        <th>تاريخ التسجيل / Registered</th>
                        <th>المستندات / Documents</th>
                        <th>إجراءات / Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${users.map(user => `
                        <tr>
                            <td>${user.name}</td>
                            <td>${user.phone}</td>
                            <td><span class="badge badge-info">${user.role}</span></td>
                            <td>${formatDate(user.created_at)}</td>
                            <td>
                                ${user.id_card_front_url || user.id_card_back_url || user.selfie_with_id_url ? 
                                    '<span class="badge badge-success"><i class="fas fa-check"></i> متوفرة / Available</span>' : 
                                    '<span class="badge badge-warning"><i class="fas fa-times"></i> غير متوفرة / Missing</span>'
                                }
                            </td>
                            <td>
                                <div class="action-buttons">
                                    <button class="btn btn-sm btn-info" onclick="viewVerificationDetails('${user.id}')">
                                        <i class="fas fa-eye"></i> عرض / View
                                    </button>
                                    <button class="btn btn-sm btn-success" onclick="approveUser('${user.id}')">
                                        <i class="fas fa-check"></i> قبول / Approve
                                    </button>
                                    <button class="btn btn-sm btn-danger" onclick="rejectUser('${user.id}')">
                                        <i class="fas fa-times"></i> رفض / Reject
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
        console.error('Load verification error:', error);
        container.innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

async function viewVerificationDetails(userId) {
    try {
        const { data: user, error } = await supabaseClient
            .from('users')
            .select('*')
            .eq('id', userId)
            .single();
        
        if (error) throw error;
        
        const modalBody = document.getElementById('verificationModalBody');
        
        // Smart path handling - works with URL, path, or filename
        const getImageUrl = async (value) => {
            if (!value) return null;
            
            console.log('🔍 Processing image value:', value);
            
            // Case 1: Already a full URL (from Flutter app's getPublicUrl)
            if (value.startsWith('http://') || value.startsWith('https://')) {
                console.log('✅ Already a full URL, using directly:', value);
                return value;
            }
            
            // Case 2: Full storage path (documents/userId/filename)
            if (value.startsWith('documents/')) {
                console.log('📁 Full path, getting URL from storage:', value);
                return await getStorageUrl(value);
            }
            
            // Case 3: Just filename - construct full path
            const fullPath = `documents/${userId}/${value}`;
            console.log('🔨 Constructed path from filename:', fullPath);
            return await getStorageUrl(fullPath);
        };
        
        // Get URLs for all documents
        const idFrontUrl = await getImageUrl(user.id_card_front_url);
        const idBackUrl = await getImageUrl(user.id_card_back_url);
        const selfieUrl = await getImageUrl(user.selfie_with_id_url);
        
        console.log('📄 Final URLs:', { idFrontUrl, idBackUrl, selfieUrl });
        
        modalBody.innerHTML = `
            <div class="verification-details">
                <div class="details-section">
                    <h3>معلومات المستخدم / User Information</h3>
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
                        ${user.store_name ? `
                            <div class="details-item">
                                <div class="details-label">اسم المتجر / Store Name:</div>
                                <div class="details-value">${user.store_name}</div>
                            </div>
                        ` : ''}
                        ${user.vehicle_type ? `
                            <div class="details-item">
                                <div class="details-label">نوع المركبة / Vehicle Type:</div>
                                <div class="details-value">${user.vehicle_type}</div>
                            </div>
                        ` : ''}
                        ${user.vehicle_plate ? `
                            <div class="details-item">
                                <div class="details-label">لوحة المركبة / Vehicle Plate:</div>
                                <div class="details-value">${user.vehicle_plate}</div>
                            </div>
                        ` : ''}
                        <div class="details-item">
                            <div class="details-label">العنوان / Address:</div>
                            <div class="details-value">${user.address || 'N/A'}</div>
                        </div>
                        <div class="details-item">
                            <div class="details-label">تاريخ التسجيل / Registered:</div>
                            <div class="details-value">${formatDate(user.created_at)}</div>
                        </div>
                    </div>
                </div>

                <div class="details-section">
                    <h3>المستندات المرفوعة / Uploaded Documents</h3>
                    <div class="documents-grid">
                        ${idFrontUrl ? `
                            <div class="document-card">
                                <h4>البطاقة الأمامية / ID Card Front</h4>
                                <img src="${idFrontUrl}" 
                                     alt="ID Front" 
                                     class="document-image" 
                                     onclick="window.open('${idFrontUrl}', '_blank')"
                                     onerror="this.onerror=null; this.src='data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%22200%22 height=%22150%22%3E%3Crect fill=%22%23ddd%22 width=%22200%22 height=%22150%22/%3E%3Ctext x=%2250%25%22 y=%2250%25%22 fill=%22%23999%22 text-anchor=%22middle%22 dy=%22.3em%22%3EImage Error%3C/text%3E%3C/svg%3E'; this.style.cursor='not-allowed';">
                                <button class="btn btn-sm btn-info" onclick="window.open('${idFrontUrl}', '_blank')">
                                    <i class="fas fa-external-link-alt"></i> فتح / Open
                                </button>
                                <small style="display:block; margin-top:5px; color:#6B7280; font-size:11px;">✅ Loaded</small>
                            </div>
                        ` : `<div class="missing-doc-card">
                                <i class="fas fa-image" style="font-size:40px; color:#9CA3AF; margin-bottom:10px;"></i>
                                <p>البطاقة الأمامية غير متوفرة<br>ID Front not available</p>
                            </div>`}
                        
                        ${idBackUrl ? `
                            <div class="document-card">
                                <h4>البطاقة الخلفية / ID Card Back</h4>
                                <img src="${idBackUrl}" 
                                     alt="ID Back" 
                                     class="document-image" 
                                     onclick="window.open('${idBackUrl}', '_blank')"
                                     onerror="this.onerror=null; this.src='data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%22200%22 height=%22150%22%3E%3Crect fill=%22%23ddd%22 width=%22200%22 height=%22150%22/%3E%3Ctext x=%2250%25%22 y=%2250%25%22 fill=%22%23999%22 text-anchor=%22middle%22 dy=%22.3em%22%3EImage Error%3C/text%3E%3C/svg%3E'; this.style.cursor='not-allowed';">
                                <button class="btn btn-sm btn-info" onclick="window.open('${idBackUrl}', '_blank')">
                                    <i class="fas fa-external-link-alt"></i> فتح / Open
                                </button>
                                <small style="display:block; margin-top:5px; color:#6B7280; font-size:11px;">✅ Loaded</small>
                            </div>
                        ` : `<div class="missing-doc-card">
                                <i class="fas fa-image" style="font-size:40px; color:#9CA3AF; margin-bottom:10px;"></i>
                                <p>البطاقة الخلفية غير متوفرة<br>ID Back not available</p>
                            </div>`}
                        
                        ${selfieUrl ? `
                            <div class="document-card">
                                <h4>صورة شخصية / Selfie with ID</h4>
                                <img src="${selfieUrl}" 
                                     alt="Selfie" 
                                     class="document-image" 
                                     onclick="window.open('${selfieUrl}', '_blank')"
                                     onerror="this.onerror=null; this.src='data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%22200%22 height=%22150%22%3E%3Crect fill=%22%23ddd%22 width=%22200%22 height=%22150%22/%3E%3Ctext x=%2250%25%22 y=%2250%25%22 fill=%22%23999%22 text-anchor=%22middle%22 dy=%22.3em%22%3EImage Error%3C/text%3E%3C/svg%3E'; this.style.cursor='not-allowed';">
                                <button class="btn btn-sm btn-info" onclick="window.open('${selfieUrl}', '_blank')">
                                    <i class="fas fa-external-link-alt"></i> فتح / Open
                                </button>
                                <small style="display:block; margin-top:5px; color:#6B7280; font-size:11px;">✅ Loaded</small>
                            </div>
                        ` : `<div class="missing-doc-card">
                                <i class="fas fa-image" style="font-size:40px; color:#9CA3AF; margin-bottom:10px;"></i>
                                <p>الصورة الشخصية غير متوفرة<br>Selfie not available</p>
                            </div>`}
                    </div>
                </div>

                <div class="verification-actions">
                    <button class="btn btn-success" onclick="approveUser('${user.id}')">
                        <i class="fas fa-check"></i> قبول المستخدم / Approve User
                    </button>
                    <button class="btn btn-danger" onclick="rejectUser('${user.id}')">
                        <i class="fas fa-times"></i> رفض المستخدم / Reject User
                    </button>
                </div>
            </div>
        `;
        
        openModal('verificationModal');
    } catch (error) {
        console.error('View verification error:', error);
        alert('خطأ / Error: ' + error.message);
    }
}

async function getStorageUrl(path) {
    try {
        if (!path) {
            console.warn('⚠️ getStorageUrl called with empty path');
            return null;
        }
        
        console.log('🔍 Getting storage URL for path:', path);
        
        // Clean the path - remove any leading slashes or bucket name
        let cleanPath = path;
        if (cleanPath.startsWith('/')) {
            cleanPath = cleanPath.substring(1);
        }
        if (cleanPath.startsWith('files/')) {
            cleanPath = cleanPath.substring(6);
        }
        
        console.log('🔍 Clean path:', cleanPath);
        
        // Since bucket is public, try getPublicUrl first (faster, no expiry)
        const { data: publicData } = supabaseClient
            .storage
            .from('files')
            .getPublicUrl(cleanPath);
        
        if (publicData && publicData.publicUrl) {
            console.log('✅ Got public URL:', publicData.publicUrl);
            return publicData.publicUrl;
        }
        
        // Fallback: Try signed URL (for private buckets)
        console.log('🔄 Trying signed URL...');
        const { data: signedData, error } = await supabaseClient
            .storage
            .from('files')
            .createSignedUrl(cleanPath, 3600); // 1 hour expiry
        
        if (error) {
            console.error('❌ Storage URL error:', {
                path: cleanPath,
                error: error,
                message: error.message
            });
            return null;
        }
        
        if (signedData && signedData.signedUrl) {
            console.log('✅ Got signed URL:', signedData.signedUrl);
            return signedData.signedUrl;
        }
        
        console.warn('⚠️ No URL available for path:', cleanPath);
        return null;
    } catch (error) {
        console.error('❌ Get storage URL exception:', error);
        return null;
    }
}

async function approveUser(userId) {
    if (!confirm('هل أنت متأكد من قبول هذا المستخدم؟ / Are you sure you want to approve this user?')) return;
    
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
        
        alert('✅ تم قبول المستخدم بنجاح / User approved successfully');
        closeAllModals();
        loadVerification();
    } catch (error) {
        console.error('Approve user error:', error);
        alert('❌ خطأ / Error: ' + error.message);
    }
}

async function rejectUser(userId) {
    const reason = prompt('سبب الرفض / Rejection reason:');
    if (!reason) return;
    
    if (!confirm('هل أنت متأكد من رفض هذا المستخدم؟ سيتم حذف حسابه. / Are you sure? This will delete the user account.')) return;
    
    try {
        // Optionally: Add rejection reason to verification_notes before deleting
        await supabaseClient
            .from('users')
            .update({ verification_notes: 'Rejected: ' + reason })
            .eq('id', userId);
        
        // Delete the user
        const { error } = await supabaseClient
            .from('users')
            .delete()
            .eq('id', userId);
        
        if (error) throw error;
        
        alert('✅ تم رفض وحذف المستخدم / User rejected and deleted');
        closeAllModals();
        loadVerification();
    } catch (error) {
        console.error('Reject user error:', error);
        alert('❌ خطأ / Error: ' + error.message);
    }
}

// =====================================================================================
// MAPBOX LIVE TRACKING - Replace Google Maps with Mapbox
// =====================================================================================

let trackingMap = null;
let driverMarkers = {};

async function loadTracking() {
    try {
        // Initialize map if not already initialized
        if (!trackingMap) {
            initializeMapboxTracking();
        }
        
        // Load drivers
        const { data: drivers, error } = await supabaseClient
            .from('users')
            .select('id, name, phone, latitude, longitude, is_online')
            .eq('role', 'driver')
            .eq('is_online', true)
            .not('latitude', 'is', null)
            .not('longitude', 'is', null);
        
        if (error) throw error;
        
        // Update count
        document.getElementById('onlineDriversCount').textContent = drivers?.length || 0;
        
        // Clear existing markers
        Object.values(driverMarkers).forEach(marker => marker.remove());
        driverMarkers = {};
        
        if (!drivers || drivers.length === 0) {
            document.getElementById('driversListContent').innerHTML = '<p class="loading">لا يوجد سائقون متصلون / No online drivers</p>';
            return;
        }
        
        // Add markers for each driver
        const bounds = new mapboxgl.LngLatBounds();
        
        drivers.forEach(driver => {
            addMapboxDriverMarker(driver);
            bounds.extend([driver.longitude, driver.latitude]);
        });
        
        // Fit map to show all drivers
        if (drivers.length > 0) {
            trackingMap.fitBounds(bounds, { padding: 50 });
        }
        
        // Update drivers list sidebar
        updateDriversList(drivers);
        
    } catch (error) {
        console.error('Load tracking error:', error);
        document.getElementById('driversListContent').innerHTML = '<p class="error-message active">خطأ في تحميل البيانات / Error loading data</p>';
    }
}

function initializeMapboxTracking() {
    if (!CONFIG.MAPBOX_ACCESS_TOKEN || CONFIG.MAPBOX_ACCESS_TOKEN === 'YOUR_MAPBOX_ACCESS_TOKEN_HERE') {
        document.getElementById('map').innerHTML = '<div style="padding: 40px; text-align: center;"><p>⚠️ يرجى إضافة Mapbox Access Token في config.js<br>Please add Mapbox Access Token in config.js</p></div>';
        return;
    }
    
    mapboxgl.accessToken = CONFIG.MAPBOX_ACCESS_TOKEN;
    
    trackingMap = new mapboxgl.Map({
        container: 'map',
        style: 'mapbox://styles/mapbox/streets-v12',
        center: [CONFIG.DEFAULT_LONGITUDE, CONFIG.DEFAULT_LATITUDE],
        zoom: 11
    });
    
    // Add navigation controls
    trackingMap.addControl(new mapboxgl.NavigationControl());
    trackingMap.addControl(new mapboxgl.FullscreenControl());
    
    // Center map button
    document.getElementById('centerMap')?.addEventListener('click', () => {
        if (Object.keys(driverMarkers).length > 0) {
            const bounds = new mapboxgl.LngLatBounds();
            Object.values(driverMarkers).forEach(marker => {
                bounds.extend(marker.getLngLat());
            });
            trackingMap.fitBounds(bounds, { padding: 50 });
        } else {
            trackingMap.setCenter([CONFIG.DEFAULT_LONGITUDE, CONFIG.DEFAULT_LATITUDE]);
            trackingMap.setZoom(11);
        }
    });
}

function addMapboxDriverMarker(driver) {
    // Create custom marker element
    const el = document.createElement('div');
    el.className = 'driver-marker';
    el.innerHTML = '<i class="fas fa-motorcycle"></i>';
    el.style.cssText = `
        background-color: #10B981;
        color: white;
        width: 40px;
        height: 40px;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 20px;
        cursor: pointer;
        border: 3px solid white;
        box-shadow: 0 2px 8px rgba(0,0,0,0.3);
    `;
    
    // Create popup
    const popup = new mapboxgl.Popup({ offset: 25 })
        .setHTML(`
            <div style="padding: 10px; min-width: 200px;">
                <h3 style="margin: 0 0 10px 0; color: #1E40AF;">
                    <i class="fas fa-motorcycle"></i> ${driver.name}
                </h3>
                <p style="margin: 5px 0;"><i class="fas fa-phone"></i> ${driver.phone}</p>
                <p style="margin: 5px 0; color: #10B981;"><i class="fas fa-circle"></i> متصل / Online</p>
                <p style="margin: 5px 0; font-size: 12px; color: #6B7280;">
                    <i class="fas fa-map-marker-alt"></i> ${driver.latitude.toFixed(6)}, ${driver.longitude.toFixed(6)}
                </p>
            </div>
        `);
    
    // Create marker
    const marker = new mapboxgl.Marker(el)
        .setLngLat([driver.longitude, driver.latitude])
        .setPopup(popup)
        .addTo(trackingMap);
    
    driverMarkers[driver.id] = marker;
}

function updateDriversList(drivers) {
    const container = document.getElementById('driversListContent');
    
    if (!drivers || drivers.length === 0) {
        container.innerHTML = '<p class="loading">لا يوجد سائقون / No drivers</p>';
        return;
    }
    
    const list = drivers.map(driver => `
        <div class="driver-list-item" onclick="focusDriverOnMapbox('${driver.id}')">
            <div class="driver-avatar">
                <i class="fas fa-motorcycle"></i>
            </div>
            <div class="driver-info">
                <h4>${driver.name}</h4>
                <p><i class="fas fa-phone"></i> ${driver.phone}</p>
                <p class="status-online"><i class="fas fa-circle"></i> متصل / Online</p>
            </div>
        </div>
    `).join('');
    
    container.innerHTML = list;
}

function focusDriverOnMapbox(driverId) {
    const marker = driverMarkers[driverId];
    
    if (marker) {
        // Center map on driver
        trackingMap.flyTo({
            center: marker.getLngLat(),
            zoom: 15,
            essential: true
        });
        
        // Show popup
        marker.togglePopup();
    }
}

// Export functions to global scope
window.loadVerification = loadVerification;
window.viewVerificationDetails = viewVerificationDetails;
window.approveUser = approveUser;
window.rejectUser = rejectUser;
window.loadTracking = loadTracking;
window.focusDriverOnMapbox = focusDriverOnMapbox;
