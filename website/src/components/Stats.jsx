import { motion, useInView } from 'framer-motion';
import { useRef, useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { FiTruck, FiUsers, FiShoppingBag, FiMapPin } from 'react-icons/fi';
import '../styles/Stats.css';

const AnimatedCounter = ({ end, duration = 2 }) => {
  const [count, setCount] = useState(0);
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true });

  useEffect(() => {
    if (!isInView) return;

    let startTime;
    let animationFrame;

    const animate = (currentTime) => {
      if (!startTime) startTime = currentTime;
      const progress = Math.min((currentTime - startTime) / (duration * 1000), 1);
      
      setCount(Math.floor(progress * end));

      if (progress < 1) {
        animationFrame = requestAnimationFrame(animate);
      }
    };

    animationFrame = requestAnimationFrame(animate);

    return () => {
      if (animationFrame) {
        cancelAnimationFrame(animationFrame);
      }
    };
  }, [isInView, end, duration]);

  return <span ref={ref}>{count.toLocaleString()}</span>;
};

const Stats = () => {
  const { t } = useTranslation();
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true, margin: '-100px' });

  const stats = [
    {
      icon: FiTruck,
      value: 50000,
      label: t('stats.deliveries'),
      color: '#008C95',
      suffix: '+'
    },
    {
      icon: FiUsers,
      value: 2500,
      label: t('stats.drivers'),
      color: '#1E40AF',
      suffix: '+'
    },
    {
      icon: FiShoppingBag,
      value: 1200,
      label: t('stats.merchants'),
      color: '#F59E0B',
      suffix: '+'
    },
    {
      icon: FiMapPin,
      value: 15,
      label: t('stats.cities'),
      color: '#10B981',
      suffix: ''
    },
  ];

  return (
    <section className="stats-section" ref={ref}>
      <div className="container">
        <div className="stats-grid">
          {stats.map((stat, index) => (
            <motion.div
              key={index}
              className="stat-card"
              initial={{ opacity: 0, y: 50 }}
              animate={isInView ? { opacity: 1, y: 0 } : {}}
              transition={{
                duration: 0.6,
                delay: index * 0.1,
                ease: 'easeOut'
              }}
              whileHover={{
                y: -10,
                boxShadow: '0 20px 40px rgba(0,0,0,0.1)'
              }}
            >
              <motion.div
                className="stat-icon"
                style={{ '--stat-color': stat.color }}
                whileHover={{ rotate: 360, scale: 1.1 }}
                transition={{ duration: 0.6 }}
              >
                <stat.icon />
              </motion.div>
              
              <div className="stat-content">
                <h3 className="stat-value">
                  <AnimatedCounter end={stat.value} />
                  {stat.suffix}
                </h3>
                <p className="stat-label">{stat.label}</p>
              </div>

              <motion.div
                className="stat-glow"
                style={{ '--stat-color': stat.color }}
                animate={{
                  opacity: [0.3, 0.6, 0.3],
                  scale: [1, 1.2, 1],
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
    </section>
  );
};

export default Stats;



