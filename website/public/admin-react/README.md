# حر - Hur Delivery Admin Panel (React)

Modern admin panel built with React, TypeScript, Tailwind CSS, and Supabase.

## 🚀 Features

- ✅ **Modern Tech Stack**: React 18 + TypeScript + Vite + Tailwind CSS
- ✅ **Supabase Integration**: Authentication, real-time subscriptions, and database queries
- ✅ **Full RTL Support**: Arabic/English bilingual interface
- ✅ **Real-time Updates**: Live data synchronization for orders, messages, and tracking
- ✅ **Responsive Design**: Works on desktop, tablet, and mobile
- ✅ **Type Safety**: Full TypeScript coverage for better developer experience
- ✅ **State Management**: Zustand for lightweight and efficient state management

## 📦 Pages Included

1. **Dashboard** - Overview with stats, charts, and quick insights
2. **Users** - Manage all users (drivers, merchants, admins)
3. **Orders** - View and manage all orders with real-time updates
4. **Drivers** - Driver management (ready for expansion)
5. **Merchants** - Merchant management (ready for expansion)
6. **Wallets** - User wallet management (ready for expansion)
7. **Earnings** - Financial reports and earnings (ready for expansion)
8. **Notifications** - Send and manage notifications (ready for expansion)
9. **Verification** - User identity verification (ready for expansion)
10. **Live Tracking** - Real-time driver and order tracking (ready for expansion)
11. **Emergency** - Emergency/SOS management (ready for expansion)
12. **Ops Messaging** - Full-featured operator messaging with:
    - Conversation list with counterpart details
    - Real-time chat interface
    - User orders panel with quick actions
    - Driver location display with coordinate copying
13. **Reviews** - Manage reviews and ratings (ready for expansion)

## 🛠️ Development

### Prerequisites
- Node.js 20.19+ or 22.12+
- npm or yarn

### Setup
```bash
cd website/public/admin-react
npm install
```

### Development Server
```bash
npm run dev
```
Access at: http://localhost:5173

### Build for Production
```bash
npm run build
```
Output: `website/public/admin/`

## 🔐 Authentication

The admin panel uses the **admin-login Edge Function** with the following features:
- Username/password authentication
- Automatic admin user creation in `auth.users` and `public.users`
- Session management via Supabase Auth
- Secure credential storage in Supabase secrets

### Required Environment Variables

Set these in your Supabase project (Settings → Edge Functions → Secrets):

```bash
ADMIN_LOGIN_USERNAME=admin
ADMIN_LOGIN_PASSWORD=your_secure_password
# Or use hashed password:
# ADMIN_LOGIN_PASSWORD_HASH=<sha256_hash>

ADMIN_SUPABASE_EMAIL=admin@hur.delivery
ADMIN_SUPABASE_PASSWORD=your_supabase_password
ADMIN_DISPLAY_NAME=Admin User
ADMIN_USER_ID=<optional_fixed_uuid>

SUPABASE_URL=https://your-project.supabase.co
SERVICE_ROLE_KEY=<your_service_role_key>
```

### Login Credentials

Use the username and password defined in:
- **Username**: Value of `ADMIN_LOGIN_USERNAME` env var
- **Password**: Value of `ADMIN_LOGIN_PASSWORD` env var

The Edge Function will automatically:
1. Create the admin user in `auth.users` if it doesn't exist
2. Upsert the admin into `public.users` with `role='admin'`
3. Return a valid session token for authentication

## 📁 Project Structure

```
src/
├── components/
│   └── Layout/
│       ├── Sidebar.tsx       # Navigation sidebar
│       ├── Header.tsx        # Top header with clock
│       └── MainLayout.tsx    # Main layout wrapper
├── pages/
│   ├── Dashboard.tsx         # Dashboard with stats
│   ├── Login.tsx             # Login page
│   ├── Orders.tsx            # Orders management
│   ├── Users.tsx             # Users management
│   ├── Messaging.tsx         # Ops messaging (full featured)
│   └── ...                   # Other pages
├── store/
│   └── authStore.ts          # Zustand auth state
├── lib/
│   ├── supabase.ts           # Supabase client & types
│   └── config.ts             # App configuration
├── App.tsx                   # Main app with routing
└── main.tsx                  # Entry point
```

## 🎨 Customization

### Colors
Edit `tailwind.config.js` to change the primary color scheme.

### Configuration
Edit `src/lib/config.ts` for app-wide settings:
- Supabase credentials
- Mapbox token
- Currency settings
- Pagination limits
- Refresh intervals

## 🔄 Migration from Old Admin

The old JavaScript admin panel has been backed up to `website/public/admin-old-backup/`.

Key differences:
- **React** vs vanilla JS
- **TypeScript** for type safety
- **Zustand** instead of global variables
- **React Router** for client-side routing
- **Supabase Auth** instead of custom edge function

## 📝 TODO / Future Enhancements

- [ ] Complete Driver Profile page with full details
- [ ] Add order detail modals with edit capabilities
- [ ] Implement wallet top-up and transaction history
- [ ] Build live tracking map with Mapbox
- [ ] Add user verification flow with document uploads
- [ ] Create notification sending interface
- [ ] Build emergency/SOS dashboard
- [ ] Add financial reports and charts
- [ ] Implement review moderation
- [ ] Add admin role and permission management
- [ ] Create system settings page
- [ ] Add data export capabilities (CSV, PDF)

## 🚢 Deployment

The build output is configured to deploy to `website/public/admin/`, replacing the old admin panel.

For production:
1. Run `npm run build` in `admin-react/`
2. Deploy the `website/public/` directory to your hosting
3. Ensure proper routing for SPA (redirect all `/admin/*` to `/admin/index.html`)

## 📚 Libraries Used

- **React** - UI library
- **TypeScript** - Type safety
- **Vite** - Build tool
- **Tailwind CSS** - Utility-first CSS
- **React Router** - Client-side routing
- **Zustand** - State management
- **@supabase/supabase-js** - Supabase client
- **Chart.js + react-chartjs-2** - Charts and visualizations
- **Mapbox GL** - Maps and location tracking
- **Font Awesome** - Icons

## 📞 Support

For issues or questions, contact the development team.

---

Built with ❤️ for Hur Delivery
