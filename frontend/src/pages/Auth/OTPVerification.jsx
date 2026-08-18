import React, { useState, useEffect, useRef } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { ShieldCheck, Timer, AlertCircle, Loader2 } from 'lucide-react';
import AuthLayout from '../../components/Auth/AuthLayout';
import authService from '../../services/authService';

export default function OTPVerification() {
  const navigate = useNavigate();
  const location = useLocation();
  const email = location.state?.email || 'user@amic.com';

  const [otp, setOtp] = useState(['', '', '', '', '', '']);
  const [timeLeft, setTimeLeft] = useState(180); // 3 minutes
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [isExpired, setIsExpired] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');
  const inputRefs = useRef([]);

  useEffect(() => {
    if (timeLeft <= 0) {
      setIsExpired(true);
      setError('OTP has expired. Please request a new one.');
      return;
    }

    const timerId = setInterval(() => {
      setTimeLeft((prev) => prev - 1);
    }, 1000);

    return () => clearInterval(timerId);
  }, [timeLeft]);

  const formatTime = (seconds) => {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  const handleChange = (index, value) => {
    if (isNaN(value)) return;
    
    const newOtp = [...otp];
    newOtp[index] = value;
    setOtp(newOtp);
    setError('');

    // Auto-focus next input
    if (value !== '' && index < 5) {
      inputRefs.current[index + 1]?.focus();
    }
  };

  const handleKeyDown = (index, e) => {
    if (e.key === 'Backspace' && !otp[index] && index > 0) {
      inputRefs.current[index - 1]?.focus();
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (isExpired) return;

    const enteredOtp = otp.join('');
    if (enteredOtp.length < 6) {
      setError('Please enter all 6 digits.');
      return;
    }

    setError('');
    setLoading(true);
    try {
      const response = await authService.verifyOtp(email, enteredOtp);
      navigate('/login', { state: { message: response.message || 'Account verified successfully. Please log in.' } });
    } catch (err) {
      setError(err.response?.data?.message || 'Invalid or expired OTP.');
    } finally {
      setLoading(false);
    }
  };

  const handleResend = async () => {
    setError('');
    setSuccessMessage('');
    try {
      await authService.resendOtp(email);
      setOtp(['', '', '', '', '', '']);
      setTimeLeft(180);
      setIsExpired(false);
      setSuccessMessage('A new verification code has been sent to your email.');
      setTimeout(() => inputRefs.current[0]?.focus(), 100);
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to resend OTP. Please try again.');
    }
  };

  return (
    <AuthLayout title="Verify Email" subtitle={`We sent a code to ${email}`}>
      <form onSubmit={handleSubmit} className="space-y-6">
        
        {error && (
          <div className="flex items-center gap-2 p-3 rounded-lg bg-red-500/10 border border-red-500/20 text-red-400 text-sm animate-in fade-in slide-in-from-top-2">
            <AlertCircle className="w-4 h-4 shrink-0" />
            <span>{error}</span>
          </div>
        )}
        
        {successMessage && (
          <div className="flex items-center gap-2 p-3 rounded-lg bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-sm animate-in fade-in slide-in-from-top-2">
            <ShieldCheck className="w-4 h-4 shrink-0" />
            <span>{successMessage}</span>
          </div>
        )}

        <div className="flex justify-center gap-2 sm:gap-3">
          {otp.map((digit, index) => (
            <input
              key={index}
              ref={(el) => (inputRefs.current[index] = el)}
              type="text"
              maxLength={1}
              value={digit}
              onChange={(e) => handleChange(index, e.target.value)}
              onKeyDown={(e) => handleKeyDown(index, e)}
              disabled={isExpired}
              className={`w-10 h-12 sm:w-12 sm:h-14 text-center text-xl sm:text-2xl font-bold bg-slate-900/50 border rounded-xl focus:ring-2 focus:ring-brand-500 transition-all text-white
                ${isExpired ? 'border-red-500/50 opacity-50 cursor-not-allowed' : 'border-slate-700 focus:border-brand-500'}`}
            />
          ))}
        </div>

        <div className="flex items-center justify-center gap-2 text-sm font-medium">
          <Timer className={`w-5 h-5 ${timeLeft < 30 ? 'text-red-400 animate-pulse' : 'text-slate-400'}`} />
          <span className={timeLeft < 30 ? 'text-red-400' : 'text-slate-300'}>
            {formatTime(timeLeft)}
          </span>
        </div>

        <button
          type="submit"
          disabled={isExpired || loading}
          className={`w-full py-2.5 px-4 font-semibold rounded-xl transition-all flex items-center justify-center gap-2
            ${isExpired || loading
              ? 'bg-slate-800 text-slate-500 cursor-not-allowed' 
              : 'bg-gradient-to-r from-brand-600 to-cyan-600 hover:from-brand-500 hover:to-cyan-500 text-white shadow-[0_0_15px_rgba(255,255,255,0.1)] hover:shadow-[0_0_25px_rgba(255,255,255,0.2)] hover:-translate-y-0.5'}`}
        >
          {loading ? (
            <>
              <Loader2 className="w-5 h-5 animate-spin" />
              Verifying...
            </>
          ) : (
            <>
              <ShieldCheck className="w-5 h-5" />
              Verify Account
            </>
          )}
        </button>

        <p className="text-center text-slate-400 text-sm mt-4">
          Didn't receive the code?{' '}
          <button 
            type="button" 
            onClick={handleResend}
            className="text-white font-medium hover:text-brand-400 transition-colors"
          >
            Resend Code
          </button>
        </p>
      </form>
    </AuthLayout>
  );
}
