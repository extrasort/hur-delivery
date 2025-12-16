# 🚚 حر (Hur) - Complete Delivery Management System

A comprehensive delivery management platform for the Iraqi market, featuring a Flutter mobile app, React admin panel, and marketing website with full Arabic RTL support.

## 📦 Project Structure

This repository contains three main components:

### 1. **Flutter Mobile App** (Root Directory)
The main mobile application for Merchants, Drivers, and Customers built with Flutter.

### 2. **Admin Panel** (`/admin_panel`)
A web-based admin dashboard for system management and monitoring.

### 3. **Marketing Website** (`/website`)
A modern React-based marketing website with landing pages and legal documents.

### 4. **Supabase Backend** (`/supabase`)
Edge functions and database migrations for the Supabase backend.

---

## 🚀 Features

### Mobile App Features
- **Multi-role Authentication**: Merchants, Drivers, Customers, and Admins
- **Phone-based OTP Authentication**: Iraqi phone number format (+964)
- **Real-time Order Tracking**: Live updates via Supabase
- **Location Services**: GPS tracking with Mapbox integration
- **Push Notifications**: Firebase Cloud Messaging with local notifications
- **Voice Orders**: Audio recording and transcription
- **Arabic RTL Support**: Complete right-to-left layout
- **Offline Support**: Background location tracking and foreground services
- **Payment Integration**: Wayl payment gateway support
- **Multi-language**: Arabic localization with Tajawal and Cairo fonts

### Admin Panel Features
- **Order Management**: Create, update, and track all orders
- **User Management**: Manage merchants, drivers, and customers
- **Verification System**: ID card and driver verification
- **Emergency Alerts**: System-wide announcements
- **Analytics & Reports**: Comprehensive business insights
- **Wallet Management**: Driver and merchant wallet operations
- **Health Monitoring**: System status and diagnostics

### Website Features
- **Modern Landing Page**: Responsive design with animations
- **Multi-language Support**: Arabic and English
- **Account Deletion**: GDPR-compliant self-service deletion
- **Legal Pages**: Privacy policy and terms of service
- **SEO Optimized**: Meta tags and structured data

---

## 🛠️ Technical Stack

### Mobile App
- **Framework**: Flutter 3.4.4+
- **Language**: Dart 3.0+
- **Backend**: Supabase (PostgreSQL + Real-time)
- **Maps**: Mapbox Maps Flutter
- **Location**: Geolocator
- **Notifications**: Firebase Cloud Messaging + Flutter Local Notifications
- **State Management**: Provider + Flutter Hooks
- **Navigation**: GoRouter
- **Audio**: Record, Audioplayers, Audio Waveforms
- **Storage**: Shared Preferences

### Admin Panel
- **Framework**: Vanilla JavaScript (SPA)
- **Styling**: Custom CSS
- **Backend**: Supabase Client
- **Deployment**: Static hosting

### Website
- **Framework**: React 18 + Vite
- **Styling**: Custom CSS
- **Routing**: React Router
- **Internationalization**: i18next
- **Deployment**: Netlify

### Backend
- **Database**: PostgreSQL (Supabase)
- **Real-time**: Supabase Realtime
- **Edge Functions**: Deno/TypeScript
- **Storage**: Supabase Storage
- **Authentication**: Supabase Auth

---

## 📱 User Roles

### Merchants (التجار)
- Create and manage orders
- Track order status in real-time
- View analytics and earnings
- Manage customer information
- Voice order creation
- Wallet management

### Drivers (السائقين)
- Receive order assignments
- Track delivery routes with turn-by-turn navigation
- Update order status with proof of delivery
- View earnings and history
- Real-time location tracking
- Offline mode support

### Customers (العملاء)
- Place orders via WhatsApp integration
- Track delivery status in real-time
- Receive location-based updates
- Rate and review service

### Admins (المديرين)
- Manage all users and roles
- Monitor system performance
- Handle verification requests
- View comprehensive analytics
- Send emergency alerts
- Manage payment methods

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK**: 3.4.4 or higher
- **Dart SDK**: 3.0.0 or higher
- **Node.js**: 16+ (for website and admin panel)
- **Android Studio** or **Xcode** (for mobile development)
- **Supabase Account**: For backend services
- **Firebase Account**: For push notifications
- **Mapbox Account**: For maps and navigation

### 1. Mobile App Setup

```bash
# Clone the repository
git clone https://github.com/extrasort/hur-delivery.git
cd hur-delivery

# Install dependencies
flutter pub get

# Create .env file (copy from env.example)
cp env.example .env

# Add your configuration to .env
# - Supabase URL and anon key
# - Mapbox access token
# - Firebase configuration

# Run the app
flutter run
```

#### Firebase Configuration

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
2. Add Android app with package name: `com.hur.delivery`
3. Download `google-services.json` to `android/app/`
4. Add iOS app and download `GoogleService-Info.plist` to `ios/Runner/`
5. Enable Cloud Messaging in Firebase Console

#### Mapbox Configuration

1. Get a Mapbox access token from [Mapbox](https://account.mapbox.com)
2. Add to `.env` file: `MAPBOX_ACCESS_TOKEN=your_token_here`

### 2. Admin Panel Setup

```bash
cd admin_panel

# Copy config example
cp config.example.js config.js

# Update config.js with your Supabase credentials

# Open index.html in a web browser or serve with a local server
python3 -m http.server 8000
# Visit http://localhost:8000
```

### 3. Website Setup

```bash
cd website

# Install dependencies
npm install

# Create .env file with Supabase credentials
echo "VITE_SUPABASE_URL=your_supabase_url" > .env
echo "VITE_SUPABASE_ANON_KEY=your_anon_key" >> .env

# Run development server
npm run dev

# Build for production
npm run build
```

### 4. Supabase Setup

1. Create a new Supabase project
2. Run migrations in order from `supabase/migrations/`
3. Deploy edge functions from `supabase/functions/`
4. Configure storage buckets:
   - `order-images` - For order photos
   - `verification-images` - For ID cards and driver verification
   - `voice-orders` - For audio recordings

```bash
# Install Supabase CLI
npm install -g supabase

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref your-project-ref

# Push migrations
supabase db push

# Deploy edge functions
supabase functions deploy
```

---

## 📦 Key Dependencies

### Mobile App

```yaml
dependencies:
  supabase_flutter: ^2.0.0
  mapbox_maps_flutter: ^2.0.0
  geolocator: ^10.1.0
  permission_handler: ^11.0.1
  firebase_messaging: ^15.1.4
  firebase_core: ^3.6.0
  flutter_local_notifications: ^17.0.0
  flutter_foreground_task: ^8.0.0
  image_picker: ^1.0.4
  record: 5.0.5
  audioplayers: ^6.0.0
  provider: ^6.1.1
  go_router: ^12.1.3
  flutter_hooks: ^0.20.3
```

---

## 🗄️ Database Schema

Main tables in Supabase:

- **users** - User profiles with role-based access
- **orders** - Order information and status tracking
- **order_items** - Individual items in orders
- **order_assignments** - Driver assignment history
- **notifications** - Push notification logs
- **fcm_tokens** - Device tokens for push notifications
- **device_sessions** - Active device sessions
- **emergency_alerts** - System-wide announcements
- **rejection_history** - Order rejection tracking
- **timeout_tracking** - Auto-rejection timeout management
- **driver_locations** - Real-time driver location data

---

## 🎨 Design System

### Colors
- **Primary**: #E3A423 (Hur Yellow)
- **Secondary**: #1E40AF (Blue)
- **Success**: #10B981 (Green)
- **Warning**: #F59E0B (Orange)
- **Error**: #EF4444 (Red)
- **Background**: #F9FAFB (Light Gray)

### Typography
- **Primary Font**: Tajawal (Arabic)
- **Secondary Font**: Noto Sans Arabic
- **Accent Font**: Cairo
- **RTL Support**: Complete right-to-left layout
- **Responsive**: Adapts to all screen sizes

---

## 📱 App Screens

### Authentication Flow
1. Landing Screen - App introduction
2. Role Selection - Choose user type (Merchant/Driver)
3. Phone Input - Iraqi phone number (+964)
4. OTP Verification - SMS verification code
5. User Registration - Complete profile
6. Verification Pending - Wait for admin approval

### Merchant Screens
- Dashboard - Order overview and quick actions
- Create Order - New order with voice or text input
- Order List - All orders with filtering
- Order Details - Comprehensive order information
- Analytics - Earnings and statistics
- Profile - Account settings

### Driver Screens
- Dashboard - Available orders and current deliveries
- Map View - Navigation and route tracking
- Order Details - Pickup and delivery information
- Delivery Proof - Photo capture and signature
- Earnings - Payment history and wallet
- Profile - Account and vehicle settings

### Admin Screens (Web)
- Dashboard - System overview
- User Management - Verify and manage users
- Order Management - Monitor all orders
- Analytics - Business intelligence
- Emergency Alerts - System announcements
- Settings - System configuration

---

## 🔧 Configuration Files

### Required Files (Not in Git)

Create these files from the examples:

1. **`.env`** - Environment variables
   ```env
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_anon_key
   MAPBOX_ACCESS_TOKEN=your_mapbox_token
   ```

2. **`google-services.json`** - Firebase Android config
3. **`GoogleService-Info.plist`** - Firebase iOS config
4. **`admin_panel/config.js`** - Admin panel Supabase config

---

## 🚀 Deployment

### Mobile App

#### Android
```bash
# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

#### iOS
```bash
# Build iOS app
flutter build ios --release

# Or build IPA
flutter build ipa --release
```

### Admin Panel

Deploy to any static hosting service (Netlify, Vercel, GitHub Pages):

```bash
cd admin_panel
# Upload all files to your hosting service
```

### Website

```bash
cd website
npm run build
# Deploy the dist/ folder to Netlify or Vercel
```

---

## 🔐 Security

- **Row Level Security (RLS)**: Enabled on all Supabase tables
- **API Keys**: Never commit to Git (use .env files)
- **Firebase**: Secure with app signing and API restrictions
- **Authentication**: Phone-based OTP with verification
- **Authorization**: Role-based access control (RBAC)

---

## 📊 Features Checklist

- [x] Multi-role authentication system
- [x] Phone-based OTP verification
- [x] Real-time order tracking
- [x] GPS location services
- [x] Push notifications (FCM)
- [x] Background location tracking
- [x] Voice order creation
- [x] Image capture and upload
- [x] Payment gateway integration
- [x] Arabic RTL support
- [x] Admin verification system
- [x] Emergency alerts
- [x] Auto-rejection system
- [x] Driver analytics
- [x] Wallet management
- [x] Legal compliance (GDPR)

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is proprietary software. All rights reserved.

---

## 📞 Support

For support and questions:
- **Email**: support@hur.delivery
- **Website**: https://hur.delivery
- **GitHub Issues**: [Report a bug](https://github.com/extrasort/hur-delivery/issues)

---

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Supabase for the backend infrastructure
- Mapbox for mapping services
- Firebase for push notifications
- All contributors and testers

---

**حر - خدمة التوصيل السريع** 🚚

*Built with ❤️ for the Iraqi market*
