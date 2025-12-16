import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

const resources = {
  ar: {
    translation: {
      // Navigation
      "nav.home": "الرئيسية",
      "nav.how": "كيف يعمل",
      "nav.testimonials": "آراء العملاء",
      "nav.download": "تحميل التطبيق",
      "nav.privacy": "سياسة الخصوصية",
      "nav.terms": "الشروط والأحكام",
      "nav.deleteAccount": "حذف الحساب",
      
      // Hero Section
      "hero.title": "حُر للتوصيل",
      "hero.subtitle": "الحرية في كل توصيلة",
      "hero.description": "منصة توصيل ذكية تمنحك الحرية الكاملة في إدارة طلباتك وتوصيلاتك. انضم إلى ثورة التوصيل الحر في العراق",
      "hero.cta.download": "حمّل التطبيق الآن",
      "hero.cta.learn": "اكتشف المزيد",
      
      
      // Features
      "features.title": "مميزات استثنائية",
      "features.subtitle": "كل ما تحتاجه لتجربة توصيل مميزة",
      
      "feature.freedom.title": "حرية كاملة",
      "feature.freedom.desc": "أنت تتحكم بكل شيء - أسعارك، أوقاتك، قراراتك. لا قيود، لا وسطاء",
      
      "feature.instant.title": "توصيل فوري",
      "feature.instant.desc": "نظام ذكي لربط الطلبات مع أقرب سائق متاح في ثوانٍ معدودة",
      
      "feature.tracking.title": "تتبع مباشر",
      "feature.tracking.desc": "تتبع طلباتك لحظة بلحظة مع إشعارات فورية وخرائط دقيقة",
      
      "feature.secure.title": "دفع آمن",
      "feature.secure.desc": "محفظة رقمية متكاملة مع نظام دفع آمن ومضمون",
      
      "feature.support.title": "دعم 24/7",
      "feature.support.desc": "فريق دعم متاح على مدار الساعة لمساعدتك في أي وقت",
      
      "feature.analytics.title": "تقارير تفصيلية",
      "feature.analytics.desc": "احصائيات شاملة لمتابعة أرباحك وأداء عملك بدقة",
      
      // Values
      "values.title": "قيمنا",
      "values.subtitle": "المبادئ التي نؤمن بها",
      
      "value.freedom.title": "الحرية",
      "value.freedom.desc": "نؤمن بحق كل فرد في اتخاذ قراراته وإدارة عمله بحرية تامة دون قيود",
      
      "value.trust.title": "الثقة",
      "value.trust.desc": "بناء علاقة ثقة مع عملائنا وشركائنا هو أساس نجاحنا المشترك",
      
      "value.innovation.title": "الابتكار",
      "value.innovation.desc": "نسعى دائماً لتطوير حلول تقنية مبتكرة تسهل حياة الجميع",
      
      "value.transparency.title": "الشفافية",
      "value.transparency.desc": "التعامل بشفافية كاملة في الأسعار والعمولات والخدمات",
      
      // How It Works
      "how.title": "كيف يعمل التطبيق",
      "how.subtitle": "أربع خطوات بسيطة للبدء",
      "how.tab.merchant": "للتجار",
      "how.tab.driver": "للسائقين",
      
      // Merchant Steps
      "how.merchant.step1.title": "سجّل كتاجر",
      "how.merchant.step1.desc": "سجل برقم هاتفك وأنشئ حساب تاجر في دقائق",
      
      "how.merchant.step2.title": "أضف طلبك",
      "how.merchant.step2.desc": "أدخل تفاصيل التوصيل ومواقع الاستلام والتسليم بسهولة",
      
      "how.merchant.step3.title": "اختر سائق",
      "how.merchant.step3.desc": "ينشر الطلب فوراً ويصلك السائقون المتاحون للاختيار",
      
      "how.merchant.step4.title": "تتبع وأكمل",
      "how.merchant.step4.desc": "تتبع التوصيل لحظياً حتى الوصول بأمان وتأكيد الاستلام",
      
      // Driver Steps
      "how.driver.step1.title": "سجّل كسائق",
      "how.driver.step1.desc": "سجل برقم هاتفك وقدّم المستندات المطلوبة للموافقة",
      
      "how.driver.step2.title": "تصفح الطلبات",
      "how.driver.step2.desc": "شاهد جميع الطلبات المتاحة في منطقتك على الخريطة",
      
      "how.driver.step3.title": "استلم وسلّم",
      "how.driver.step3.desc": "اقبل الطلب، استلم من التاجر، وسلّم للعميل باستخدام الملاحة المدمجة",
      
      "how.driver.step4.title": "احصل على أجرك",
      "how.driver.step4.desc": "بعد إكمال التوصيل، يضاف المبلغ الكامل لمحفظتك فوراً - بدون أي عمولة!",
      
      // Commission Free
      "how.driver.commissionFree.title": "بدون عمولة - 100% لك!",
      "how.driver.commissionFree.desc": "نحن لا نأخذ أي عمولة من السائقين. كل المبلغ المحدد من التاجر يذهب إليك مباشرة. حريتك في العمل، وأرباحك كاملة لك!",
      
      // Testimonials
      "testimonials.title": "آراء عملائنا",
      "testimonials.subtitle": "ماذا يقول شركاؤنا عنا",
      
      // CTA Section
      "cta.title": "جاهز لتجربة الحرية؟",
      "cta.subtitle": "انضم إلى آلاف التجار والسائقين الذين اختاروا حُر للتوصيل",
      "cta.button": "ابدأ الآن مجاناً",
      
      // Footer
      "footer.about": "عن حُر",
      "footer.about.desc": "منصة توصيل عراقية مبتكرة تمنح الحرية الكاملة للتجار والسائقين",
      "footer.links": "روابط سريعة",
      "footer.contact": "تواصل معنا",
      "footer.download": "حمّل التطبيق",
      "footer.rights": "© 2025 حُر للتوصيل. جميع الحقوق محفوظة",
      
      // Roles
      "role.merchant": "للتجار",
      "role.driver": "للسائقين",
      "role.admin": "للإدارة",
      
      // Delete Account
      "deleteAccount.title": "حذف الحساب",
      "deleteAccount.subtitle": "اطلب حذف حسابك وبياناتك المرتبطة به",
      "deleteAccount.phoneLabel": "رقم الهاتف",
      "deleteAccount.phonePlaceholder": "+964 7XX XXX XXXX",
      "deleteAccount.phoneHint": "سيتم إرسال رمز التحقق إلى هذا الرقم عبر واتساب",
      "deleteAccount.otpLabel": "رمز التحقق",
      "deleteAccount.otpHint": "أدخل الرمز المكون من 6 أرقام الذي استلمته",
      "deleteAccount.sendOTP": "إرسال رمز التحقق",
      "deleteAccount.sending": "جاري الإرسال...",
      "deleteAccount.confirmDelete": "تأكيد حذف الحساب",
      "deleteAccount.deleting": "جاري الحذف...",
      "deleteAccount.back": "رجوع",
      "deleteAccount.warning.title": "تحذير مهم",
      "deleteAccount.warning.message": "حذف الحساب عملية نهائية ولا يمكن التراجع عنها. سيتم حذف جميع بياناتك المرتبطة بالحساب.",
      "deleteAccount.dataDeleted.title": "البيانات التي سيتم حذفها",
      "deleteAccount.dataDeleted.account": "معلومات الحساب والملف الشخصي",
      "deleteAccount.dataDeleted.profile": "بيانات المستخدم (الاسم، الهاتف، العنوان)",
      "deleteAccount.dataDeleted.orders": "سجل الطلبات والعمليات",
      "deleteAccount.dataDeleted.location": "بيانات الموقع والجلسات",
      "deleteAccount.dataDeleted.sessions": "جلسات تسجيل الدخول على جميع الأجهزة",
      "deleteAccount.dataKept.title": "البيانات المحفوظة لأغراض قانونية",
      "deleteAccount.dataKept.legal": "السجلات المالية المطلوبة قانونياً (لمدة 7 سنوات)",
      "deleteAccount.dataKept.analytics": "البيانات الإحصائية المجمعة (بدون معلومات شخصية)",
      "deleteAccount.retention": "ملاحظة: يتم الاحتفاظ ببعض البيانات لأغراض قانونية ومحاسبية لمدة 7 سنوات وفقاً للقوانين المحلية. لن يتم استخدام هذه البيانات لأي غرض آخر.",
      "deleteAccount.success.title": "تم حذف الحساب بنجاح",
      "deleteAccount.success.message": "تم حذف حسابك وبياناتك المرتبطة به بنجاح. نشكرك على استخدام تطبيق حر للتوصيل.",
      "deleteAccount.success.backHome": "العودة للصفحة الرئيسية",
      "deleteAccount.error.title": "حدث خطأ",
      "deleteAccount.error.message": "حدث خطأ أثناء محاولة حذف الحساب. يرجى المحاولة مرة أخرى أو الاتصال بالدعم.",
      "deleteAccount.error.tryAgain": "المحاولة مرة أخرى",
      "deleteAccount.errors.sendOTP": "فشل إرسال رمز التحقق",
      "deleteAccount.errors.delete": "فشل حذف الحساب",
      "deleteAccount.backToHome": "العودة للصفحة الرئيسية",
    }
  },
  en: {
    translation: {
      // Navigation
      "nav.home": "Home",
      "nav.how": "How It Works",
      "nav.testimonials": "Testimonials",
      "nav.download": "Download",
      "nav.privacy": "Privacy Policy",
      "nav.terms": "Terms & Conditions",
      "nav.deleteAccount": "Delete Account",
      
      // Hero Section
      "hero.title": "Hur Delivery",
      "hero.subtitle": "Freedom in Every Delivery",
      "hero.description": "A smart delivery platform that gives you complete freedom to manage your orders and deliveries. Join the free delivery revolution in Iraq",
      "hero.cta.download": "Download Now",
      "hero.cta.learn": "Learn More",
      
      
      // Features
      "features.title": "Exceptional Features",
      "features.subtitle": "Everything you need for a great delivery experience",
      
      "feature.freedom.title": "Complete Freedom",
      "feature.freedom.desc": "You control everything - your prices, your time, your decisions. No restrictions, no middlemen",
      
      "feature.instant.title": "Instant Delivery",
      "feature.instant.desc": "Smart system connects orders with the nearest available driver in seconds",
      
      "feature.tracking.title": "Live Tracking",
      "feature.tracking.desc": "Track your orders in real-time with instant notifications and accurate maps",
      
      "feature.secure.title": "Secure Payment",
      "feature.secure.desc": "Integrated digital wallet with safe and secure payment system",
      
      "feature.support.title": "24/7 Support",
      "feature.support.desc": "Support team available around the clock to help you anytime",
      
      "feature.analytics.title": "Detailed Reports",
      "feature.analytics.desc": "Comprehensive statistics to track your earnings and business performance",
      
      // Values
      "values.title": "Our Values",
      "values.subtitle": "The principles we believe in",
      
      "value.freedom.title": "Freedom",
      "value.freedom.desc": "We believe in everyone's right to make their own decisions and run their business freely without restrictions",
      
      "value.trust.title": "Trust",
      "value.trust.desc": "Building trust with our customers and partners is the foundation of our shared success",
      
      "value.innovation.title": "Innovation",
      "value.innovation.desc": "We constantly strive to develop innovative tech solutions that make everyone's life easier",
      
      "value.transparency.title": "Transparency",
      "value.transparency.desc": "Complete transparency in pricing, commissions, and services",
      
      // How It Works
      "how.title": "How It Works",
      "how.subtitle": "Four simple steps to get started",
      "how.tab.merchant": "For Merchants",
      "how.tab.driver": "For Drivers",
      
      // Merchant Steps
      "how.merchant.step1.title": "Register as Merchant",
      "how.merchant.step1.desc": "Sign up with your phone and create a merchant account in minutes",
      
      "how.merchant.step2.title": "Add Your Order",
      "how.merchant.step2.desc": "Enter delivery details, pickup and delivery locations with ease",
      
      "how.merchant.step3.title": "Driver Assignment",
      "how.merchant.step3.desc": "Our smart system automatically assigns the nearest available driver to your order",
      
      "how.merchant.step4.title": "Track & Complete",
      "how.merchant.step4.desc": "Track delivery in real-time until safe arrival and confirmation",
      
      // Driver Steps
      "how.driver.step1.title": "Register as Driver",
      "how.driver.step1.desc": "Sign up with your phone and submit required documents for approval",
      
      "how.driver.step2.title": "Browse Orders",
      "how.driver.step2.desc": "View all available orders in your area on the map",
      
      "how.driver.step3.title": "Pick Up & Deliver",
      "how.driver.step3.desc": "Accept order, pick up from merchant, and deliver to customer using integrated navigation",
      
      "how.driver.step4.title": "Get Your Payment",
      "how.driver.step4.desc": "After completing delivery, full amount is added to your wallet instantly - with zero commission!",
      
      // Commission Free
      "how.driver.commissionFree.title": "Zero Commission - 100% Yours!",
      "how.driver.commissionFree.desc": "We don't take any commission from drivers. The full amount set by the merchant goes directly to you. Your freedom to work, your full earnings!",
      
      // Testimonials
      "testimonials.title": "What Our Users Say",
      "testimonials.subtitle": "Feedback from our partners",
      
      // CTA Section
      "cta.title": "Ready to Experience Freedom?",
      "cta.subtitle": "Join thousands of merchants and drivers who chose Hur Delivery",
      "cta.button": "Start Now for Free",
      
      // Footer
      "footer.about": "About Hur",
      "footer.about.desc": "An innovative Iraqi delivery platform that gives complete freedom to merchants and drivers",
      "footer.links": "Quick Links",
      "footer.contact": "Contact Us",
      "footer.download": "Download App",
      "footer.rights": "© 2025 Hur Delivery. All rights reserved",
      
      // Roles
      "role.merchant": "For Merchants",
      "role.driver": "For Drivers",
      "role.admin": "For Admins",
      
      // Delete Account
      "deleteAccount.title": "Delete Account",
      "deleteAccount.subtitle": "Request deletion of your account and associated data",
      "deleteAccount.phoneLabel": "Phone Number",
      "deleteAccount.phonePlaceholder": "+964 7XX XXX XXXX",
      "deleteAccount.phoneHint": "A verification code will be sent to this number via WhatsApp",
      "deleteAccount.otpLabel": "Verification Code",
      "deleteAccount.otpHint": "Enter the 6-digit code you received",
      "deleteAccount.sendOTP": "Send Verification Code",
      "deleteAccount.sending": "Sending...",
      "deleteAccount.confirmDelete": "Confirm Account Deletion",
      "deleteAccount.deleting": "Deleting...",
      "deleteAccount.back": "Back",
      "deleteAccount.warning.title": "Important Warning",
      "deleteAccount.warning.message": "Account deletion is permanent and cannot be undone. All your associated data will be deleted.",
      "deleteAccount.dataDeleted.title": "Data That Will Be Deleted",
      "deleteAccount.dataDeleted.account": "Account information and profile",
      "deleteAccount.dataDeleted.profile": "User data (name, phone, address)",
      "deleteAccount.dataDeleted.orders": "Order history and transactions",
      "deleteAccount.dataDeleted.location": "Location data and sessions",
      "deleteAccount.dataDeleted.sessions": "Login sessions on all devices",
      "deleteAccount.dataKept.title": "Data Kept for Legal Purposes",
      "deleteAccount.dataKept.legal": "Financial records required by law (for 7 years)",
      "deleteAccount.dataKept.analytics": "Aggregated statistical data (without personal information)",
      "deleteAccount.retention": "Note: Some data is retained for legal and accounting purposes for 7 years in accordance with local laws. This data will not be used for any other purpose.",
      "deleteAccount.success.title": "Account Deleted Successfully",
      "deleteAccount.success.message": "Your account and associated data have been successfully deleted. Thank you for using Hur Delivery.",
      "deleteAccount.success.backHome": "Back to Home",
      "deleteAccount.error.title": "An Error Occurred",
      "deleteAccount.error.message": "An error occurred while attempting to delete the account. Please try again or contact support.",
      "deleteAccount.error.tryAgain": "Try Again",
      "deleteAccount.errors.sendOTP": "Failed to send verification code",
      "deleteAccount.errors.delete": "Failed to delete account",
      "deleteAccount.backToHome": "Back to Home",
    }
  }
};

i18n
  .use(initReactI18next)
  .init({
    resources,
    lng: 'ar',
    fallbackLng: 'ar',
    interpolation: {
      escapeValue: false
    }
  });

export default i18n;

