import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import ProtectedRoute from './components/Auth/ProtectedRoute';

// Public & Auth Pages
import Landing from './pages/Landing';
import Login from './pages/Auth/Login';
import Signup from './pages/Auth/Signup';
import OTPVerification from './pages/Auth/OTPVerification';
import ForgotPassword from './pages/Auth/ForgotPassword';

// Production Pages (Student 4)
import ProductionDashboard from './pages/Production/ProductionDashboard';
import MachineList from './pages/Production/MachineList';
import MachineDetail from './pages/Production/MachineDetail';
import MaintenancePage from './pages/Production/MaintenancePage';
import ShiftPage from './pages/Production/ShiftPage';

// Admin Pages (Student 4 - ITAdmin only)
import AdminDashboard from './pages/Admin/AdminDashboard';
import UsersPage from './pages/Admin/UsersPage';
import RolesPage from './pages/Admin/RolesPage';
import AuditLogsPage from './pages/Admin/AuditLogsPage';
import AgentWorkflowsPage from './pages/Admin/AgentWorkflowsPage';
import SystemHealthPage from './pages/Admin/SystemHealthPage';

// Teammate Dashboards
import WorkerDashboard from './pages/Dashboard/WorkerDashboard';
import QualityDashboard from './pages/Dashboard/QualityDashboard';

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          {/* Public Routes */}
          <Route path="/" element={<Landing />} />
          <Route path="/login" element={<Login />} />
          <Route path="/signup" element={<Signup />} />
          <Route path="/otp-verify" element={<OTPVerification />} />
          <Route path="/forgot-password" element={<ForgotPassword />} />

          {/* Legacy / Shared Dashboards */}
          <Route path="/dashboard/admin" element={<Navigate to="/admin" replace />} />
          <Route path="/dashboard/worker" element={<WorkerDashboard />} />
          <Route path="/dashboard/quality" element={<QualityDashboard />} />

          {/* Production & Equipment Routes (Protected) */}
          <Route 
            path="/production" 
            element={
              <ProtectedRoute>
                <ProductionDashboard />
              </ProtectedRoute>
            } 
          />
          <Route 
            path="/machines" 
            element={
              <ProtectedRoute>
                <MachineList />
              </ProtectedRoute>
            } 
          />
          <Route 
            path="/machines/:id" 
            element={
              <ProtectedRoute>
                <MachineDetail />
              </ProtectedRoute>
            } 
          />
          <Route 
            path="/maintenance" 
            element={
              <ProtectedRoute>
                <MaintenancePage />
              </ProtectedRoute>
            } 
          />
          <Route 
            path="/shifts" 
            element={
              <ProtectedRoute>
                <ShiftPage />
              </ProtectedRoute>
            } 
          />

          {/* System Administration Routes (Strictly ITAdmin only: role 3) */}
          <Route 
            path="/admin" 
            element={
              <ProtectedRoute requiredRole={3}>
                <AdminDashboard />
              </ProtectedRoute>
            } 
          />
          <Route 
            path="/admin/users" 
            element={
              <ProtectedRoute requiredRole={3}>
                <UsersPage />
              </ProtectedRoute>
            } 
          />
          <Route 
            path="/admin/roles" 
            element={
              <ProtectedRoute requiredRole={3}>
                <RolesPage />
              </ProtectedRoute>
            } 
          />
          <Route 
            path="/admin/audit-logs" 
            element={
              <ProtectedRoute requiredRole={3}>
                <AuditLogsPage />
              </ProtectedRoute>
            } 
          />
          <Route 
            path="/admin/agent-workflows" 
            element={
              <ProtectedRoute requiredRole={3}>
                <AgentWorkflowsPage />
              </ProtectedRoute>
            } 
          />
          <Route 
            path="/admin/system-health" 
            element={
              <ProtectedRoute requiredRole={3}>
                <SystemHealthPage />
              </ProtectedRoute>
            } 
          />

          {/* Fallback route */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}

export default App;
