import { motion, useInView } from 'framer-motion';
import { useRef } from 'react';
import { useTranslation } from 'react-i18next';
import { FiDownload, FiArrowRight, FiArrowLeft } from 'react-icons/fi';
import { RiGooglePlayFill, RiAppStoreFill } from 'react-icons/ri';
import '../styles/CTA.css';

const CTA = () => {
  const { t, i18n } = useTranslation();
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true });
  const isRTL = i18n.language === 'ar';
  const ArrowIcon = isRTL ? FiArrowLeft : FiArrowRight;

  return (
    <section className="cta-section" id="download" ref={ref}>
      <div className="cta-background">
        <motion.div
          className="cta-orb orb-1"
          animate={{
            scale: [1, 1.2, 1],
            opacity: [0.3, 0.6, 0.3],
          }}
          transition={{
            duration: 4,
            repeat: Infinity,
            ease: 'easeInOut',
          }}
        />
        <motion.div
          className="cta-orb orb-2"
          animate={{
            scale: [1, 1.3, 1],
            opacity: [0.2, 0.5, 0.2],
          }}
          transition={{
            duration: 5,
            repeat: Infinity,
            ease: 'easeInOut',
          }}
        />
      </div>

      <div className="container">
        <motion.div
          className="cta-content"
          initial={{ opacity: 0, y: 50 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.8 }}
        >
          <motion.div
            className="cta-badge"
            initial={{ scale: 0 }}
            animate={isInView ? { scale: 1 } : {}}
            transition={{ delay: 0.2, type: 'spring' }}
          >
            <FiDownload />
            <span>{t('nav.download')}</span>
          </motion.div>

          <motion.h2
            className="cta-title"
            initial={{ opacity: 0, y: 30 }}
            animate={isInView ? { opacity: 1, y: 0 } : {}}
            transition={{ delay: 0.3, duration: 0.6 }}
          >
            {t('cta.title')}
          </motion.h2>

          <motion.p
            className="cta-subtitle"
            initial={{ opacity: 0, y: 30 }}
            animate={isInView ? { opacity: 1, y: 0 } : {}}
            transition={{ delay: 0.4, duration: 0.6 }}
          >
            {t('cta.subtitle')}
          </motion.p>

          <motion.div
            className="cta-buttons"
            initial={{ opacity: 0, y: 30 }}
            animate={isInView ? { opacity: 1, y: 0 } : {}}
            transition={{ delay: 0.5, duration: 0.6 }}
          >
            <motion.button
              className="cta-button primary"
              whileHover={{ scale: 1.05, boxShadow: '0 10px 40px rgba(0, 140, 149, 0.4)' }}
              whileTap={{ scale: 0.95 }}
            >
              <span>{t('cta.button')}</span>
              <ArrowIcon />
            </motion.button>

            <div className="store-buttons">
              <motion.a
                href="#"
                className="store-button"
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
              >
                <RiGooglePlayFill className="store-icon" />
                <div className="store-text">
                  <span className="store-label">{i18n.language === 'ar' ? 'حمّل من' : 'Get it on'}</span>
                  <span className="store-name">Google Play</span>
                </div>
              </motion.a>

              <motion.a
                href="#"
                className="store-button"
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
              >
                <RiAppStoreFill className="store-icon" />
                <div className="store-text">
                  <span className="store-label">{i18n.language === 'ar' ? 'حمّل من' : 'Download on'}</span>
                  <span className="store-name">App Store</span>
                </div>
              </motion.a>
            </div>
          </motion.div>

          {/* Floating Icons */}
          <motion.div
            className="cta-float-icon icon-1"
            animate={{
              y: [0, -20, 0],
              rotate: [0, 10, 0],
            }}
            transition={{
              duration: 3,
              repeat: Infinity,
              ease: 'easeInOut',
            }}
          >
            📦
          </motion.div>
          <motion.div
            className="cta-float-icon icon-2"
            animate={{
              y: [0, -15, 0],
              rotate: [0, -10, 0],
            }}
            transition={{
              duration: 4,
              repeat: Infinity,
              ease: 'easeInOut',
            }}
          >
            🏍️
          </motion.div>
          <motion.div
            className="cta-float-icon icon-3"
            animate={{
              y: [0, -25, 0],
              rotate: [0, 15, 0],
            }}
            transition={{
              duration: 3.5,
              repeat: Infinity,
              ease: 'easeInOut',
            }}
          >
            ⚡
          </motion.div>
        </motion.div>
      </div>
    </section>
  );
};

export default CTA;



