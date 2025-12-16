import { motion } from 'framer-motion';
import { useTranslation } from 'react-i18next';
import { FiDownload, FiArrowDown } from 'react-icons/fi';
import { RiMotorbikeFill } from 'react-icons/ri';
import { MdStore, MdTrendingUp } from 'react-icons/md';
import '../styles/Hero.css';

const Hero = () => {
  const { t, i18n } = useTranslation();
  const isRTL = i18n.language === 'ar';

  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        delayChildren: 0.3,
        staggerChildren: 0.2
      }
    }
  };

  const itemVariants = {
    hidden: { y: 50, opacity: 0 },
    visible: {
      y: 0,
      opacity: 1,
      transition: {
        duration: 0.8,
        ease: [0.6, -0.05, 0.01, 0.99]
      }
    }
  };

  const floatingIcons = [
    { Icon: RiMotorbikeFill, delay: 0, color: '#008C95' },
    { Icon: MdStore, delay: 0.5, color: '#1E40AF' },
    { Icon: MdTrendingUp, delay: 1, color: '#F59E0B' }
  ];


  return (
    <section className="hero" id="home">
      <div className="hero-background">
        <div className="gradient-orb orb-1"></div>
        <div className="gradient-orb orb-2"></div>
        <div className="gradient-orb orb-3"></div>
      </div>

      <div className="container hero-container">
        {/* Mobile Features Header */}
        <div className="mobile-features-header">
          <img src="/icon.png" alt="Hur" className="mobile-app-logo" />
          <h3 className="mobile-app-title">حُر للتوصيل</h3>
          <p className="mobile-app-subtitle">تطبيق التوصيل الأفضل في العراق</p>
        </div>
        <motion.div
          className="hero-content"
          variants={containerVariants}
          initial="hidden"
          animate="visible"
        >
          {/* Badge */}
          <motion.div
            className="hero-badge"
            variants={itemVariants}
            whileHover={{ scale: 1.05 }}
          >
            <span className="badge-dot"></span>
            <span>{t('hero.subtitle')}</span>
          </motion.div>

          {/* Main Title */}
          <motion.h1
            className="hero-title"
            variants={itemVariants}
          >
            <span className="title-main">{t('hero.title')}</span>
            <motion.span
              className="title-gradient"
              animate={{
                backgroundPosition: ['0% 50%', '100% 50%', '0% 50%'],
              }}
              transition={{
                duration: 5,
                ease: 'linear',
                repeat: Infinity,
              }}
            >
              {t('hero.subtitle')}
            </motion.span>
          </motion.h1>

          {/* Description */}
          <motion.p
            className="hero-description"
            variants={itemVariants}
          >
            {t('hero.description')}
          </motion.p>

          {/* CTA Buttons */}
          <motion.div
            className="hero-cta"
            variants={itemVariants}
          >
            <motion.a
              href="#download"
              className="btn-hero primary"
              whileHover={{ scale: 1.05, boxShadow: '0 10px 40px rgba(0, 140, 149, 0.3)' }}
              whileTap={{ scale: 0.95 }}
            >
              <FiDownload />
              <span>{t('hero.cta.download')}</span>
            </motion.a>

            <motion.a
              href="#features"
              className="btn-hero secondary"
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
            >
              <span>{t('hero.cta.learn')}</span>
              <FiArrowDown />
            </motion.a>
          </motion.div>

          {/* Floating Icons */}
          <div className="floating-icons">
            {floatingIcons.map(({ Icon, delay, color }, index) => (
              <motion.div
                key={index}
                className="floating-icon"
                style={{ '--icon-color': color }}
                initial={{ scale: 0, rotate: -180 }}
                animate={{
                  scale: 1,
                  rotate: 0,
                  y: [0, -20, 0],
                }}
                transition={{
                  scale: { delay, duration: 0.6 },
                  rotate: { delay, duration: 0.6 },
                  y: {
                    delay: delay + 0.6,
                    duration: 3,
                    repeat: Infinity,
                    ease: 'easeInOut',
                  },
                }}
              >
                <Icon />
              </motion.div>
            ))}
          </div>
        </motion.div>

        {/* Desktop Hero Illustration */}
        <motion.div
          className="hero-illustration desktop-only"
          initial={{ opacity: 0, scale: 0.8, x: isRTL ? -100 : 100 }}
          animate={{ opacity: 1, scale: 1, x: 0 }}
          transition={{ duration: 1, delay: 0.3 }}
        >
          <motion.div
            className="phone-mockup"
            animate={{
              y: [0, -20, 0],
            }}
            transition={{
              duration: 4,
              repeat: Infinity,
              ease: 'easeInOut',
            }}
          >
            <div className="phone-screen">
              <div className="app-preview">
                {/* Logo Header Section */}
                <motion.div
                  className="preview-logo-section"
                  initial={{ scale: 0, opacity: 0 }}
                  animate={{ scale: 1, opacity: 1 }}
                  transition={{ delay: 1, type: 'spring' }}
                >
                  <img src="/icon.png" alt="Hur" className="preview-app-logo" />
                  <motion.h2 
                    className="preview-app-name"
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 1.2 }}
                  >
                    {i18n.language === 'ar' ? 'حُر للتوصيل' : 'Hur Delivery'}
                  </motion.h2>
                  <motion.div 
                    className="preview-status"
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ delay: 1.4 }}
                  >
                    <span className="status-dot"></span>
                    <span>{i18n.language === 'ar' ? 'متصل' : 'Online'}</span>
                  </motion.div>
                </motion.div>
                
                {/* Orders Section */}
                <motion.div
                  className="preview-orders-section"
                  initial={{ opacity: 0, y: 30 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 1.5 }}
                >
                  <div className="orders-title">
                    {i18n.language === 'ar' ? 'الطلبات النشطة' : 'Active Orders'}
                  </div>
                  
                  <div className="preview-card">
                    <div className="card-icon">📦</div>
                    <div className="card-info">
                      <h4>{i18n.language === 'ar' ? 'طلب جديد' : 'New Order'}</h4>
                      <p>{i18n.language === 'ar' ? 'التوصيل خلال 20 دقيقة' : 'Delivery in 20 min'}</p>
                    </div>
                    <div className="card-badge new">{i18n.language === 'ar' ? 'جديد' : 'New'}</div>
                  </div>
                  
                  <div className="preview-card">
                    <div className="card-icon">🏍️</div>
                    <div className="card-info">
                      <h4>{i18n.language === 'ar' ? 'قيد التوصيل' : 'In Delivery'}</h4>
                      <p>{i18n.language === 'ar' ? '5 دقائق متبقية' : '5 min remaining'}</p>
                    </div>
                    <div className="card-badge active">{i18n.language === 'ar' ? 'نشط' : 'Active'}</div>
                  </div>
                </motion.div>
              </div>
            </div>
            <div className="phone-notch"></div>
          </motion.div>

          {/* Decorative Elements */}
          <motion.div
            className="decoration-circle circle-1"
            animate={{
              scale: [1, 1.2, 1],
              rotate: [0, 180, 360],
            }}
            transition={{
              duration: 8,
              repeat: Infinity,
              ease: 'linear',
            }}
          />
          <motion.div
            className="decoration-circle circle-2"
            animate={{
              scale: [1, 1.3, 1],
              rotate: [0, -180, -360],
            }}
            transition={{
              duration: 10,
              repeat: Infinity,
              ease: 'linear',
            }}
          />
        </motion.div>

      </div>

      {/* Scroll Indicator */}
      <motion.div
        className="scroll-indicator"
        animate={{ y: [0, 10, 0] }}
        transition={{
          duration: 1.5,
          repeat: Infinity,
          ease: 'easeInOut',
        }}
      >
        <FiArrowDown />
      </motion.div>
    </section>
  );
};

export default Hero;

