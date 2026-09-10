import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '../../context/useAuth';

export default function ProtectedRoute({ allowedRoles }) {
  const { user } = useAuth();
  const location = useLocation();

  if (!user) return <Navigate to="/login" replace state={{ from: location }} />;

  const role = user.role;
  const isAllowed = allowedRoles.some((allowedRole) => role === allowedRole || role === allowedRole.name);
  return isAllowed ? <Outlet /> : <Navigate to="/" replace />;
}
