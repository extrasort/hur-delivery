import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useTranslation } from 'react-i18next';
import { FiMenu, FiX, FiGlobe, FiInstagram } from 'react-icons/fi';
import { FaWhatsapp } from 'react-icons/fa';
import '../styles/Navbar.css';

const Navbar = () => {
  const { t, i18n } = useTranslation();
  const [isScrolled, setIsScrolled] = useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 50);
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const toggleLanguage = () => {
    const newLang = i18n.language === 'ar' ? 'en' : 'ar';
    i18n.changeLanguage(newLang);
    document.body.className = newLang === 'ar' ? 'rtl' : 'ltr';
  };

  const navItems = [
    { key: 'home', label: t('nav.home'), href: '#home' },
    { key: 'how', label: t('nav.how'), href: '#how' },
    { key: 'testimonials', label: t('nav.testimonials'), href: '#testimonials' },
  ];

  return (
    <motion.nav
      className={`navbar ${isScrolled ? 'scrolled' : ''}`}
      initial={{ y: -100 }}
      animate={{ y: 0 }}
      transition={{ duration: 0.6, ease: 'easeOut' }}
    >
      <div className="container navbar-container">
        {/* Logo */}
        <motion.div 
          className="navbar-logo"
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
        >
          <img src="/icon.png" alt="Hur" className="navbar-logo-icon" />
          <div className="navbar-logo-text">
            <span className="logo-text">حُر</span>
            <span className="logo-subtitle">للتوصيل</span>
          </div>
        </motion.div>

        {/* Desktop Menu */}
        <ul className="navbar-menu desktop-menu">
          {navItems.map((item, index) => (
            <motion.li
              key={item.key}
              initial={{ opacity: 0, y: -20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.1 }}
            >
              <a href={item.href} className="nav-link">
                {item.label}
              </a>
            </motion.li>
          ))}
        </ul>

        {/* Actions */}
        <div className="navbar-actions">
          {/* Social Media Buttons - Consistent sizes */}
          <motion.a
            href="https://www.instagram.com/hur.delivery"
            target="_blank"
            rel="noopener noreferrer"
            className="social-btn instagram-btn"
            whileHover={{ scale: 1.1 }}
            whileTap={{ scale: 0.9 }}
            transition={{ duration: 0.3 }}
            title="Instagram"
          >
            <FiInstagram />
          </motion.a>

          <motion.a
            href="https://wa.me/9647701234567"
            target="_blank"
            rel="noopener noreferrer"
            className="social-btn whatsapp-btn"
            whileHover={{ scale: 1.1 }}
            whileTap={{ scale: 0.9 }}
            transition={{ duration: 0.3 }}
            title="WhatsApp"
          >
            <FaWhatsapp />
          </motion.a>

          <motion.button
            className="lang-toggle"
            onClick={toggleLanguage}
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            transition={{ duration: 0.3 }}
          >
            <FiGlobe />
            <span>{i18n.language === 'ar' ? 'EN' : 'ع'}</span>
          </motion.button>

          <motion.a
            href="#download"
            className="btn-primary"
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
          >
            {t('nav.download')}
          </motion.a>

          {/* Mobile Menu Toggle */}
          <button
            className="mobile-menu-toggle"
            onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
          >
            {isMobileMenuOpen ? <FiX /> : <FiMenu />}
          </button>
        </div>
      </div>

      {/* Mobile Menu */}
      <AnimatePresence>
        {isMobileMenuOpen && (
          <motion.div
            className="mobile-menu"
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            transition={{ duration: 0.3 }}
          >
            <ul>
              {navItems.map((item) => (
                <motion.li
                  key={item.key}
                  whileHover={{ x: i18n.language === 'ar' ? -10 : 10 }}
                >
                  <a
                    href={item.href}
                    onClick={() => setIsMobileMenuOpen(false)}
                  >
                    {item.label}
                  </a>
                </motion.li>
              ))}
            </ul>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.nav>
  );
};

export default Navbar;

