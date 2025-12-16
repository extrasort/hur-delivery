import { motion, useInView } from 'framer-motion';
import { useRef } from 'react';
import { useTranslation } from 'react-i18next';
import {
  FiUnlock,
  FiZap,
  FiMapPin,
  FiShield,
  FiHeadphones,
  FiBarChart2,
} from 'react-icons/fi';
import '../styles/Features.css';

const Features = () => {
  const { t } = useTranslation();
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true, margin: '-100px' });

  const features = [
    {
      icon: FiUnlock,
      title: t('feature.freedom.title'),
      description: t('feature.freedom.desc'),
      color: '#008C95',
      gradient: 'linear-gradient(135deg, #008C95, #00ADB5)',
    },
    {
      icon: FiZap,
      title: t('feature.instant.title'),
      description: t('feature.instant.desc'),
      color: '#1E40AF',
      gradient: 'linear-gradient(135deg, #1E40AF, #3B82F6)',
    },
    {
      icon: FiMapPin,
      title: t('feature.tracking.title'),
      description: t('feature.tracking.desc'),
      color: '#10B981',
      gradient: 'linear-gradient(135deg, #10B981, #34D399)',
    },
    {
      icon: FiShield,
      title: t('feature.secure.title'),
      description: t('feature.secure.desc'),
      color: '#8B5CF6',
      gradient: 'linear-gradient(135deg, #8B5CF6, #A78BFA)',
    },
    {
      icon: FiHeadphones,
      title: t('feature.support.title'),
      description: t('feature.support.desc'),
      color: '#F59E0B',
      gradient: 'linear-gradient(135deg, #F59E0B, #FBBF24)',
    },
    {
      icon: FiBarChart2,
      title: t('feature.analytics.title'),
      description: t('feature.analytics.desc'),
      color: '#EF4444',
      gradient: 'linear-gradient(135deg, #EF4444, #F87171)',
    },
  ];

  return (
    <section className="features-section" id="features" ref={ref}>
      <div className="container">
        {/* Section Header */}
        <motion.div
          className="section-header"
          initial={{ opacity: 0, y: 30 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.6 }}
        >
          <motion.h2
            className="section-title"
            animate={isInView ? {
              backgroundPosition: ['0% 50%', '100% 50%', '0% 50%'],
            } : {}}
            transition={{
              duration: 5,
              ease: 'linear',
              repeat: Infinity,
            }}
          >
            {t('features.title')}
          </motion.h2>
          <p className="section-subtitle">{t('features.subtitle')}</p>
        </motion.div>

        {/* Features Grid */}
        <div className="features-grid">
          {features.map((feature, index) => (
            <motion.div
              key={index}
              className="feature-card"
              initial={{ opacity: 0, y: 50 }}
              animate={isInView ? { opacity: 1, y: 0 } : {}}
              transition={{
                duration: 0.6,
                delay: index * 0.1,
                ease: [0.6, -0.05, 0.01, 0.99]
              }}
              whileHover={{
                y: -10,
                transition: { duration: 0.3 }
              }}
            >
              <motion.div
                className="feature-icon-wrapper"
                style={{ background: feature.gradient }}
                whileHover={{
                  rotate: [0, -10, 10, -10, 0],
                  scale: 1.1,
                }}
                transition={{ duration: 0.5 }}
              >
                <feature.icon className="feature-icon" />
              </motion.div>

              <h3 className="feature-title">{feature.title}</h3>
              <p className="feature-description">{feature.description}</p>

              <motion.div
                className="feature-glow"
                style={{ background: feature.gradient }}
                animate={{
                  opacity: [0, 0.3, 0],
                  scale: [0.8, 1.2, 0.8],
                }}
                transition={{
                  duration: 3,
                  repeat: Infinity,
                  ease: 'easeInOut',
                }}
              />
            </motion.div>
          ))}
        </div>
      </div>

      {/* Background Decorations */}
      <div className="features-decoration">
        <motion.div
          className="decoration-blob blob-1"
          animate={{
            x: [0, 100, 0],
            y: [0, -100, 0],
            rotate: [0, 180, 360],
          }}
          transition={{
            duration: 20,
            repeat: Infinity,
            ease: 'linear',
          }}
        />
        <motion.div
          className="decoration-blob blob-2"
          animate={{
            x: [0, -100, 0],
            y: [0, 100, 0],
            rotate: [0, -180, -360],
          }}
          transition={{
            duration: 25,
            repeat: Infinity,
            ease: 'linear',
          }}
        />
      </div>
    </section>
  );
};

export default Features;



