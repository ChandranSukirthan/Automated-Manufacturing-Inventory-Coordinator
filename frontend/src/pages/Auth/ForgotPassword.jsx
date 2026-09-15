import { useState, useRef, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { Mail, Lock, AlertCircle, CheckCircle2, Loader2, Timer, Eye, EyeOff } from 'lucide-react';
import AuthLayout from '../../components/Auth/AuthLayout';
import authService from '../../services/authService';

const STEPS = { EMAIL: 'email', OTP: 'otp', NEW_PASSWORD: 'new_password' };
const OTP_EXPIRY_SECONDS = 180; // 3 minutes

export default function ForgotPassword() {
  const navigate = useNavigate();
  const [step, setStep] = useState(STEPS.EMAIL);

  // Shared state
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  // Step 1 — Email
  const [emailInput, setEmailInput] = useState('');

  // Step 2 — OTP
  const [otp, setOtp] = useState(['', '', '', '', '', '']);
  const [timeLeft, setTimeLeft] = useState(OTP_EXPIRY_SECONDS);
  const isExpired = timeLeft <= 0;
  const [resendSuccess, setResendSuccess] = useState('');
  const inputRefs = useRef([]);

  // Step 3 — New password
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showNew, setShowNew] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [successMsg, setSuccessMsg] = useState('');

  // OTP countdown
  useEffect(() => {
    if (step !== STEPS.OTP) return;
    if (timeLeft <= 0) return;
    const id = setInterval(() => setTimeLeft((t) => t - 1), 1000);
    return () => clearInterval(id);
  }, [timeLeft, step]);

  const formatTime = (s) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;

  // ---- Step 1: Submit email ----
  const handleEmailSubmit = async (e) => {
    e.preventDefault();
    setError('');
    if (!emailInput.includes('@')) { setError('Please enter a valid email address.'); return; }
    setLoading(true);
    try {
      await authService.forgotPassword(emailInput.trim().toLowerCase());
      setEmail(emailInput.trim().toLowerCase());
      setStep(STEPS.OTP);
    } catch (err) {
      setError(err.response?.data?.message || 'Something went wrong. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  // ---- Step 2: OTP input helpers ----
  const handleOtpChange = (index, value) => {
    if (isNaN(value)) return;
    const next = [...otp];
    next[index] = value;
    setOtp(next);
    setError('');
    if (value !== '' && index < 5) inputRefs.current[index + 1]?.focus();
  };

  const handleOtpKeyDown = (index, e) => {
    if (e.key === 'Backspace' && !otp[index] && index > 0) inputRefs.current[index - 1]?.focus();
  };

  const handleOtpSubmit = (e) => {
    e.preventDefault();
    if (isExpired) return;
    const code = otp.join('');
    if (code.length < 6) { setError('Please enter all 6 digits.'); return; }
    setError('');
    // Move to set-password step, keep email & code in state
    setStep(STEPS.NEW_PASSWORD);
  };

  const handleResend = async () => {
    setError('');
    setResendSuccess('');
    setLoading(true);
    try {
      await authService.forgotPassword(email);
      setOtp(['', '', '', '', '', '']);
      setTimeLeft(OTP_EXPIRY_SECONDS);
      setResendSuccess('A new code has been sent to your email.');
      setTimeout(() => inputRefs.current[0]?.focus(), 100);
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to resend. Please wait before trying again.');
    } finally {
      setLoading(false);
    }
  };

  // ---- Step 3: Reset password ----
  const handleResetSubmit = async (e) => {
    e.preventDefault();
    setError('');
    if (newPassword.length < 8) { setError('Password must be at least 8 characters.'); return; }
    if (newPassword !== confirmPassword) { setError('Passwords do not match.'); return; }
    setLoading(true);
    try {
      await authService.resetPassword(email, otp.join(''), newPassword);
      setSuccessMsg('Password reset successfully!');
      setTimeout(() => navigate('/login', { state: { message: 'Password reset! Please log in with your new password.' } }), 1800);
    } catch (err) {
      setError(err.response?.data?.message || 'Invalid or expired code. Please start over.');
    } finally {
      setLoading(false);
    }
  };

  // ---- Renders ----
  if (step === STEPS.EMAIL) {
    return (
      <AuthLayout title="Forgot Password" subtitle="Enter your email and we'll send a reset code">
        <form onSubmit={handleEmailSubmit} className="space-y-4">
          {error && (
            <div className="flex items-center gap-2 p-3 rounded-lg bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
              <AlertCircle className="w-4 h-4 shrink-0" />
              <span>{error}</span>
            </div>
          )}
          <div className="space-y-1">
            <label className="text-sm font-medium text-slate-300 ml-1">Email Address</label>
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-slate-500">
                <Mail className="w-5 h-5" />
              </div>
              <input
                type="text"
                value={emailInput}
                onChange={(e) => { setEmailInput(e.target.value); if (error) setError(''); }}
                className="w-full pl-10 pr-4 py-2.5 bg-slate-900/50 border border-slate-700 rounded-xl focus:ring-2 focus:ring-brand-500 focus:border-brand-500 transition-all text-white placeholder-slate-500"
                placeholder="Enter your registered email"
                autoFocus
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full flex items-center justify-center gap-2 py-2.5 px-4 bg-gradient-to-r from-brand-600 to-cyan-600 hover:from-brand-500 hover:to-cyan-500 text-white font-semibold rounded-xl transition-all shadow-[0_0_15px_rgba(255,255,255,0.1)] hover:shadow-[0_0_25px_rgba(255,255,255,0.2)] hover:-translate-y-0.5 disabled:opacity-70 disabled:hover:translate-y-0"
          >
            {loading ? <><Loader2 className="w-5 h-5 animate-spin" /> Sending...</> : 'Send Reset Code'}
          </button>

          <p className="text-center text-slate-400 text-sm mt-4">
            Remember your password?{' '}
            <Link to="/login" className="text-white font-medium hover:text-brand-400 transition-colors">Sign in</Link>
          </p>
        </form>
      </AuthLayout>
    );
  }

  if (step === STEPS.OTP) {
    return (
      <AuthLayout title="Enter Reset Code" subtitle={`We sent a 6-digit code to ${email}`}>
        <form onSubmit={handleOtpSubmit} className="space-y-6">
          {error && (
            <div className="flex items-center gap-2 p-3 rounded-lg bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
              <AlertCircle className="w-4 h-4 shrink-0" />
              <span>{error}</span>
            </div>
          )}
          {resendSuccess && (
            <div className="flex items-center gap-2 p-3 rounded-lg bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-sm">
              <CheckCircle2 className="w-4 h-4 shrink-0" />
              <span>{resendSuccess}</span>
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
                onChange={(e) => handleOtpChange(index, e.target.value)}
                onKeyDown={(e) => handleOtpKeyDown(index, e)}
                disabled={isExpired}
                className={`w-10 h-12 sm:w-12 sm:h-14 text-center text-xl sm:text-2xl font-bold bg-slate-900/50 border rounded-xl focus:ring-2 focus:ring-brand-500 transition-all text-white
                  ${isExpired ? 'border-red-500/50 opacity-50 cursor-not-allowed' : 'border-slate-700 focus:border-brand-500'}`}
              />
            ))}
          </div>

          <div className="flex items-center justify-center gap-2 text-sm font-medium">
            <Timer className={`w-5 h-5 ${timeLeft < 30 ? 'text-red-400 animate-pulse' : 'text-slate-400'}`} />
            <span className={timeLeft < 30 ? 'text-red-400' : 'text-slate-300'}>{formatTime(timeLeft)}</span>
          </div>

          <button
            type="submit"
            disabled={isExpired || loading}
            className={`w-full py-2.5 px-4 font-semibold rounded-xl transition-all flex items-center justify-center gap-2
              ${isExpired ? 'bg-slate-800 text-slate-500 cursor-not-allowed'
                : 'bg-gradient-to-r from-brand-600 to-cyan-600 hover:from-brand-500 hover:to-cyan-500 text-white shadow-[0_0_15px_rgba(255,255,255,0.1)] hover:shadow-[0_0_25px_rgba(255,255,255,0.2)] hover:-translate-y-0.5'}`}
          >
            Continue
          </button>

          <p className="text-center text-slate-400 text-sm">
            Didn't receive the code?{' '}
            <button type="button" onClick={handleResend} disabled={loading}
              className="text-white font-medium hover:text-brand-400 transition-colors disabled:opacity-50">
              {loading ? 'Sending...' : 'Resend Code'}
            </button>
          </p>
        </form>
      </AuthLayout>
    );
  }

  // Step 3: New password
  return (
    <AuthLayout title="Set New Password" subtitle="Choose a strong password for your account">
      <form onSubmit={handleResetSubmit} className="space-y-4">
        {error && (
          <div className="flex items-center gap-2 p-3 rounded-lg bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
            <AlertCircle className="w-4 h-4 shrink-0" />
            <span>{error}</span>
          </div>
        )}
        {successMsg && (
          <div className="flex items-center gap-2 p-3 rounded-lg bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-sm">
            <CheckCircle2 className="w-4 h-4 shrink-0" />
            <span>{successMsg}</span>
          </div>
        )}

        <div className="space-y-1">
          <label className="text-sm font-medium text-slate-300 ml-1">New Password</label>
          <div className="relative">
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-slate-500">
              <Lock className="w-5 h-5" />
            </div>
            <input
              type={showNew ? 'text' : 'password'}
              value={newPassword}
              onChange={(e) => { setNewPassword(e.target.value); if (error) setError(''); }}
              className="w-full pl-10 pr-12 py-2.5 bg-slate-900/50 border border-slate-700 rounded-xl focus:ring-2 focus:ring-brand-500 focus:border-brand-500 transition-all text-white placeholder-slate-500"
              placeholder="At least 8 characters"
              autoFocus
            />
            <button type="button" onClick={() => setShowNew(!showNew)}
              className="absolute inset-y-0 right-0 pr-3 flex items-center text-slate-400 hover:text-slate-300">
              {showNew ? <Eye className="w-5 h-5" /> : <EyeOff className="w-5 h-5" />}
            </button>
          </div>
        </div>

        <div className="space-y-1">
          <label className="text-sm font-medium text-slate-300 ml-1">Confirm Password</label>
          <div className="relative">
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-slate-500">
              <Lock className="w-5 h-5" />
            </div>
            <input
              type={showConfirm ? 'text' : 'password'}
              value={confirmPassword}
              onChange={(e) => { setConfirmPassword(e.target.value); if (error) setError(''); }}
              className="w-full pl-10 pr-12 py-2.5 bg-slate-900/50 border border-slate-700 rounded-xl focus:ring-2 focus:ring-brand-500 focus:border-brand-500 transition-all text-white placeholder-slate-500"
              placeholder="••••••••"
            />
            <button type="button" onClick={() => setShowConfirm(!showConfirm)}
              className="absolute inset-y-0 right-0 pr-3 flex items-center text-slate-400 hover:text-slate-300">
              {showConfirm ? <Eye className="w-5 h-5" /> : <EyeOff className="w-5 h-5" />}
            </button>
          </div>
        </div>

        <button
          type="submit"
          disabled={loading || !!successMsg}
          className="w-full flex items-center justify-center gap-2 py-2.5 px-4 mt-2 bg-gradient-to-r from-brand-600 to-cyan-600 hover:from-brand-500 hover:to-cyan-500 text-white font-semibold rounded-xl transition-all shadow-[0_0_15px_rgba(255,255,255,0.1)] hover:shadow-[0_0_25px_rgba(255,255,255,0.2)] hover:-translate-y-0.5 disabled:opacity-70 disabled:hover:translate-y-0"
        >
          {loading ? <><Loader2 className="w-5 h-5 animate-spin" /> Resetting...</> : 'Reset Password'}
        </button>
      </form>
    </AuthLayout>
  );
}
