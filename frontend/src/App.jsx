import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext.jsx';
import { Navigate } from 'react-router-dom';
import ProtectedRoute from './components/Auth/ProtectedRoute';
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
import DefectReportsPage from './pages/Dashboard/DefectReportsPage';
import DefectFormPage from './pages/Dashboard/DefectFormPage';
import DefectDetailPage from './pages/Dashboard/DefectDetailPage';
import QuarantineManagementPage from './pages/Dashboard/QuarantineManagementPage';
import QuarantineDetailPage from './pages/Dashboard/QuarantineDetailPage';
import QuarantineHistoryPage from './pages/Dashboard/QuarantineHistoryPage';

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
          <Route path="/dashboard/admin" element={<Navigate to="/admin" replace />} />
          <Route path="/dashboard/worker" element={<WorkerDashboard />} />
          <Route element={<ProtectedRoute allowedRoles={['QualityInspector']} />}>
            <Route path="/quality" element={<QualityDashboard />} />
            <Route path="/quality/defects" element={<DefectReportsPage />} />
            <Route path="/quality/defects/new" element={<DefectFormPage />} />
            <Route path="/quality/defects/:id" element={<DefectDetailPage />} />
            <Route path="/quality/defects/:id/edit" element={<DefectFormPage />} />
            <Route path="/quality/quarantine" element={<QuarantineManagementPage />} />
            <Route path="/quality/quarantine/:id" element={<QuarantineDetailPage />} />
            <Route path="/quality/quarantine/history" element={<QuarantineHistoryPage />} />
            <Route path="/dashboard/quality" element={<QualityDashboard />} />
            <Route path="/dashboard/defects" element={<DefectReportsPage />} />
            <Route path="/dashboard/defects/new" element={<DefectFormPage />} />
            <Route path="/dashboard/defects/:id" element={<DefectDetailPage />} />
            <Route path="/dashboard/defects/:id/edit" element={<DefectFormPage />} />
            <Route path="/dashboard/quarantine" element={<QuarantineManagementPage />} />
            <Route path="/dashboard/quarantine/:id" element={<QuarantineDetailPage />} />
            <Route path="/dashboard/quarantine/history" element={<QuarantineHistoryPage />} />
          </Route>
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
