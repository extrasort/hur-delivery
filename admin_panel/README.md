# حر (Hur) Delivery - Admin Panel
## لوحة التحكم الإدارية الشاملة | Comprehensive Admin Control Panel

A full-featured, RTL-ready admin website for complete management of the Hur Delivery app. Built with vanilla JavaScript, modern UI, and Supabase integration.

---

## 🌟 Features | المميزات

### Core Management | الإدارة الأساسية
- **Dashboard** - Real-time statistics and overview
- **Users Management** - Complete control over all users (merchants, drivers, customers, admins)
- **Orders Management** - View, track, and manage all orders
- **Drivers Management** - Monitor driver performance, online status, and earnings
- **Merchants Management** - Track merchant activity, orders, and wallet status
- **Wallets Management** - Control merchant wallets, top-ups, and transactions
- **Earnings Management** - Track and mark driver earnings as paid
- **Notifications** - Send bulk notifications and view notification history
- **Live Tracking** - Real-time driver location monitoring
- **Device Sessions** - Manage active user sessions across devices
- **Analytics** - Advanced charts and performance metrics
- **System Settings** - Configure all system parameters
- **Database Tools** - Export data and run diagnostics

### Key Capabilities | القدرات الرئيسية
✅ User verification and approval
✅ Order status modification
✅ Wallet top-ups and adjustments
✅ Bulk notification sending
✅ Real-time data updates
✅ Session management (force logout)
✅ Advanced filtering and search
✅ Comprehensive statistics
✅ RTL (Arabic) support
✅ Responsive design
✅ Beautiful blue theme
✅ Real-time subscriptions

---

## 🚀 Quick Start | البدء السريع

### 1. Prerequisites | المتطلبات
- Supabase account with Hur Delivery database
- Modern web browser (Chrome, Firefox, Safari, Edge)
- Web server (local or remote)

### 2. Configuration | التكوين

Edit `config.js` and replace with your Supabase credentials:

```javascript
const CONFIG = {
  SUPABASE_URL: 'https://your-project.supabase.co',
  SUPABASE_ANON_KEY: 'your-anon-key-here',
  // ... other settings
};
```

### 3. Deployment | النشر

#### Option A: Local Development
```bash
# Using Python
cd admin_panel
python3 -m http.server 8000

# Or using PHP
php -S localhost:8000

# Or using Node.js
npx http-server -p 8000
```

Visit: `http://localhost:8000`

#### Option B: Deploy to Web Server
1. Upload all files to your web server
2. Ensure `config.js` has correct credentials
3. Access via your domain

#### Option C: Use Live Server (VS Code)
1. Install "Live Server" extension in VS Code
2. Right-click `index.html`
3. Select "Open with Live Server"

---

## 🔐 Login | تسجيل الدخول

1. Open the admin panel in your browser
2. Enter admin phone number (format: 964XXXXXXXXXX)
3. Enter admin password
4. Only users with `role = 'admin'` can access

**Security Note:** Make sure you have at least one admin user in your database:
```sql
-- Create an admin user
INSERT INTO users (phone, name, role, manual_verified)
VALUES ('9647XXXXXXXX', 'Admin Name', 'admin', true);

-- Set password using Supabase Auth Dashboard
```

---

## 📚 Feature Guide | دليل المميزات

### Dashboard | لوحة التحكم
- View real-time statistics
- Monitor active drivers and merchants
- See pending orders and verifications
- View recent orders
- Interactive charts

### Users Management | إدارة المستخدمين
- View all users with filtering by role
- Verify unverified users
- View detailed user information
- Delete users (with cascade delete of related data)
- Search by name, phone, or other fields

### Orders Management | إدارة الطلبات
- View all orders with comprehensive details
- Filter by status (pending, assigned, delivered, etc.)
- View order items and locations
- Cancel pending orders
- View merchant and driver information
- Track order timeline

### Drivers Management | إدارة السائقين
- Monitor online/offline status
- View driver statistics (orders, completion rate, earnings)
- Verify new drivers
- Track driver performance
- View vehicle information

### Merchants Management | إدارة التجار
- View merchant statistics
- Monitor wallet balance
- Track order volume
- Verify new merchants
- View store information

### Wallets Management | إدارة المحافظ
- View all merchant wallets
- Top-up wallets with custom amounts
- View transaction history
- Monitor credit limits
- Track balance status

### Earnings Management | إدارة الأرباح
- View all driver earnings
- Filter by status (pending, paid, cancelled)
- Mark earnings as paid
- Track commission amounts
- Export earnings reports

### Notifications | الإشعارات
- Send bulk notifications to all users or specific roles
- View notification history
- Track read/unread status
- Monitor notification delivery

### Live Tracking | التتبع المباشر
- View all online drivers
- See real-time GPS coordinates
- View drivers on map
- Monitor driver availability

### Device Sessions | إدارة الجلسات
- View all active sessions
- Force logout any session
- Monitor device information
- Track last seen timestamps

### Analytics | التحليلات
- Advanced performance charts
- Revenue analytics
- Driver performance metrics
- Merchant activity analysis
- Custom date ranges

### System Settings | إعدادات النظام
- Configure delivery fees
- Set commission rates
- Adjust timeout settings
- Modify credit limits
- Update system parameters

### Database Tools | أدوات قاعدة البيانات
- Export data to JSON
- View database statistics
- Clean up old records
- Monitor system health

---

## 🎨 UI Components | مكونات واجهة المستخدم

### Color Theme | نظام الألوان
- **Primary:** Blue (#1E40AF) - Main actions
- **Success:** Green (#10B981) - Completed actions
- **Warning:** Orange (#F59E0B) - Pending items
- **Danger:** Red (#EF4444) - Destructive actions
- **Info:** Light Blue (#3B82F6) - Informational

### Status Badges | شارات الحالة
- **Pending** - Orange
- **Assigned** - Blue
- **Accepted** - Green
- **Delivered** - Teal
- **Cancelled** - Red
- **Rejected** - Gray

### Responsive Breakpoints | نقاط التجاوب
- Desktop: 1024px+
- Tablet: 768px - 1023px
- Mobile: < 768px

---

## 🔧 Technical Details | التفاصيل التقنية

### Technology Stack | المجموعة التقنية
- **Frontend:** HTML5, CSS3, Vanilla JavaScript
- **Backend:** Supabase (PostgreSQL + Realtime)
- **Charts:** Chart.js v4
- **Icons:** Font Awesome 6
- **Authentication:** Supabase Auth

### Browser Support | دعم المتصفحات
- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

### Performance | الأداء
- Lazy loading for large datasets
- Real-time updates via Supabase subscriptions
- Optimized queries with proper indexing
- Pagination support (20 items per page)
- Auto-refresh every 30 seconds

### Security | الأمان
- Admin-only access (role-based)
- Secure Supabase RLS policies
- No SQL injection vulnerabilities
- HTTPS recommended for production
- Session management

---

## 📊 Database Schema | مخطط قاعدة البيانات

The admin panel manages the following tables:

### Core Tables
- `users` - All system users
- `orders` - Delivery orders
- `order_items` - Order line items
- `order_assignments` - Driver assignment history
- `order_rejected_drivers` - Rejection tracking

### Financial Tables
- `merchant_wallets` - Merchant wallet balances
- `wallet_transactions` - All wallet transactions
- `earnings` - Driver earnings records

### System Tables
- `notifications` - Push notifications
- `device_sessions` - Active user sessions
- `driver_locations` - GPS tracking
- `system_settings` - Configurable parameters

---

## 🛠️ Customization | التخصيص

### Changing Colors
Edit `styles.css` and modify the `:root` variables:
```css
:root {
    --primary: #1E40AF;  /* Change to your color */
    --success: #10B981;
    /* ... etc */
}
```

### Adding New Pages
1. Add navigation item in `index.html`:
```html
<a href="#" class="nav-item" data-page="mypage">
    <i class="fas fa-icon"></i>
    <span>My Page</span>
</a>
```

2. Add page content:
```html
<div id="mypagePage" class="page">
    <!-- Your content -->
</div>
```

3. Add loader in `app.js`:
```javascript
case 'mypage': loadMyPage(); break;
```

### Modifying Statistics
Edit the dashboard queries in `app.js` -> `loadDashboard()` function.

---

## 🐛 Troubleshooting | استكشاف الأخطاء

### Can't Login
1. Check if admin user exists in database
2. Verify phone number format (964XXXXXXXXXX)
3. Check Supabase credentials in `config.js`
4. Ensure admin user has `role = 'admin'`

### Data Not Loading
1. Open browser console (F12) and check for errors
2. Verify Supabase URL and keys
3. Check RLS policies allow admin access
4. Ensure tables exist in database

### Realtime Not Working
1. Check if Supabase Realtime is enabled
2. Verify tables are added to realtime publication
3. Check browser console for subscription errors

### Styling Issues
1. Clear browser cache (Ctrl+Shift+R)
2. Check if `styles.css` is loaded
3. Verify CDN resources are accessible

---

## 📝 API Functions | وظائف API

### Available Supabase RPC Functions

```sql
-- Add wallet balance
SELECT add_wallet_balance(
    p_merchant_id UUID,
    p_amount DECIMAL,
    p_payment_method TEXT,
    p_notes TEXT
);

-- Check if merchant can place order
SELECT can_merchant_place_order(p_merchant_id UUID);

-- Get wallet summary
SELECT get_wallet_summary(p_merchant_id UUID);

-- Register device session
SELECT register_device_session(
    p_user_id UUID,
    p_device_id TEXT,
    p_device_info JSONB
);

-- Logout device session
SELECT logout_device_session(
    p_user_id UUID,
    p_device_id TEXT
);

-- Check session active
SELECT check_session_active(
    p_user_id UUID,
    p_device_id TEXT
);
```

---

## 🔄 Updates & Maintenance | التحديثات والصيانة

### Regular Tasks
- Monitor dashboard for pending verifications
- Review and approve new drivers/merchants
- Process pending earnings payments
- Check wallet balances and top-up requests
- Monitor system settings
- Review notification logs

### Weekly Tasks
- Export data backups
- Review analytics and performance
- Clean up old sessions
- Check for system errors

### Monthly Tasks
- Analyze revenue and commission reports
- Review driver and merchant performance
- Update system settings if needed
- Archive old data

---

## 🚨 Important Notes | ملاحظات مهمة

### Security
⚠️ **Never expose your Supabase service role key in client-side code**
⚠️ **Always use HTTPS in production**
⚠️ **Regularly review and update RLS policies**
⚠️ **Monitor admin access logs**

### Performance
📊 **Dashboard auto-refreshes every 30 seconds**
📊 **Consider pagination for tables with 100+ rows**
📊 **Use filters to reduce data load**

### Best Practices
✅ Verify users before approving
✅ Document major changes in system settings
✅ Keep wallet transactions logged
✅ Monitor driver activity regularly
✅ Send notifications sparingly

---

## 📞 Support | الدعم

For issues or questions:
- Check this README first
- Review browser console for errors
- Check Supabase logs
- Verify database schema matches migration files

---

## 📄 License | الترخيص

This admin panel is part of the Hur Delivery system.
All rights reserved.

---

## 🎯 Roadmap | خارطة الطريق

### Planned Features
- [ ] Export data to Excel/CSV
- [ ] Advanced analytics with date ranges
- [ ] SMS notification integration
- [ ] Image upload for documents
- [ ] Audit log viewer
- [ ] Role-based admin permissions
- [ ] Dark mode
- [ ] Multi-language support
- [ ] Mobile app version
- [ ] Email notifications

---

**Built with ❤️ for Hur Delivery**
**تم البناء بحب لخدمة حر للتوصيل**
