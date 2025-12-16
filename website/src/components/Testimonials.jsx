import { motion, useInView } from 'framer-motion';
import { useRef } from 'react';
import { useTranslation } from 'react-i18next';
import { FiStar } from 'react-icons/fi';
import '../styles/Testimonials.css';

const Testimonials = () => {
  const { t, i18n } = useTranslation();
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true, margin: '-100px' });

  const testimonials = [
    {
      name: i18n.language === 'ar' ? 'أحمد محمد' : 'Ahmed Mohammed',
      role: i18n.language === 'ar' ? 'صاحب متجر' : 'Store Owner',
      image: '👨‍💼',
      content: i18n.language === 'ar' 
        ? 'حُر غيّر طريقة عملي بالكامل. الحرية في تحديد الأسعار والتحكم بالطلبات جعلت أرباحي تزيد بشكل كبير'
        : 'Hur completely changed the way I work. The freedom to set prices and control orders significantly increased my profits',
      rating: 5,
    },
    {
      name: i18n.language === 'ar' ? 'علي حسن' : 'Ali Hassan',
      role: i18n.language === 'ar' ? 'سائق توصيل' : 'Delivery Driver',
      image: '🏍️',
      content: i18n.language === 'ar'
        ? 'أفضل شيء أنه بدون عمولة! أخيراً تطبيق يحترم السائقين. دفع سريع ودعم ممتاز'
        : 'Best thing is it\'s commission-free! Finally an app that respects drivers. Fast payment and excellent support',
      rating: 5,
    },
    {
      name: i18n.language === 'ar' ? 'فاطمة علي' : 'Fatima Ali',
      role: i18n.language === 'ar' ? 'صاحبة مطعم' : 'Restaurant Owner',
      image: '👩‍🍳',
      content: i18n.language === 'ar'
        ? 'تطبيق احترافي وسهل الاستخدام. التتبع المباشر والإشعارات الفورية توفر لي راحة البال'
        : 'Professional and easy-to-use app. Live tracking and instant notifications give me peace of mind',
      rating: 5,
    },
  ];

  return (
    <section className="testimonials-section" id="testimonials" ref={ref}>
      <div className="container">
        {/* Section Header */}
        <motion.div
          className="section-header"
          initial={{ opacity: 0, y: 30 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.6 }}
        >
          <h2 className="section-title">{t('testimonials.title')}</h2>
          <p className="section-subtitle">{t('testimonials.subtitle')}</p>
        </motion.div>

        {/* Testimonials Grid */}
        <div className="testimonials-grid">
          {testimonials.map((testimonial, index) => (
            <motion.div
              key={index}
              className="testimonial-card"
              initial={{ opacity: 0, y: 50 }}
              animate={isInView ? { opacity: 1, y: 0 } : {}}
              transition={{
                duration: 0.6,
                delay: index * 0.15,
                ease: 'easeOut'
              }}
              whileHover={{
                y: -10,
                boxShadow: '0 20px 40px rgba(0,0,0,0.15)'
              }}
            >
              <div className="quote-icon">"</div>

              <div className="rating">
                {[...Array(testimonial.rating)].map((_, i) => (
                  <motion.div
                    key={i}
                    initial={{ opacity: 0, scale: 0 }}
                    animate={isInView ? { opacity: 1, scale: 1 } : {}}
                    transition={{
                      delay: index * 0.15 + i * 0.1,
                      duration: 0.3
                    }}
                  >
                    <FiStar className="star" />
                  </motion.div>
                ))}
              </div>

              <p className="testimonial-content">{testimonial.content}</p>

              <div className="testimonial-author">
                <div className="author-avatar">{testimonial.image}</div>
                <div className="author-info">
                  <h4 className="author-name">{testimonial.name}</h4>
                  <p className="author-role">{testimonial.role}</p>
                </div>
              </div>

              <motion.div
                className="card-glow"
                animate={{
                  opacity: [0, 0.3, 0],
                  scale: [0.8, 1.2, 0.8],
                }}
                transition={{
                  duration: 3,
                  repeat: Infinity,
                  ease: 'easeInOut',
                  delay: index * 0.5,
                }}
              />
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
};

export default Testimonials;

