import React, { lazy, Suspense } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import ProtectedRoute from './components/Auth/ProtectedRoute';
import RoleHomeRedirect from './components/Auth/RoleHomeRedirect';

const Landing = lazy(() => import('./pages/Landing'));
const Login = lazy(() => import('./pages/Auth/Login'));
const Signup = lazy(() => import('./pages/Auth/Signup'));
const OTPVerification = lazy(() => import('./pages/Auth/OTPVerification'));
const ForgotPassword = lazy(() => import('./pages/Auth/ForgotPassword'));
const ProfilePage = lazy(() => import('./pages/Profile/ProfilePage'));

// Supply Chain Manager pages
const SupplyChainDashboard = lazy(() => import('./pages/Dashboard/AdminDashboard'));
const SupplierList = lazy(() => import('./pages/Suppliers/SupplierList'));
const SupplierDetail = lazy(() => import('./pages/Suppliers/SupplierDetail'));
const PurchaseOrderList = lazy(() => import('./pages/PurchaseOrders/PurchaseOrderList'));
const PurchaseOrderCreate = lazy(() => import('./pages/PurchaseOrders/PurchaseOrderCreate'));
const PurchaseOrderDetail = lazy(() => import('./pages/PurchaseOrders/PurchaseOrderDetail'));
const ProcurementResearch = lazy(() => import('./pages/PurchaseOrders/ProcurementResearch'));
const AiApprovals = lazy(() => import('./pages/PurchaseOrders/AiApprovals'));
const SupplierAnalytics = lazy(() => import('./pages/PurchaseOrders/SupplierAnalytics'));
const AgentWorkflowMonitor = lazy(() => import('./pages/AgentWorkflows/AgentWorkflowMonitor'));

// Quality and defect pages
const QualityDashboard = lazy(() => import('./pages/Dashboard/QualityDashboard'));
const AiValidationPage = lazy(() => import('./pages/Dashboard/AiValidationPage'));
const DefectReportsPage = lazy(() => import('./pages/Dashboard/DefectReportsPage'));
const DefectFormPage = lazy(() => import('./pages/Dashboard/DefectFormPage'));
const DefectDetailPage = lazy(() => import('./pages/Dashboard/DefectDetailPage'));
const QuarantineManagementPage = lazy(() => import('./pages/Dashboard/QuarantineManagementPage'));
const QuarantineDetailPage = lazy(() => import('./pages/Dashboard/QuarantineDetailPage'));
const QuarantineHistoryPage = lazy(() => import('./pages/Dashboard/QuarantineHistoryPage'));
import RoleLayout from './components/Layout/RoleLayout';

// Production and equipment pages
const ProductionDashboard = lazy(() => import('./pages/Production/ProductionDashboard'));
const MachineList = lazy(() => import('./pages/Production/MachineList'));
const MachineDetail = lazy(() => import('./pages/Production/MachineDetail'));
const MaintenancePage = lazy(() => import('./pages/Production/MaintenancePage'));
const ShiftPage = lazy(() => import('./pages/Production/ShiftPage'));

// System administration pages
const ITAdminDashboard = lazy(() => import('./pages/Admin/AdminDashboard'));
const UsersPage = lazy(() => import('./pages/Admin/UsersPage'));
const RolesPage = lazy(() => import('./pages/Admin/RolesPage'));
const AuditLogsPage = lazy(() => import('./pages/Admin/AuditLogsPage'));
const AgentWorkflowsPage = lazy(() => import('./pages/Admin/AgentWorkflowsPage'));
const SystemHealthPage = lazy(() => import('./pages/Admin/SystemHealthPage'));

// Floor Worker Dashboard
const WorkerDashboard = lazy(() => import('./pages/Dashboard/WorkerDashboard'));
const ReplenishmentRequestPage = lazy(() => import('./pages/Worker/ReplenishmentRequestPage'));

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Suspense fallback={<div role="status" className="p-6 text-center">Loading page…</div>}>
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

          {/* Supply Chain Manager routes */}
          <Route
            path="/dashboard/manager"
            element={
              <ProtectedRoute allowedRoles={['SupplyChainManager', 'ITAdmin']}>
                <SupplyChainDashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/dashboard/admin"
            element={
              <ProtectedRoute allowedRoles={['SupplyChainManager', 'ITAdmin']}>
                <RoleHomeRedirect />
              </ProtectedRoute>
            }
          />
          <Route
            path="/purchase-orders"
            element={
              <ProtectedRoute allowedRoles={['FloorWorker', 'SupplyChainManager', 'ITAdmin']}>
                <PurchaseOrderList />
              </ProtectedRoute>
            }
          />
          <Route
            path="/purchase-orders/create"
            element={
              <ProtectedRoute allowedRoles={['SupplyChainManager']}>
                <PurchaseOrderCreate />
              </ProtectedRoute>
            }
          />
          <Route
            path="/purchase-orders/procurement"
            element={
              <ProtectedRoute allowedRoles={[1, 'SupplyChainManager', 'ITAdmin', 3]}>
                <ProcurementResearch />
              </ProtectedRoute>
            }
          />
          <Route
            path="/procurement-research"
            element={
              <ProtectedRoute allowedRoles={[1, 'SupplyChainManager', 'ITAdmin', 3]}>
                <ProcurementResearch />
              </ProtectedRoute>
            }
          />
          <Route
            path="/purchase-orders/:id"
            element={
              <ProtectedRoute allowedRoles={['FloorWorker', 'SupplyChainManager', 'ITAdmin']}>
                <PurchaseOrderDetail />
              </ProtectedRoute>
            }
          />
          <Route
            path="/suppliers"
            element={
              <ProtectedRoute allowedRoles={['SupplyChainManager', 'ITAdmin']}>
                <SupplierList />
              </ProtectedRoute>
            }
          />
          <Route
            path="/suppliers/:id"
            element={
              <ProtectedRoute allowedRoles={['SupplyChainManager', 'ITAdmin']}>
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
              <ProtectedRoute allowedRoles={['SupplyChainManager', 'ITAdmin']}>
                <SupplierAnalytics />
              </ProtectedRoute>
            }
          />
          <Route
            path="/supplier-analytics"
            element={
              <ProtectedRoute allowedRoles={['SupplyChainManager', 'ITAdmin']}>
                <SupplierAnalytics />
              </ProtectedRoute>
            }
          />
          <Route
            path="/agent-workflows"
            element={
              <ProtectedRoute allowedRoles={['FloorWorker', 'SupplyChainManager', 'ITAdmin']}>
                <AgentWorkflowMonitor />
              </ProtectedRoute>
            }
          />

          {/* Floor Worker inventory and stock-tracking routes */}
          <Route
            path="/dashboard/worker"
            element={
              <ProtectedRoute allowedRoles={[0, 'FloorWorker', 'ITAdmin']}>
                <WorkerDashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/inventory"
            element={
              <ProtectedRoute allowedRoles={[0, 'FloorWorker', 'ITAdmin']}>
                <WorkerDashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/inventory/:id"
            element={
              <ProtectedRoute allowedRoles={[0, 'FloorWorker', 'ITAdmin']}>
                <WorkerDashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/inventory/rolls"
            element={
              <ProtectedRoute allowedRoles={[0, 'FloorWorker', 'ITAdmin']}>
                <WorkerDashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/inventory/stock-levels"
            element={
              <ProtectedRoute allowedRoles={[0, 'FloorWorker', 'ITAdmin']}>
                <WorkerDashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/inventory/low-stock"
            element={
              <ProtectedRoute allowedRoles={[0, 'FloorWorker', 'ITAdmin']}>
                <WorkerDashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/inventory/history"
            element={
              <ProtectedRoute allowedRoles={[0, 'FloorWorker', 'ITAdmin']}>
                <WorkerDashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/worker/replenishment"
            element={
              <ProtectedRoute allowedRoles={[0, 'FloorWorker', 'ITAdmin']}>
                <ReplenishmentRequestPage />
              </ProtectedRoute>
            }
          />

          {/* Quality and defect routes */}
          <Route element={<ProtectedRoute allowedRoles={[2, 'QualityInspector', 'ITAdmin']} />}>
            <Route element={<RoleLayout />}>
              <Route path="/quality" element={<QualityDashboard />} />
              <Route path="/quality/ai-validation" element={<AiValidationPage />} />
              <Route path="/quality/defects" element={<DefectReportsPage />} />
              <Route path="/quality/defects/new" element={<DefectFormPage />} />
              <Route path="/quality/defects/:id" element={<DefectDetailPage />} />
              <Route path="/quality/defects/:id/edit" element={<DefectFormPage />} />
              <Route path="/quality/quarantine" element={<QuarantineManagementPage />} />
              <Route path="/quality/quarantine/history" element={<QuarantineHistoryPage />} />
              <Route path="/quality/quarantine/:id" element={<QuarantineDetailPage />} />
              <Route path="/dashboard/quality" element={<QualityDashboard />} />
              <Route path="/dashboard/ai-validation" element={<AiValidationPage />} />
              <Route path="/dashboard/defects" element={<DefectReportsPage />} />
              <Route path="/dashboard/defects/new" element={<DefectFormPage />} />
              <Route path="/dashboard/defects/:id" element={<DefectDetailPage />} />
              <Route path="/dashboard/defects/:id/edit" element={<DefectFormPage />} />
              <Route path="/dashboard/quarantine" element={<QuarantineManagementPage />} />
              <Route path="/dashboard/quarantine/history" element={<QuarantineHistoryPage />} />
              <Route path="/dashboard/quarantine/:id" element={<QuarantineDetailPage />} />
            </Route>
          </Route>

          {/* Production and equipment routes */}
          <Route
            path="/production"
            element={
              <ProtectedRoute allowedRoles={['FloorWorker', 'SupplyChainManager', 'ITAdmin']}>
                <ProductionDashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/machines"
            element={
              <ProtectedRoute allowedRoles={['FloorWorker', 'SupplyChainManager', 'QualityInspector', 'ITAdmin']}>
                <MachineList />
              </ProtectedRoute>
            }
          />
          <Route
            path="/machines/:id"
            element={
              <ProtectedRoute allowedRoles={['FloorWorker', 'SupplyChainManager', 'QualityInspector', 'ITAdmin']}>
                <MachineDetail />
              </ProtectedRoute>
            }
          />
          <Route
            path="/maintenance"
            element={
              <ProtectedRoute allowedRoles={['FloorWorker', 'SupplyChainManager', 'QualityInspector', 'ITAdmin']}>
                <MaintenancePage />
              </ProtectedRoute>
            }
          />
          <Route
            path="/shifts"
            element={
              <ProtectedRoute allowedRoles={['FloorWorker', 'SupplyChainManager', 'ITAdmin']}>
                <ShiftPage />
              </ProtectedRoute>
            }
          />

          {/* System administration routes (ITAdmin only) */}
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
        </Suspense>
      </BrowserRouter>
    </AuthProvider>
  );
}

export default App;
