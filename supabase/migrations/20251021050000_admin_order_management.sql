-- =====================================================================================
-- ADMIN ORDER MANAGEMENT FUNCTIONS
-- =====================================================================================
-- Comprehensive functions for admins to manage orders with full authority
-- =====================================================================================

-- Drop all existing admin functions first to avoid conflicts
DROP FUNCTION IF EXISTS admin_assign_driver_to_order(UUID, UUID, UUID);
DROP FUNCTION IF EXISTS admin_change_order_status(UUID, TEXT, UUID, TEXT);
DROP FUNCTION IF EXISTS admin_change_order_status(UUID, TEXT, UUID);
DROP FUNCTION IF EXISTS admin_update_order_details(UUID, TEXT, TEXT, TEXT, TEXT, DECIMAL, DECIMAL, TEXT, UUID);
DROP FUNCTION IF EXISTS admin_get_available_drivers_for_order(UUID);
DROP FUNCTION IF EXISTS admin_get_available_drivers_for_order();
DROP FUNCTION IF EXISTS admin_cancel_order(UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS admin_cancel_order(UUID, UUID);
DROP FUNCTION IF EXISTS admin_reassign_order(UUID, UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS admin_reassign_order(UUID, UUID, UUID);
DROP FUNCTION IF EXISTS get_available_drivers_for_order(UUID);
DROP FUNCTION IF EXISTS get_available_drivers_for_order();

-- =====================================================================================
-- 1. MANUALLY ASSIGN DRIVER TO ORDER
-- =====================================================================================

CREATE OR REPLACE FUNCTION admin_assign_driver_to_order(
    p_order_id UUID,
    p_driver_id UUID,
    p_admin_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_order_status TEXT;
    v_driver_name TEXT;
    v_merchant_id UUID;
BEGIN
    -- Check if order exists
    SELECT status, merchant_id INTO v_order_status, v_merchant_id
    FROM orders
    WHERE id = p_order_id;
    
    IF v_order_status IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Order not found'
        );
    END IF;
    
    -- Get driver name
    SELECT name INTO v_driver_name
    FROM users
    WHERE id = p_driver_id AND role = 'driver';
    
    IF v_driver_name IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Driver not found or invalid role'
        );
    END IF;
    
    -- Update order
    UPDATE orders
    SET 
        driver_id = p_driver_id,
        status = CASE 
            WHEN status = 'pending' THEN 'assigned'
            ELSE status
        END,
        driver_assigned_at = NOW(),
        updated_at = NOW()
    WHERE id = p_order_id;
    
    -- Create assignment record
    INSERT INTO order_assignments (
        order_id,
        driver_id,
        status,
        assigned_at,
        timeout_at
    ) VALUES (
        p_order_id,
        p_driver_id,
        'pending',
        NOW(),
        NOW() + INTERVAL '30 seconds'
    )
    ON CONFLICT (order_id, driver_id) DO UPDATE
    SET status = 'pending', assigned_at = NOW(), timeout_at = NOW() + INTERVAL '30 seconds';
    
    -- Create notification for driver
    INSERT INTO notifications (
        user_id,
        title,
        body,
        type,
        data
    ) VALUES (
        p_driver_id,
        'طلب جديد / New Order',
        'تم تخصيص طلب لك من قبل المدير / Order assigned to you by admin',
        'order_assigned',
        jsonb_build_object('order_id', p_order_id, 'assigned_by', 'admin')
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Driver assigned successfully',
        'driver_name', v_driver_name,
        'order_id', p_order_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- 2. CHANGE ORDER STATUS (ADMIN OVERRIDE)
-- =====================================================================================

CREATE OR REPLACE FUNCTION admin_change_order_status(
    p_order_id UUID,
    p_new_status TEXT,
    p_admin_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_merchant_id UUID;
    v_driver_id UUID;
    v_old_status TEXT;
BEGIN
    -- Validate status
    IF p_new_status NOT IN ('pending', 'assigned', 'accepted', 'on_the_way', 'picked_up', 'delivered', 'cancelled', 'rejected') THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invalid status');
    END IF;
    
    -- Get order details
    SELECT merchant_id, driver_id, status 
    INTO v_merchant_id, v_driver_id, v_old_status
    FROM orders
    WHERE id = p_order_id;
    
    IF v_merchant_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Order not found');
    END IF;
    
    -- Update order status
    UPDATE orders
    SET 
        status = p_new_status,
        updated_at = NOW(),
        delivered_at = CASE WHEN p_new_status = 'delivered' THEN NOW() ELSE delivered_at END,
        cancelled_at = CASE WHEN p_new_status = 'cancelled' THEN NOW() ELSE cancelled_at END,
        rejected_at = CASE WHEN p_new_status = 'rejected' THEN NOW() ELSE rejected_at END,
        accepted_at = CASE WHEN p_new_status = 'accepted' THEN NOW() ELSE accepted_at END,
        notes = COALESCE(p_notes, notes)
    WHERE id = p_order_id;
    
    -- Notify merchant
    INSERT INTO notifications (
        user_id,
        title,
        body,
        type,
        data
    ) VALUES (
        v_merchant_id,
        'تحديث الطلب / Order Update',
        format('تم تغيير حالة الطلب من %s إلى %s بواسطة المدير', v_old_status, p_new_status),
        'order_status_update',
        jsonb_build_object('order_id', p_order_id, 'old_status', v_old_status, 'new_status', p_new_status)
    );
    
    -- Notify driver if assigned
    IF v_driver_id IS NOT NULL THEN
        INSERT INTO notifications (
            user_id,
            title,
            body,
            type,
            data
        ) VALUES (
            v_driver_id,
            'تحديث الطلب / Order Update',
            format('تم تغيير حالة الطلب إلى %s', p_new_status),
            'order_status_update',
            jsonb_build_object('order_id', p_order_id, 'new_status', p_new_status)
        );
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Order status updated successfully',
        'old_status', v_old_status,
        'new_status', p_new_status
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- 3. UPDATE ORDER DETAILS (ADMIN EDIT)
-- =====================================================================================

CREATE OR REPLACE FUNCTION admin_update_order_details(
    p_order_id UUID,
    p_customer_name TEXT DEFAULT NULL,
    p_customer_phone TEXT DEFAULT NULL,
    p_pickup_address TEXT DEFAULT NULL,
    p_delivery_address TEXT DEFAULT NULL,
    p_total_amount DECIMAL DEFAULT NULL,
    p_delivery_fee DECIMAL DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_admin_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
BEGIN
    -- Update only provided fields
    UPDATE orders
    SET 
        customer_name = COALESCE(p_customer_name, customer_name),
        customer_phone = COALESCE(p_customer_phone, customer_phone),
        pickup_address = COALESCE(p_pickup_address, pickup_address),
        delivery_address = COALESCE(p_delivery_address, delivery_address),
        total_amount = COALESCE(p_total_amount, total_amount),
        delivery_fee = COALESCE(p_delivery_fee, delivery_fee),
        notes = COALESCE(p_notes, notes),
        updated_at = NOW()
    WHERE id = p_order_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Order not found');
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Order details updated successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- 4. GET AVAILABLE DRIVERS FOR ASSIGNMENT
-- =====================================================================================

CREATE OR REPLACE FUNCTION admin_get_available_drivers_for_order(
    p_order_id UUID DEFAULT NULL
)
RETURNS TABLE (
    driver_id UUID,
    driver_name TEXT,
    driver_phone TEXT,
    vehicle_type TEXT,
    is_online BOOLEAN,
    current_orders BIGINT,
    total_completed BIGINT,
    distance_km NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.name,
        u.phone,
        u.vehicle_type,
        u.is_online,
        (
            SELECT COUNT(*)
            FROM orders o
            WHERE o.driver_id = u.id 
            AND o.status IN ('assigned', 'accepted', 'on_the_way', 'picked_up')
        )::BIGINT,
        (
            SELECT COUNT(*)
            FROM orders o
            WHERE o.driver_id = u.id 
            AND o.status = 'delivered'
        )::BIGINT,
        CASE 
            WHEN p_order_id IS NOT NULL AND ord.pickup_latitude IS NOT NULL AND ord.pickup_longitude IS NOT NULL 
                 AND u.latitude IS NOT NULL AND u.longitude IS NOT NULL THEN
                ST_Distance(
                    ST_MakePoint(u.longitude, u.latitude)::geography,
                    ST_MakePoint(ord.pickup_longitude, ord.pickup_latitude)::geography
                ) / 1000.0
            ELSE NULL
        END::NUMERIC
    FROM users u
    LEFT JOIN orders ord ON ord.id = p_order_id
    WHERE u.role = 'driver'
        AND u.manual_verified = true
    ORDER BY u.is_online DESC, total_completed DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- 5. CANCEL ORDER (ADMIN)
-- =====================================================================================

CREATE OR REPLACE FUNCTION admin_cancel_order(
    p_order_id UUID,
    p_admin_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_merchant_id UUID;
    v_driver_id UUID;
    v_old_status TEXT;
BEGIN
    -- Get order details
    SELECT merchant_id, driver_id, status 
    INTO v_merchant_id, v_driver_id, v_old_status
    FROM orders
    WHERE id = p_order_id;
    
    IF v_merchant_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Order not found');
    END IF;
    
    -- Update order
    UPDATE orders
    SET 
        status = 'cancelled',
        cancelled_at = NOW(),
        updated_at = NOW(),
        notes = COALESCE(p_reason, notes)
    WHERE id = p_order_id;
    
    -- Notify merchant
    INSERT INTO notifications (user_id, title, body, type, data) VALUES (
        v_merchant_id,
        'إلغاء الطلب / Order Cancelled',
        'تم إلغاء الطلب من قبل المدير / Order cancelled by admin',
        'order_cancelled',
        jsonb_build_object('order_id', p_order_id, 'reason', p_reason)
    );
    
    -- Notify driver if assigned
    IF v_driver_id IS NOT NULL THEN
        INSERT INTO notifications (user_id, title, body, type, data) VALUES (
            v_driver_id,
            'إلغاء الطلب / Order Cancelled',
            'تم إلغاء الطلب من قبل المدير / Order cancelled by admin',
            'order_cancelled',
            jsonb_build_object('order_id', p_order_id)
        );
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Order cancelled successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- 6. REASSIGN ORDER TO DIFFERENT DRIVER
-- =====================================================================================

CREATE OR REPLACE FUNCTION admin_reassign_order(
    p_order_id UUID,
    p_new_driver_id UUID,
    p_admin_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_old_driver_id UUID;
    v_new_driver_name TEXT;
    v_old_driver_name TEXT;
    v_merchant_id UUID;
BEGIN
    -- Get order details
    SELECT driver_id, merchant_id 
    INTO v_old_driver_id, v_merchant_id
    FROM orders
    WHERE id = p_order_id;
    
    IF v_merchant_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Order not found');
    END IF;
    
    -- Get driver names
    SELECT name INTO v_new_driver_name
    FROM users
    WHERE id = p_new_driver_id AND role = 'driver';
    
    IF v_new_driver_name IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'New driver not found');
    END IF;
    
    IF v_old_driver_id IS NOT NULL THEN
        SELECT name INTO v_old_driver_name
        FROM users
        WHERE id = v_old_driver_id;
    END IF;
    
    -- Update order assignment
    UPDATE orders
    SET 
        driver_id = p_new_driver_id,
        driver_assigned_at = NOW(),
        updated_at = NOW()
    WHERE id = p_order_id;
    
    -- Notify old driver if exists
    IF v_old_driver_id IS NOT NULL THEN
        INSERT INTO notifications (user_id, title, body, type, data) VALUES (
            v_old_driver_id,
            'تم إعادة تخصيص الطلب / Order Reassigned',
            'تم إعادة تخصيص الطلب لسائق آخر / Order reassigned to another driver',
            'order_reassigned',
            jsonb_build_object('order_id', p_order_id, 'reason', p_reason)
        );
    END IF;
    
    -- Notify new driver
    INSERT INTO notifications (user_id, title, body, type, data) VALUES (
        p_new_driver_id,
        'طلب جديد / New Order',
        'تم تخصيص طلب لك من قبل المدير / Order assigned to you by admin',
        'order_assigned',
        jsonb_build_object('order_id', p_order_id, 'reassigned', true)
    );
    
    -- Notify merchant
    INSERT INTO notifications (user_id, title, body, type, data) VALUES (
        v_merchant_id,
        'تحديث الطلب / Order Update',
        format('تم إعادة تخصيص الطلب من %s إلى %s', 
            COALESCE(v_old_driver_name, 'لا يوجد'), v_new_driver_name),
        'order_updated',
        jsonb_build_object('order_id', p_order_id)
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Order reassigned successfully',
        'new_driver_name', v_new_driver_name
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- 7. GET AVAILABLE DRIVERS (ALIAS FOR COMPATIBILITY)
-- =====================================================================================

CREATE OR REPLACE FUNCTION get_available_drivers_for_order(
    p_order_id UUID DEFAULT NULL
)
RETURNS TABLE (
    driver_id UUID,
    driver_name TEXT,
    driver_phone TEXT,
    vehicle_type TEXT,
    is_online BOOLEAN,
    current_orders BIGINT,
    total_completed BIGINT,
    distance_km NUMERIC
) AS $$
BEGIN
    RETURN QUERY SELECT * FROM admin_get_available_drivers_for_order(p_order_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================================================
-- GRANT PERMISSIONS
-- =====================================================================================

GRANT EXECUTE ON FUNCTION admin_assign_driver_to_order TO authenticated;
GRANT EXECUTE ON FUNCTION admin_change_order_status TO authenticated;
GRANT EXECUTE ON FUNCTION admin_update_order_details TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_available_drivers_for_order TO authenticated;
GRANT EXECUTE ON FUNCTION admin_cancel_order TO authenticated;
GRANT EXECUTE ON FUNCTION admin_reassign_order TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_drivers_for_order TO authenticated;

-- =====================================================================================
-- DONE! Admin order management functions are ready
-- =====================================================================================
