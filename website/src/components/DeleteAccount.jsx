import { useState } from 'react';
import { motion } from 'framer-motion';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router-dom';
import { FiPhone, FiShield, FiAlertCircle, FiCheckCircle, FiX, FiHome } from 'react-icons/fi';
import '../styles/DeleteAccount.css';
import { supabase } from '../config/supabase';

const SUPABASE_URL = 'https://bvtoxmmiitznagsbubhg.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2dG94bW1paXR6bmFnc2J1YmhnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwNzk5MTcsImV4cCI6MjA2NzY1NTkxN30.WjdQh_cvOebwL0TG0bzDLZimWCLC4YuP__jtvBD_xv0';

const DeleteAccount = () => {
  const { t, i18n } = useTranslation();
  const isRTL = i18n.language === 'ar';
  
  const [phoneNumber, setPhoneNumber] = useState('');
  const [otpCode, setOtpCode] = useState('');
  const [step, setStep] = useState('phone'); // 'phone', 'otp', 'confirm', 'success', 'error'
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  const normalizePhone = (input) => {
    let cleaned = input.replace(/\D/g, '');
    if (cleaned.startsWith('0')) cleaned = `964${cleaned.slice(1)}`;
    if (!cleaned.startsWith('964')) cleaned = `964${cleaned}`;
    return cleaned;
  };

  const handleSendOTP = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const normalizedPhone = normalizePhone(phoneNumber);
      
      // Send OTP via Edge Function
      const response = await fetch(`${SUPABASE_URL}/functions/v1/otp-handler`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        },
        body: JSON.stringify({
          action: 'send',
          phoneNumber: normalizedPhone,
          purpose: 'delete_account',
        }),
      });

      const data = await response.json();

      if (!response.ok || !data.success) {
        throw new Error(data.error || 'Failed to send OTP');
      }

      setStep('otp');
    } catch (err) {
      setError(err.message || t('deleteAccount.errors.sendOTP'));
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyAndDelete = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const normalizedPhone = normalizePhone(phoneNumber);
      
      // Verify OTP and delete account via Edge Function
      const response = await fetch(`${SUPABASE_URL}/functions/v1/delete-account`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        },
        body: JSON.stringify({
          phoneNumber: normalizedPhone,
          code: otpCode,
        }),
      });

      const data = await response.json();

      if (!response.ok || !data.success) {
        throw new Error(data.error || 'Failed to delete account');
      }

      setStep('success');
      setSuccess(true);
    } catch (err) {
      setError(err.message || t('deleteAccount.errors.delete'));
      setStep('error');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="delete-account-page">
      {/* Simple Header */}
      <div className="delete-account-page-header">
        <Link to="/" className="back-home-link">
          <FiHome />
          <span>{t('deleteAccount.backToHome')}</span>
        </Link>
      </div>
      
      <div className="container">
        <motion.div
          className="delete-account-content"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
        >
          {/* Header */}
          <div className="delete-account-header">
            <motion.div
              className="delete-icon"
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              transition={{ delay: 0.2, type: 'spring' }}
            >
              <FiShield />
            </motion.div>
            <h1>{t('deleteAccount.title')}</h1>
            <p className="subtitle">{t('deleteAccount.subtitle')}</p>
          </div>

          {/* Warning Box */}
          {step !== 'success' && (
            <motion.div
              className="warning-box"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.3 }}
            >
              <FiAlertCircle className="warning-icon" />
              <div>
                <h3>{t('deleteAccount.warning.title')}</h3>
                <p>{t('deleteAccount.warning.message')}</p>
              </div>
            </motion.div>
          )}

          {/* What Gets Deleted */}
          {step === 'phone' && (
            <motion.div
              className="data-info-box"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.4 }}
            >
              <h3>{t('deleteAccount.dataDeleted.title')}</h3>
              <ul>
                <li>{t('deleteAccount.dataDeleted.account')}</li>
                <li>{t('deleteAccount.dataDeleted.profile')}</li>
                <li>{t('deleteAccount.dataDeleted.orders')}</li>
                <li>{t('deleteAccount.dataDeleted.location')}</li>
                <li>{t('deleteAccount.dataDeleted.sessions')}</li>
              </ul>
              
              <h3 style={{ marginTop: '2rem' }}>{t('deleteAccount.dataKept.title')}</h3>
              <ul>
                <li>{t('deleteAccount.dataKept.legal')}</li>
                <li>{t('deleteAccount.dataKept.analytics')}</li>
              </ul>
              
              <p className="retention-note">
                {t('deleteAccount.retention')}
              </p>
            </motion.div>
          )}

          {/* Phone Input Step */}
          {step === 'phone' && (
            <motion.form
              className="delete-account-form"
              onSubmit={handleSendOTP}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.5 }}
            >
              <div className="form-group">
                <label htmlFor="phone">
                  <FiPhone /> {t('deleteAccount.phoneLabel')}
                </label>
                <input
                  type="tel"
                  id="phone"
                  value={phoneNumber}
                  onChange={(e) => setPhoneNumber(e.target.value)}
                  placeholder={t('deleteAccount.phonePlaceholder')}
                  required
                  dir="ltr"
                />
                <small>{t('deleteAccount.phoneHint')}</small>
              </div>

              {error && (
                <div className="error-message">
                  <FiAlertCircle /> {error}
                </div>
              )}

              <button type="submit" className="btn-primary" disabled={loading}>
                {loading ? t('deleteAccount.sending') : t('deleteAccount.sendOTP')}
              </button>
            </motion.form>
          )}

          {/* OTP Verification Step */}
          {step === 'otp' && (
            <motion.form
              className="delete-account-form"
              onSubmit={handleVerifyAndDelete}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.2 }}
            >
              <div className="form-group">
                <label htmlFor="otp">{t('deleteAccount.otpLabel')}</label>
                <input
                  type="text"
                  id="otp"
                  value={otpCode}
                  onChange={(e) => setOtpCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                  placeholder="000000"
                  required
                  maxLength={6}
                  dir="ltr"
                  className="otp-input"
                />
                <small>{t('deleteAccount.otpHint')}</small>
              </div>

              {error && (
                <div className="error-message">
                  <FiAlertCircle /> {error}
                </div>
              )}

              <div className="button-group">
                <button
                  type="button"
                  className="btn-secondary"
                  onClick={() => setStep('phone')}
                  disabled={loading}
                >
                  {t('deleteAccount.back')}
                </button>
                <button type="submit" className="btn-danger" disabled={loading || otpCode.length !== 6}>
                  {loading ? t('deleteAccount.deleting') : t('deleteAccount.confirmDelete')}
                </button>
              </div>
            </motion.form>
          )}

          {/* Success Step */}
          {step === 'success' && (
            <motion.div
              className="success-box"
              initial={{ scale: 0.8, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              transition={{ type: 'spring', delay: 0.2 }}
            >
              <FiCheckCircle className="success-icon" />
              <h2>{t('deleteAccount.success.title')}</h2>
              <p>{t('deleteAccount.success.message')}</p>
              <a href="/" className="btn-primary">
                {t('deleteAccount.success.backHome')}
              </a>
            </motion.div>
          )}

          {/* Error Step */}
          {step === 'error' && (
            <motion.div
              className="error-box"
              initial={{ scale: 0.8, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
            >
              <FiX className="error-icon" />
              <h2>{t('deleteAccount.error.title')}</h2>
              <p>{error || t('deleteAccount.error.message')}</p>
              <button
                className="btn-primary"
                onClick={() => {
                  setStep('phone');
                  setError('');
                  setOtpCode('');
                }}
              >
                {t('deleteAccount.error.tryAgain')}
              </button>
            </motion.div>
          )}
        </motion.div>
      </div>
    </div>
  );
};

export default DeleteAccount;

