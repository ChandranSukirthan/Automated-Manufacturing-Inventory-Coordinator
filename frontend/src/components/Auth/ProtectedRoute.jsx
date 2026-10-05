import { normalizeRole, roleHome } from '../../utils/roles';
import React from 'react';
import { Link, Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '../../context/useAuth';
import { ShieldAlert } from 'lucide-react';

export default function ProtectedRoute({ children, allowedRoles, requiredRole = null }) {
  const { user, loading } = useAuth();
  const location = useLocation();

  if (loading) {
    return (
      <div className="min-h-screen bg-slate-950 flex items-center justify-center">
        <div className="w-8 h-8 border-4 border-brand-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!user) return <Navigate to="/login" replace state={{ from: location }} />;

  const userRole = normalizeRole(user.role);
  const matchesRole = (allowedRole) => {
    return userRole.toLowerCase() === normalizeRole(allowedRole).toLowerCase();
  };

  const isAllowed = requiredRole === null
    ? (!allowedRoles || allowedRoles.some(matchesRole))
    : matchesRole(requiredRole);

  if (!isAllowed) {
    return (
      <div className="min-h-screen flex items-center justify-center p-6 text-center">
        <div className="max-w-md space-y-4">
          <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-2xl bg-red-500/10 text-red-400">
            <ShieldAlert className="h-8 w-8" />
          </div>
          <h2 className="text-xl font-bold">Restricted Access (403)</h2>
          <p className="text-sm">Your account does not have permission to view this page.</p>
          <Link to={roleHome(user.role)} className="inline-block rounded-lg bg-brand-600 px-4 py-2 text-white">Return to my dashboard</Link>
        </div>
      </div>
    );
  }

  return children || <Outlet />;
}
