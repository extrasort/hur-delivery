import { motion, useInView } from 'framer-motion';
import { useRef } from 'react';
import { useTranslation } from 'react-i18next';
import { FiHeart, FiTrendingUp, FiEye, FiAward } from 'react-icons/fi';
import '../styles/Values.css';

const Values = () => {
  const { t } = useTranslation();
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true, margin: '-100px' });

  const values = [
    {
      icon: FiHeart,
      title: t('value.freedom.title'),
      description: t('value.freedom.desc'),
      color: '#008C95',
    },
    {
      icon: FiAward,
      title: t('value.trust.title'),
      description: t('value.trust.desc'),
      color: '#1E40AF',
    },
    {
      icon: FiTrendingUp,
      title: t('value.innovation.title'),
      description: t('value.innovation.desc'),
      color: '#F59E0B',
    },
    {
      icon: FiEye,
      title: t('value.transparency.title'),
      description: t('value.transparency.desc'),
      color: '#10B981',
    },
  ];

  return (
    <section className="values-section" id="about" ref={ref}>
      <div className="container">
        {/* Section Header */}
        <motion.div
          className="section-header"
          initial={{ opacity: 0, y: 30 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.6 }}
        >
          <h2 className="section-title">{t('values.title')}</h2>
          <p className="section-subtitle">{t('values.subtitle')}</p>
        </motion.div>

        {/* Values Grid */}
        <div className="values-grid">
          {values.map((value, index) => (
            <motion.div
              key={index}
              className="value-card"
              initial={{ opacity: 0, scale: 0.8 }}
              animate={isInView ? { opacity: 1, scale: 1 } : {}}
              transition={{
                duration: 0.6,
                delay: index * 0.15,
                ease: [0.6, -0.05, 0.01, 0.99]
              }}
              whileHover={{
                scale: 1.05,
                rotateY: 5,
                transition: { duration: 0.3 }
              }}
            >
              <div className="value-content">
                <motion.div
                  className="value-icon"
                  style={{ '--value-color': value.color }}
                  whileHover={{
                    rotate: [0, -15, 15, -15, 0],
                    scale: 1.2,
                  }}
                  transition={{ duration: 0.5 }}
                >
                  <value.icon />
                </motion.div>

                <h3 className="value-title">{value.title}</h3>
                <p className="value-description">{value.description}</p>
              </div>

              <motion.div
                className="value-shimmer"
                animate={{
                  x: ['-200%', '200%'],
                }}
                transition={{
                  duration: 3,
                  repeat: Infinity,
                  ease: 'linear',
                  repeatDelay: 2,
                }}
              />
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
};

export default Values;



