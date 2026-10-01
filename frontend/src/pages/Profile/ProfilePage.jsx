import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  User,
  Mail,
  Shield,
  CheckCircle2,
  AlertTriangle,
  Loader2,
  Save,
  ArrowLeft
} from 'lucide-react';
import { useAuth } from '../../context/useAuth';
import authService from '../../services/authService';
import { parseErrorMessage } from '../../utils/errorHandler';
import QALayout from '../../components/Layout/QALayout';
import PageHeader from '../../components/QA/PageHeader';

export default function ProfilePage() {
  const navigate = useNavigate();
  const { user, updateProfile } = useAuth();
  const [profile, setProfile] = useState(user);
  const [fullName, setFullName] = useState(user?.fullName || '');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    const loadProfile = async () => {
      try {
        const data = await authService.getProfile();
        setProfile(data);
        setFullName(data.fullName || '');
      } catch (err) {
        setError(parseErrorMessage(err, 'Unable to load your profile.'));
      } finally {
        setLoading(false);
      }
    };

    loadProfile();
  }, []);

  const handleSubmit = async (event) => {
    event.preventDefault();
    if (!fullName.trim()) {
      setError('Name is required.');
      setMessage('');
      return;
    }

    setSaving(true);
    setError('');
    setMessage('');
    try {
      const updatedUser = await updateProfile(fullName.trim());
      setProfile(updatedUser);
      setFullName(updatedUser.fullName);
      setMessage('Profile updated successfully.');
    } catch (err) {
      setError(parseErrorMessage(err, 'Unable to update your profile.'));
    } finally {
      setSaving(false);
    }
  };

  const roleStr = String(user?.role ?? '').toLowerCase();
  const isQA = roleStr === 'qualityinspector' || roleStr === '2';

  const getRoleDisplay = (r) => {
    const s = String(r ?? '').toLowerCase();
    if (s === 'qualityinspector' || s === '2') return 'Quality Inspector';
    if (s === 'floorworker' || s === '0') return 'Floor Worker';
    if (s === 'supplychainmanager' || s === '1') return 'Supply Chain Manager';
    if (s === 'itadmin' || s === '3') return 'IT Admin';
    return r || 'Standard User';
  };

  const roleLabel = getRoleDisplay(profile?.role || user?.role);

  if (loading) {
    const loadingView = (
      <div className="flex flex-col items-center justify-center py-24 text-slate-400 space-y-3">
        <Loader2 className="w-8 h-8 animate-spin text-purple-400" />
        <p className="text-sm font-medium">Loading profile credentials...</p>
      </div>
    );
    return isQA ? (
      <QALayout title="Account Profile" subtitle="Account information">
        <div className="p-6 lg:p-8 max-w-7xl mx-auto">{loadingView}</div>
      </QALayout>
    ) : (
      <div className="min-h-screen bg-slate-950 text-slate-100 p-8">{loadingView}</div>
    );
  }

  const profileContent = (
    <div className="space-y-6 max-w-3xl">
      {/* Page Header */}
      <PageHeader
        category="Account"
        title="Profile"
        subtitle="Account information"
        actions={
          <button
            onClick={() => navigate(-1)}
            className="px-4 py-2.5 rounded-xl border border-slate-700 bg-slate-900/60 text-slate-200 text-sm font-medium hover:bg-slate-800 hover:text-white transition-all shadow-sm flex items-center gap-2"
          >
            <ArrowLeft className="w-4 h-4" />
            <span>Back</span>
          </button>
        }
      />

      {/* Alert Notifications */}
      {error && (
        <div
          role="alert"
          className="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-rose-200 flex items-center gap-3"
        >
          <AlertTriangle className="w-5 h-5 text-rose-400 shrink-0" />
          <span className="text-sm font-medium">{error}</span>
        </div>
      )}

      {message && (
        <div
          role="status"
          className="rounded-2xl border border-purple-500/30 bg-purple-500/10 p-4 text-purple-200 flex items-center gap-3"
        >
          <CheckCircle2 className="w-5 h-5 text-purple-400 shrink-0" />
          <span className="text-sm font-medium">{message}</span>
        </div>
      )}

      {/* Account Information Card */}
      <div className="rounded-3xl border border-slate-800 bg-slate-900/60 backdrop-blur-sm p-8 space-y-8 shadow-sm">
        {/* User Identity Header */}
        <div className="flex items-center gap-5 border-b border-slate-800/80 pb-6">
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-purple-500 to-violet-600 flex items-center justify-center text-2xl font-bold text-white shadow-lg shadow-purple-500/20 shrink-0">
            {fullName ? fullName.charAt(0).toUpperCase() : <User className="w-8 h-8" />}
          </div>
          <div className="min-w-0">
            <h2 className="text-xl font-bold text-white tracking-tight truncate">
              {fullName || 'Quality Inspector'}
            </h2>
            <p className="text-sm text-slate-400 truncate">{profile?.email || '—'}</p>
            <div className="mt-2">
              <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-purple-500/10 text-purple-300 border border-purple-500/30 uppercase tracking-wide">
                <Shield className="w-3 h-3" />
                <span>{roleLabel}</span>
              </span>
            </div>
          </div>
        </div>

        {/* Profile Edit Form */}
        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Full Name */}
          <div>
            <label
              htmlFor="profile-name"
              className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2"
            >
              Full Name
            </label>
            <div className="relative">
              <User className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
              <input
                id="profile-name"
                value={fullName}
                onChange={(e) => setFullName(e.target.value)}
                placeholder="Your full name"
                className="w-full rounded-xl bg-slate-950 border border-slate-700 pl-10 pr-4 py-3 text-sm text-white placeholder:text-slate-500 outline-none focus:border-purple-500 transition-colors"
                maxLength={200}
              />
            </div>
          </div>

          {/* Email (Read-only) */}
          <div>
            <label
              htmlFor="profile-email"
              className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2"
            >
              Email Address
            </label>
            <div className="relative">
              <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
              <input
                id="profile-email"
                value={profile?.email || ''}
                readOnly
                disabled
                className="w-full rounded-xl bg-slate-950/60 border border-slate-800/80 pl-10 pr-4 py-3 text-sm text-slate-400 cursor-not-allowed select-all"
              />
            </div>
            <p className="text-xs text-slate-500 mt-2">
              Email is managed by the authentication system.
            </p>
          </div>

          {/* Role (Read-only) */}
          <div>
            <label
              htmlFor="profile-role"
              className="block text-xs font-bold uppercase tracking-wider text-slate-400 mb-2"
            >
              Assigned Role
            </label>
            <div className="relative">
              <Shield className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
              <input
                id="profile-role"
                value={roleLabel}
                readOnly
                disabled
                className="w-full rounded-xl bg-slate-950/60 border border-slate-800/80 pl-10 pr-4 py-3 text-sm text-slate-400 cursor-not-allowed"
              />
            </div>
          </div>

          {/* Form Actions */}
          <div className="pt-2">
            <button
              type="submit"
              disabled={saving}
              className="px-6 py-3 rounded-xl bg-purple-600 text-white font-bold text-sm hover:bg-purple-500 disabled:opacity-60 transition-all shadow-lg shadow-purple-600/25 flex items-center gap-2"
            >
              {saving ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  <span>Saving...</span>
                </>
              ) : (
                <>
                  <Save className="w-4 h-4 stroke-[2.5]" />
                  <span>Save changes</span>
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );

  if (isQA) {
    return (
      <QALayout title="Profile" subtitle="Account information">
        <div className="p-6 lg:p-8 max-w-7xl mx-auto">{profileContent}</div>
      </QALayout>
    );
  }

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-8">
      <div className="max-w-3xl mx-auto">{profileContent}</div>
    </div>
  );
}
