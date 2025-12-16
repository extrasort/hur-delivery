/**
 * Admin Order Management Functions
 * Complete order control for administrators
 */

// =====================================================================================
// ASSIGN DRIVER TO ORDER
// =====================================================================================

async function assignDriver(orderId) {
    try {
        // Get available drivers
        const { data: drivers, error } = await supabaseClient
            .rpc('get_available_drivers_for_order', { p_order_id: orderId });
        
        if (error) throw error;
        
        if (!drivers || drivers.length === 0) {
            alert('⚠️ لا يوجد سائقون متاحون / No available drivers');
            return;
        }
        
        // Create driver selection modal
        const modalBody = document.getElementById('orderActionModalBody');
        modalBody.innerHTML = `
            <h3>اختر سائق / Select Driver</h3>
            <div class="drivers-selection-list">
                ${drivers.map(driver => `
                    <div class="driver-selection-card ${driver.is_online ? 'online' : 'offline'}" 
                         onclick="confirmDriverAssignment('${orderId}', '${driver.driver_id}', '${driver.driver_name}')">
                        <div class="driver-selection-info">
                            <div class="driver-selection-header">
                                <h4>
                                    <i class="fas fa-motorcycle"></i> ${driver.driver_name}
                                    ${driver.is_online ? '<span class="badge badge-success"><i class="fas fa-circle"></i> متصل</span>' : '<span class="badge badge-secondary">غير متصل</span>'}
                                </h4>
                            </div>
                            <p><i class="fas fa-phone"></i> ${driver.driver_phone}</p>
                            <div class="driver-selection-stats">
                                <span><i class="fas fa-box"></i> ${driver.current_orders} طلبات حالية / Current orders</span>
                                <span><i class="fas fa-check-circle"></i> ${driver.total_completed} مكتمل / Completed</span>
                                ${driver.distance_km ? `<span><i class="fas fa-route"></i> ${driver.distance_km.toFixed(1)} كم / km</span>` : ''}
                            </div>
                        </div>
                        <div class="driver-selection-action">
                            <i class="fas fa-chevron-left"></i>
                        </div>
                    </div>
                `).join('')}
            </div>
        `;
        
        openModal('orderActionModal');
    } catch (error) {
        console.error('Assign driver error:', error);
        alert('❌ خطأ / Error: ' + error.message);
    }
}

async function confirmDriverAssignment(orderId, driverId, driverName) {
    if (!confirm(`تخصيص الطلب للسائق ${driverName}؟\nAssign order to driver ${driverName}?`)) return;
    
    try {
        const { data, error } = await supabaseClient
            .rpc('admin_assign_driver_to_order', {
                p_order_id: orderId,
                p_driver_id: driverId,
                p_admin_id: currentUser.id
            });
        
        if (error) throw error;
        
        if (data.success) {
            alert('✅ ' + data.message);
            closeAllModals();
            loadOrders();
        } else {
            alert('❌ ' + data.message);
        }
    } catch (error) {
        console.error('Confirm assignment error:', error);
        alert('❌ خطأ / Error: ' + error.message);
    }
}

// =====================================================================================
// REASSIGN ORDER TO DIFFERENT DRIVER
// =====================================================================================

async function reassignOrder(orderId) {
    try {
        // Get available drivers
        const { data: drivers, error } = await supabaseClient
            .rpc('get_available_drivers_for_order', { p_order_id: orderId });
        
        if (error) throw error;
        
        if (!drivers || drivers.length === 0) {
            alert('⚠️ لا يوجد سائقون متاحون / No available drivers');
            return;
        }
        
        const modalBody = document.getElementById('orderActionModalBody');
        modalBody.innerHTML = `
            <h3>إعادة التخصيص / Reassign Order</h3>
            <div class="form-group">
                <label>سبب إعادة التخصيص / Reassignment Reason</label>
                <input type="text" id="reassignReason" placeholder="سبب... / Reason..." />
            </div>
            <div class="drivers-selection-list">
                ${drivers.map(driver => `
                    <div class="driver-selection-card ${driver.is_online ? 'online' : 'offline'}" 
                         onclick="confirmReassignment('${orderId}', '${driver.driver_id}', '${driver.driver_name}')">
                        <div class="driver-selection-info">
                            <div class="driver-selection-header">
                                <h4>
                                    <i class="fas fa-motorcycle"></i> ${driver.driver_name}
                                    ${driver.is_online ? '<span class="badge badge-success"><i class="fas fa-circle"></i> متصل</span>' : '<span class="badge badge-secondary">غير متصل</span>'}
                                </h4>
                            </div>
                            <p><i class="fas fa-phone"></i> ${driver.driver_phone}</p>
                            <div class="driver-selection-stats">
                                <span><i class="fas fa-box"></i> ${driver.current_orders} حالي / Current</span>
                                <span><i class="fas fa-check-circle"></i> ${driver.total_completed} مكتمل / Completed</span>
                                ${driver.distance_km ? `<span><i class="fas fa-route"></i> ${driver.distance_km.toFixed(1)} كم</span>` : ''}
                            </div>
                        </div>
                        <div class="driver-selection-action">
                            <i class="fas fa-exchange-alt"></i>
                        </div>
                    </div>
                `).join('')}
            </div>
        `;
        
        openModal('orderActionModal');
    } catch (error) {
        console.error('Reassign order error:', error);
        alert('❌ خطأ / Error: ' + error.message);
    }
}

async function confirmReassignment(orderId, newDriverId, driverName) {
    const reason = document.getElementById('reassignReason')?.value || 'Admin reassignment';
    
    if (!confirm(`إعادة تخصيص الطلب للسائق ${driverName}؟\nReassign order to ${driverName}?`)) return;
    
    try {
        const { data, error } = await supabaseClient
            .rpc('admin_reassign_order', {
                p_order_id: orderId,
                p_new_driver_id: newDriverId,
                p_admin_id: currentUser.id,
                p_reason: reason
            });
        
        if (error) throw error;
        
        if (data.success) {
            alert('✅ ' + data.message);
            closeAllModals();
            loadOrders();
        } else {
            alert('❌ ' + data.message);
        }
    } catch (error) {
        console.error('Confirm reassignment error:', error);
        alert('❌ خطأ / Error: ' + error.message);
    }
}

// =====================================================================================
// CHANGE ORDER STATUS
// =====================================================================================

async function changeOrderStatus(orderId, currentStatus) {
    const modalBody = document.getElementById('orderActionModalBody');
    
    const statuses = [
        { value: 'pending', label: 'معلق / Pending', color: 'warning' },
        { value: 'assigned', label: 'مخصص / Assigned', color: 'info' },
        { value: 'accepted', label: 'مقبول / Accepted', color: 'success' },
        { value: 'on_the_way', label: 'في الطريق / On The Way', color: 'info' },
        { value: 'delivered', label: 'تم التسليم / Delivered', color: 'success' },
        { value: 'cancelled', label: 'ملغي / Cancelled', color: 'danger' },
        { value: 'rejected', label: 'مرفوض / Rejected', color: 'danger' }
    ];
    
    modalBody.innerHTML = `
        <h3>تغيير حالة الطلب / Change Order Status</h3>
        <p class="current-status">الحالة الحالية / Current: <span class="badge badge-${getStatusBadgeClass(currentStatus)}">${currentStatus}</span></p>
        
        <div class="form-group">
            <label>الحالة الجديدة / New Status</label>
            <select id="newStatus" class="form-control">
                <option value="">اختر... / Select...</option>
                ${statuses.map(s => `
                    <option value="${s.value}" ${s.value === currentStatus ? 'disabled' : ''}>${s.label}</option>
                `).join('')}
            </select>
        </div>
        
        <div class="form-group">
            <label>ملاحظات (اختياري) / Notes (Optional)</label>
            <textarea id="statusNotes" rows="3" placeholder="سبب التغيير... / Reason for change..."></textarea>
        </div>
        
        <button class="btn btn-primary" onclick="confirmStatusChange('${orderId}')">
            <i class="fas fa-check"></i> تأكيد التغيير / Confirm Change
        </button>
    `;
    
    openModal('orderActionModal');
}

async function confirmStatusChange(orderId) {
    const newStatus = document.getElementById('newStatus')?.value;
    const notes = document.getElementById('statusNotes')?.value;
    
    if (!newStatus) {
        alert('⚠️ يرجى اختيار الحالة / Please select status');
        return;
    }
    
    if (!confirm(`تأكيد تغيير الحالة إلى ${newStatus}؟\nConfirm status change to ${newStatus}?`)) return;
    
    try {
        const { data, error } = await supabaseClient
            .rpc('admin_change_order_status', {
                p_order_id: orderId,
                p_new_status: newStatus,
                p_admin_id: currentUser.id,
                p_notes: notes || null
            });
        
        if (error) throw error;
        
        if (data.success) {
            alert('✅ ' + data.message);
            closeAllModals();
            loadOrders();
        } else {
            alert('❌ ' + data.message);
        }
    } catch (error) {
        console.error('Change status error:', error);
        alert('❌ خطأ / Error: ' + error.message);
    }
}

// =====================================================================================
// EDIT ORDER DETAILS
// =====================================================================================

async function editOrderDetails(orderId) {
    try {
        // Get current order details
        const { data: order, error } = await supabaseClient
            .from('orders')
            .select('*')
            .eq('id', orderId)
            .single();
        
        if (error) throw error;
        
        const modalBody = document.getElementById('orderActionModalBody');
        modalBody.innerHTML = `
            <h3>تعديل تفاصيل الطلب / Edit Order Details</h3>
            
            <div class="form-grid">
                <div class="form-group">
                    <label>اسم العميل / Customer Name</label>
                    <input type="text" id="editCustomerName" value="${order.customer_name}" />
                </div>
                
                <div class="form-group">
                    <label>هاتف العميل / Customer Phone</label>
                    <input type="tel" id="editCustomerPhone" value="${order.customer_phone}" />
                </div>
                
                <div class="form-group">
                    <label>عنوان الاستلام / Pickup Address</label>
                    <textarea id="editPickupAddress" rows="2">${order.pickup_address}</textarea>
                </div>
                
                <div class="form-group">
                    <label>عنوان التوصيل / Delivery Address</label>
                    <textarea id="editDeliveryAddress" rows="2">${order.delivery_address}</textarea>
                </div>
                
                <div class="form-group">
                    <label>المبلغ الإجمالي / Total Amount (${CONFIG.CURRENCY})</label>
                    <input type="number" id="editTotalAmount" value="${order.total_amount}" step="100" />
                </div>
                
                <div class="form-group">
                    <label>رسوم التوصيل / Delivery Fee (${CONFIG.CURRENCY})</label>
                    <input type="number" id="editDeliveryFee" value="${order.delivery_fee}" step="100" />
                </div>
            </div>
            
            <div class="form-group">
                <label>ملاحظات / Notes</label>
                <textarea id="editNotes" rows="3">${order.notes || ''}</textarea>
            </div>
            
            <button class="btn btn-primary" onclick="confirmOrderEdit('${orderId}')">
                <i class="fas fa-save"></i> حفظ التغييرات / Save Changes
            </button>
        `;
        
        openModal('orderActionModal');
    } catch (error) {
        console.error('Edit order error:', error);
        alert('❌ خطأ / Error: ' + error.message);
    }
}

async function confirmOrderEdit(orderId) {
    if (!confirm('حفظ التغييرات؟ / Save changes?')) return;
    
    try {
        const { data, error} = await supabaseClient
            .rpc('admin_update_order_details', {
                p_order_id: orderId,
                p_customer_name: document.getElementById('editCustomerName')?.value,
                p_customer_phone: document.getElementById('editCustomerPhone')?.value,
                p_pickup_address: document.getElementById('editPickupAddress')?.value,
                p_delivery_address: document.getElementById('editDeliveryAddress')?.value,
                p_total_amount: parseFloat(document.getElementById('editTotalAmount')?.value),
                p_delivery_fee: parseFloat(document.getElementById('editDeliveryFee')?.value),
                p_notes: document.getElementById('editNotes')?.value,
                p_admin_id: currentUser.id
            });
        
        if (error) throw error;
        
        if (data.success) {
            alert('✅ ' + data.message);
            closeAllModals();
            loadOrders();
        } else {
            alert('❌ ' + data.message);
        }
    } catch (error) {
        console.error('Save order edit error:', error);
        alert('❌ خطأ / Error: ' + error.message);
    }
}

// =====================================================================================
// CANCEL ORDER WITH REFUND
// =====================================================================================

async function cancelOrderWithRefund(orderId) {
    const modalBody = document.getElementById('orderActionModalBody');
    modalBody.innerHTML = `
        <h3>إلغاء الطلب / Cancel Order</h3>
        
        <div class="form-group">
            <label>سبب الإلغاء / Cancellation Reason</label>
            <textarea id="cancelReason" rows="3" placeholder="يرجى ذكر السبب... / Please provide reason..." required></textarea>
        </div>
        
        <div class="form-group">
            <label class="checkbox-label">
                <input type="checkbox" id="refundToWallet" checked />
                استرداد رسوم الطلب إلى المحفظة / Refund order fee to wallet
            </label>
        </div>
        
        <div class="warning-box">
            <i class="fas fa-exclamation-triangle"></i>
            <p>⚠️ سيتم إلغاء الطلب نهائياً / Order will be permanently cancelled</p>
        </div>
        
        <button class="btn btn-danger" onclick="confirmOrderCancellation('${orderId}')">
            <i class="fas fa-times-circle"></i> إلغاء الطلب / Cancel Order
        </button>
    `;
    
    openModal('orderActionModal');
}

async function confirmOrderCancellation(orderId) {
    const reason = document.getElementById('cancelReason')?.value;
    const refund = document.getElementById('refundToWallet')?.checked;
    
    if (!reason) {
        alert('⚠️ يرجى إدخال سبب الإلغاء / Please enter cancellation reason');
        return;
    }
    
    if (!confirm('⚠️ تأكيد إلغاء الطلب؟ / Confirm order cancellation?')) return;
    
    try {
        const { data, error } = await supabaseClient
            .rpc('admin_cancel_order_with_refund', {
                p_order_id: orderId,
                p_admin_id: currentUser.id,
                p_reason: reason,
                p_refund_to_wallet: refund
            });
        
        if (error) throw error;
        
        if (data.success) {
            alert('✅ ' + data.message + (refund ? `\nRefunded: ${formatCurrency(data.refund_amount)}` : ''));
            closeAllModals();
            loadOrders();
        } else {
            alert('❌ ' + data.message);
        }
    } catch (error) {
        console.error('Cancel order error:', error);
        alert('❌ خطأ / Error: ' + error.message);
    }
}

// Export to global scope
window.assignDriver = assignDriver;
window.confirmDriverAssignment = confirmDriverAssignment;
window.reassignOrder = reassignOrder;
window.confirmReassignment = confirmReassignment;
window.changeOrderStatus = changeOrderStatus;
window.confirmStatusChange = confirmStatusChange;
window.editOrderDetails = editOrderDetails;
window.confirmOrderEdit = confirmOrderEdit;
window.cancelOrderWithRefund = cancelOrderWithRefund;
window.confirmOrderCancellation = confirmOrderCancellation;




