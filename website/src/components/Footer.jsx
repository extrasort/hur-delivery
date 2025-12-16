import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { useTranslation } from 'react-i18next';
import {
  FiFacebook,
  FiTwitter,
  FiInstagram,
  FiLinkedin,
  FiMail,
  FiPhone,
  FiMapPin,
} from 'react-icons/fi';
import '../styles/Footer.css';
import { getSupportPhone } from '../config/supabase';

const Footer = () => {
  const { t, i18n } = useTranslation();
  const isRTL = i18n.language === 'ar';
  const [supportPhone, setSupportPhone] = useState('+964 770 123 4567');

  useEffect(() => {
    // Fetch support phone from database
    getSupportPhone().then(phone => {
      if (phone) {
        setSupportPhone(phone);
      }
    });
  }, []);

  const socialLinks = [
    { icon: FiFacebook, href: '#', color: '#1877F2' },
    { icon: FiTwitter, href: '#', color: '#1DA1F2' },
    { icon: FiInstagram, href: '#', color: '#E4405F' },
    { icon: FiLinkedin, href: '#', color: '#0A66C2' },
  ];

  const quickLinks = [
    { label: t('nav.home'), href: '#home' },
    { label: t('nav.how'), href: '#how' },
    { label: t('nav.testimonials'), href: '#testimonials' },
    { label: t('nav.download'), href: '#download' },
    { label: t('nav.privacy'), href: '/legal/privacy-policy.html' },
    { label: t('nav.terms'), href: '/legal/terms.html' },
    { label: t('nav.deleteAccount'), href: '/delete-account' },
  ];

  return (
    <footer className="footer">
      <div className="container">
        <div className="footer-content">
          {/* Brand Section */}
          <div className="footer-section brand">
            <motion.div
              className="footer-logo"
              whileHover={{ scale: 1.05 }}
            >
              <img src="/icon.png" alt="Hur" className="footer-logo-icon" />
              <div className="footer-logo-text">
                <span className="logo-text">حُر</span>
                <span className="logo-subtitle">للتوصيل</span>
              </div>
            </motion.div>
            <p className="footer-description">
              {t('footer.about.desc')}
            </p>
            <div className="social-links">
              {socialLinks.map((social, index) => (
                <motion.a
                  key={index}
                  href={social.href}
                  className="social-link"
                  style={{ '--social-color': social.color }}
                  whileHover={{ scale: 1.2, rotate: 5 }}
                  whileTap={{ scale: 0.9 }}
                >
                  <social.icon />
                </motion.a>
              ))}
            </div>
          </div>

          {/* Quick Links */}
          <div className="footer-section">
            <h3 className="footer-title">{t('footer.links')}</h3>
            <ul className="footer-links">
              {quickLinks.map((link, index) => (
                <motion.li
                  key={index}
                  whileHover={{ x: isRTL ? -5 : 5 }}
                >
                  <a href={link.href}>{link.label}</a>
                </motion.li>
              ))}
            </ul>
          </div>

          {/* Contact Info */}
          <div className="footer-section">
            <h3 className="footer-title">{t('footer.contact')}</h3>
            <ul className="footer-contact">
              <li>
                <FiMail />
                <span>info@hurdelivery.iq</span>
              </li>
              <li>
                <FiPhone />
                <span dir="ltr">{supportPhone}</span>
              </li>
              <li>
                <FiMapPin />
                <span>{i18n.language === 'ar' ? 'بغداد، العراق' : 'Baghdad, Iraq'}</span>
              </li>
            </ul>
          </div>

          {/* Download Section */}
          <div className="footer-section">
            <h3 className="footer-title">{t('footer.download')}</h3>
            <div className="footer-badges">
              <motion.a
                href="#"
                className="badge-link"
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
              >
                <img 
                  src="https://upload.wikimedia.org/wikipedia/commons/7/78/Google_Play_Store_badge_EN.svg" 
                  alt="Google Play"
                />
              </motion.a>
              <motion.a
                href="#"
                className="badge-link"
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
              >
                <img 
                  src="https://upload.wikimedia.org/wikipedia/commons/3/3c/Download_on_the_App_Store_Badge.svg" 
                  alt="App Store"
                />
              </motion.a>
            </div>
          </div>
        </div>

        {/* Bottom Bar */}
        <div className="footer-bottom">
          <motion.p
            className="copyright"
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
          >
            {t('footer.rights')}
          </motion.p>
        </div>
      </div>

      {/* Animated Background */}
      <div className="footer-decoration">
        <motion.div
          className="decoration-line"
          initial={{ scaleX: 0 }}
          whileInView={{ scaleX: 1 }}
          viewport={{ once: true }}
          transition={{ duration: 1.5 }}
        />
      </div>
    </footer>
  );
};

export default Footer;

