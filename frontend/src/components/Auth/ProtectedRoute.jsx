import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';

export default function ProtectedRoute({ children, allowedRoles }) {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div className="min-h-screen bg-slate-950 flex items-center justify-center">
        <div className="w-8 h-8 border-4 border-brand-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  // If specific roles are specified, check if user's role matches
  // Role mapping: 0: FloorWorker, 1: SupplyChainManager, 2: QualityInspector, 3: ITAdmin
  if (allowedRoles && allowedRoles.length > 0) {
    const userRoleNum = typeof user.role === 'number' ? user.role : parseInt(user.role, 10);
    if (!allowedRoles.includes(userRoleNum)) {
      return <Navigate to="/" replace />;
    }
  }

  return children;
}
