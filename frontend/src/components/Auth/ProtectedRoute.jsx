import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '../../context/useAuth';
import { ShieldAlert } from 'lucide-react';

export default function ProtectedRoute({ children, allowedRoles, requiredRole = null }) {
  const { user } = useAuth();
  const location = useLocation();

  if (!user) return <Navigate to="/login" replace state={{ from: location }} />;

  const role = user.role;
  const matchesRole = (allowedRole) => (
    role === allowedRole ||
    role === String(allowedRole) ||
    role?.name === allowedRole ||
    role?.id === allowedRole ||
    role?.id === Number(allowedRole)
  );
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
        </div>
      </div>
    );
  }

  return children || <Outlet />;
}
