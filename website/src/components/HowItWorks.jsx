import { motion, useInView } from 'framer-motion';
import { useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { 
  FiUserPlus, 
  FiPackage, 
  FiMapPin, 
  FiCheckCircle,
  FiTruck,
  FiDollarSign,
  FiSmartphone
} from 'react-icons/fi';
import '../styles/HowItWorks.css';

const HowItWorks = () => {
  const { t, i18n } = useTranslation();
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true, margin: '-100px' });
  const [activeTab, setActiveTab] = useState('driver');

  const merchantSteps = [
    {
      icon: FiUserPlus,
      title: t('how.merchant.step1.title'),
      description: t('how.merchant.step1.desc'),
      color: '#008C95',
    },
    {
      icon: FiPackage,
      title: t('how.merchant.step2.title'),
      description: t('how.merchant.step2.desc'),
      color: '#1E40AF',
    },
    {
      icon: FiTruck,
      title: t('how.merchant.step3.title'),
      description: t('how.merchant.step3.desc'),
      color: '#F59E0B',
    },
    {
      icon: FiCheckCircle,
      title: t('how.merchant.step4.title'),
      description: t('how.merchant.step4.desc'),
      color: '#10B981',
    },
  ];

  const driverSteps = [
    {
      icon: FiSmartphone,
      title: t('how.driver.step1.title'),
      description: t('how.driver.step1.desc'),
      color: '#008C95',
    },
    {
      icon: FiMapPin,
      title: t('how.driver.step2.title'),
      description: t('how.driver.step2.desc'),
      color: '#1E40AF',
    },
    {
      icon: FiTruck,
      title: t('how.driver.step3.title'),
      description: t('how.driver.step3.desc'),
      color: '#F59E0B',
    },
    {
      icon: FiDollarSign,
      title: t('how.driver.step4.title'),
      description: t('how.driver.step4.desc'),
      color: '#10B981',
    },
  ];

  const steps = activeTab === 'merchant' ? merchantSteps : driverSteps;

  return (
    <section className="how-it-works" id="how" ref={ref}>
      <div className="container">
        {/* Section Header */}
        <motion.div
          className="section-header"
          initial={{ opacity: 0, y: 30 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.6 }}
        >
          <h2 className="section-title">{t('how.title')}</h2>
          <p className="section-subtitle">{t('how.subtitle')}</p>
        </motion.div>

        {/* Tab Selector */}
        <motion.div
          className="tabs-container"
          initial={{ opacity: 0, y: 20 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.6, delay: 0.2 }}
        >
          <button
            className={`tab-button ${activeTab === 'merchant' ? 'active' : ''}`}
            onClick={() => setActiveTab('merchant')}
          >
            <FiPackage />
            <span>{t('how.tab.merchant')}</span>
          </button>
          <button
            className={`tab-button ${activeTab === 'driver' ? 'active' : ''}`}
            onClick={() => setActiveTab('driver')}
          >
            <FiTruck />
            <span>{t('how.tab.driver')}</span>
          </button>
        </motion.div>

        {/* Steps */}
        <div className="steps-container">
          {steps.map((step, index) => (
            <motion.div
              key={`${activeTab}-${index}`}
              className="step"
              initial={{ opacity: 0, y: 50 }}
              animate={isInView ? { opacity: 1, y: 0 } : {}}
              transition={{
                duration: 0.6,
                delay: index * 0.15 + 0.4,
                ease: 'easeOut'
              }}
            >
              <motion.div
                className="step-number"
                style={{ '--step-color': step.color }}
                whileHover={{ scale: 1.2, rotate: 360 }}
                transition={{ duration: 0.6 }}
              >
                {index + 1}
              </motion.div>

              <motion.div
                className="step-icon"
                style={{ '--step-color': step.color }}
                whileHover={{
                  y: -10,
                  rotate: [0, -10, 10, -10, 0],
                }}
                transition={{ duration: 0.5 }}
              >
                <step.icon />
              </motion.div>

              <div className="step-content">
                <h3 className="step-title">{step.title}</h3>
                <p className="step-description">{step.description}</p>
              </div>

              {index < steps.length - 1 && (
                <motion.div
                  className="step-connector"
                  initial={{ scaleX: 0 }}
                  animate={isInView ? { scaleX: 1 } : {}}
                  transition={{
                    duration: 0.6,
                    delay: index * 0.15 + 0.6,
                  }}
                  style={{
                    transformOrigin: i18n.language === 'ar' ? 'right' : 'left'
                  }}
                >
                  <motion.div
                    className="connector-dot"
                    animate={{
                      x: i18n.language === 'ar' ? [0, -50, -100] : [0, 50, 100],
                      opacity: [1, 0.5, 1],
                    }}
                    transition={{
                      duration: 2,
                      repeat: Infinity,
                      ease: 'linear',
                    }}
                  />
                </motion.div>
              )}
            </motion.div>
          ))}
        </div>

        {/* Commission-Free Highlight for Drivers */}
        {activeTab === 'driver' && (
          <motion.div
            className="commission-free-banner"
            initial={{ opacity: 0, y: 30 }}
            animate={isInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 1 }}
          >
            <div className="banner-icon">⚡</div>
            <div className="banner-content">
              <h3>{t('how.driver.commissionFree.title')}</h3>
              <p>{t('how.driver.commissionFree.desc')}</p>
            </div>
          </motion.div>
        )}
      </div>
    </section>
  );
};

export default HowItWorks;
