import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../context/useAuth';
import authService from '../../services/authService';
import { parseErrorMessage } from '../../utils/errorHandler';

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

  if (loading) {
    return <div className="min-h-screen bg-slate-950 text-slate-100 p-8">Loading profile...</div>;
  }

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-8">
      <div className="max-w-3xl mx-auto">
        <div className="flex items-center justify-between border-b border-slate-800 pb-4 mb-8">
          <div>
            <p className="text-emerald-400 uppercase tracking-wide text-sm font-semibold">Account</p>
            <h1 className="text-4xl font-bold mt-2">Profile</h1>
          </div>
          <button onClick={() => navigate(-1)} className="px-4 py-2 rounded-xl border border-slate-700 text-slate-200 hover:bg-slate-800">Back</button>
        </div>

        {error && <div role="alert" className="mb-4 p-3 rounded bg-red-500/10 text-red-300 border border-red-500/30">{error}</div>}
        {message && <div role="status" className="mb-4 p-3 rounded bg-emerald-500/10 text-emerald-300 border border-emerald-500/30">{message}</div>}

        <form onSubmit={handleSubmit} className="bg-slate-900/60 rounded-3xl border border-slate-800 p-8 space-y-6">
          <div>
            <label htmlFor="profile-name" className="block text-sm font-medium text-slate-300 mb-2">Name</label>
            <input id="profile-name" value={fullName} onChange={(event) => setFullName(event.target.value)} className="w-full rounded-xl bg-slate-950 border border-slate-700 px-4 py-3 text-white outline-none focus:border-emerald-500" maxLength={200} />
          </div>
          <div>
            <label htmlFor="profile-email" className="block text-sm font-medium text-slate-300 mb-2">Email</label>
            <input id="profile-email" value={profile?.email || ''} readOnly disabled className="w-full rounded-xl bg-slate-900 border border-slate-800 px-4 py-3 text-slate-400" />
            <p className="text-xs text-slate-500 mt-2">Email is managed by the authentication system.</p>
          </div>
          <div>
            <label htmlFor="profile-role" className="block text-sm font-medium text-slate-300 mb-2">Role</label>
            <input id="profile-role" value={profile?.role || ''} readOnly disabled className="w-full rounded-xl bg-slate-900 border border-slate-800 px-4 py-3 text-slate-400" />
          </div>
          <button type="submit" disabled={saving} className="px-5 py-3 rounded-xl bg-emerald-500 text-slate-950 font-bold hover:bg-emerald-400 disabled:opacity-60">{saving ? 'Saving...' : 'Save changes'}</button>
        </form>
      </div>
    </div>
  );
}
