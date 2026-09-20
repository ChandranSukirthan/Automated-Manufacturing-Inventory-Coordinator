import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import ProtectedRoute from './components/Auth/ProtectedRoute';

import Landing from './pages/Landing';
import Login from './pages/Auth/Login';
import Signup from './pages/Auth/Signup';
import OTPVerification from './pages/Auth/OTPVerification';
import ForgotPassword from './pages/Auth/ForgotPassword';
import ProfilePage from './pages/Profile/ProfilePage';

// Student 2: Supply Chain Manager Pages
import SupplyChainDashboard from './pages/Dashboard/AdminDashboard';
import SupplierList from './pages/Suppliers/SupplierList';
import SupplierDetail from './pages/Suppliers/SupplierDetail';
import PurchaseOrderList from './pages/PurchaseOrders/PurchaseOrderList';
import PurchaseOrderCreate from './pages/PurchaseOrders/PurchaseOrderCreate';
import PurchaseOrderDetail from './pages/PurchaseOrders/PurchaseOrderDetail';
import AiApprovals from './pages/PurchaseOrders/AiApprovals';
import SupplierAnalytics from './pages/PurchaseOrders/SupplierAnalytics';
import AgentWorkflowMonitor from './pages/AgentWorkflows/AgentWorkflowMonitor';

// Student 3: Quality & Defect Pages
import QualityDashboard from './pages/Dashboard/QualityDashboard';
import DefectReportsPage from './pages/Dashboard/DefectReportsPage';
import DefectFormPage from './pages/Dashboard/DefectFormPage';
import DefectDetailPage from './pages/Dashboard/DefectDetailPage';
import QuarantineManagementPage from './pages/Dashboard/QuarantineManagementPage';
import QuarantineDetailPage from './pages/Dashboard/QuarantineDetailPage';
import QuarantineHistoryPage from './pages/Dashboard/QuarantineHistoryPage';

// Student 4: Production & Equipment Pages
import ProductionDashboard from './pages/Production/ProductionDashboard';
import MachineList from './pages/Production/MachineList';
import MachineDetail from './pages/Production/MachineDetail';
import MaintenancePage from './pages/Production/MaintenancePage';
import ShiftPage from './pages/Production/ShiftPage';

// Student 4: System Administration Pages (ITAdmin)
import ITAdminDashboard from './pages/Admin/AdminDashboard';
import UsersPage from './pages/Admin/UsersPage';
import RolesPage from './pages/Admin/RolesPage';
import AuditLogsPage from './pages/Admin/AuditLogsPage';
import AgentWorkflowsPage from './pages/Admin/AgentWorkflowsPage';
import SystemHealthPage from './pages/Admin/SystemHealthPage';

// Floor Worker Dashboard
import WorkerDashboard from './pages/Dashboard/WorkerDashboard';

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          {/* Public Authentication & Landing Routes */}
          <Route path="/" element={<Landing />} />
          <Route path="/login" element={<Login />} />
          <Route path="/signup" element={<Signup />} />
          <Route path="/otp-verify" element={<OTPVerification />} />
          <Route path="/forgot-password" element={<ForgotPassword />} />

          {/* User Profile */}
          <Route
            path="/profile"
            element={
              <ProtectedRoute>
                <ProfilePage />
              </ProtectedRoute>
            }
          />

          {/* Student 2: Supply Chain Manager Routes */}
          <Route
            path="/dashboard/manager"
            element={
              <ProtectedRoute>
                <SupplyChainDashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/dashboard/admin"
            element={
              <ProtectedRoute>
                <SupplyChainDashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/purchase-orders"
            element={
              <ProtectedRoute>
                <PurchaseOrderList />
              </ProtectedRoute>
            }
          />
          <Route
            path="/purchase-orders/create"
            element={
              <ProtectedRoute>
                <PurchaseOrderCreate />
              </ProtectedRoute>
            }
          />
          <Route
            path="/purchase-orders/:id"
            element={
              <ProtectedRoute>
                <PurchaseOrderDetail />
              </ProtectedRoute>
            }
          />
          <Route
            path="/suppliers"
            element={
              <ProtectedRoute>
                <SupplierList />
              </ProtectedRoute>
            }
          />
          <Route
            path="/suppliers/:id"
            element={
              <ProtectedRoute>
                <SupplierDetail />
              </ProtectedRoute>
            }
          />
          <Route
            path="/purchase-orders/approvals"
            element={
              <ProtectedRoute allowedRoles={[1, 'SupplyChainManager', 'ITAdmin']}>
                <AiApprovals />
              </ProtectedRoute>
            }
          />
          <Route
            path="/ai-approvals"
            element={
              <ProtectedRoute allowedRoles={[1, 'SupplyChainManager', 'ITAdmin']}>
                <AiApprovals />
              </ProtectedRoute>
            }
          />
          <Route
            path="/purchase-orders/analytics"
            element={
              <ProtectedRoute>
                <SupplierAnalytics />
              </ProtectedRoute>
            }
          />
          <Route
            path="/supplier-analytics"
            element={
              <ProtectedRoute>
                <SupplierAnalytics />
              </ProtectedRoute>
            }
          />
          <Route
            path="/agent-workflows"
            element={
              <ProtectedRoute>
                <AgentWorkflowMonitor />
              </ProtectedRoute>
            }
          />

          {/* Worker Dashboard */}
          <Route
            path="/dashboard/worker"
            element={
              <ProtectedRoute>
                <WorkerDashboard />
              </ProtectedRoute>
            }
          />

          {/* Student 3: Quality & Defect Routes */}
          <Route element={<ProtectedRoute allowedRoles={[2, 'QualityInspector', 'ITAdmin']} />}>
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

          {/* Student 4: Production & Equipment Routes */}
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

          {/* Student 4: System Administration Routes (Strictly ITAdmin only: role 3) */}
          <Route
            path="/admin"
            element={
              <ProtectedRoute requiredRole={3}>
                <ITAdminDashboard />
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

          {/* Catch-all fallback */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}

export default App;
