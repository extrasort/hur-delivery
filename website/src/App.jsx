import { useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { BrowserRouter as Router, Routes, Route, useLocation } from 'react-router-dom';
import Navbar from './components/Navbar';
import Hero from './components/Hero';
import HowItWorks from './components/HowItWorks';
import Testimonials from './components/Testimonials';
import CTA from './components/CTA';
import Footer from './components/Footer';
import DeleteAccount from './components/DeleteAccount';
import ParticlesBackground from './components/ParticlesBackground';
import ScrollToTop from './components/ScrollToTop';

function Home() {
  return (
    <>
      <Hero />
      <HowItWorks />
      {/* Testimonials removed - no fake reviews */}
      <CTA />
    </>
  );
}

function AppContent() {
  const { i18n } = useTranslation();
  const location = useLocation();
  const isDeleteAccountPage = location.pathname === '/delete-account';
  
  useEffect(() => {
    // Set body direction based on language
    document.body.className = i18n.language === 'ar' ? 'rtl' : 'ltr';
    document.documentElement.lang = i18n.language;
    document.documentElement.dir = i18n.language === 'ar' ? 'rtl' : 'ltr';
  }, [i18n.language]);

  useEffect(() => {
    // Smooth scroll behavior
    document.documentElement.style.scrollBehavior = 'smooth';
    
    // Handle hash links
    const handleHashClick = (e) => {
      const href = e.target.closest('a')?.getAttribute('href');
      if (href?.startsWith('#')) {
        e.preventDefault();
        const element = document.querySelector(href);
        if (element) {
          element.scrollIntoView({ behavior: 'smooth' });
        }
      }
    };

    document.addEventListener('click', handleHashClick);
    return () => document.removeEventListener('click', handleHashClick);
  }, []);

  return (
    <div className="app">
      {!isDeleteAccountPage && <ParticlesBackground />}
      {!isDeleteAccountPage && <Navbar />}
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/delete-account" element={<DeleteAccount />} />
      </Routes>
      {!isDeleteAccountPage && <Footer />}
      {!isDeleteAccountPage && <ScrollToTop />}
    </div>
  );
}

function App() {
  return (
    <Router>
      <AppContent />
    </Router>
  );
}

export default App;

