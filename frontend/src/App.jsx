import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import Landing from './pages/Landing';
import Login from './pages/Auth/Login';
import Signup from './pages/Auth/Signup';
import OTPVerification from './pages/Auth/OTPVerification';
import ForgotPassword from './pages/Auth/ForgotPassword';
import AdminDashboard from './pages/Dashboard/AdminDashboard';
import WorkerDashboard from './pages/Dashboard/WorkerDashboard';
import QualityDashboard from './pages/Dashboard/QualityDashboard';
import ProtectedRoute from './components/Auth/ProtectedRoute';

// Student 2: Supply Chain Manager — Purchase Order Management Pages
import SupplierList from './pages/Suppliers/SupplierList';
import SupplierDetail from './pages/Suppliers/SupplierDetail';
import PurchaseOrderList from './pages/PurchaseOrders/PurchaseOrderList';
import PurchaseOrderDetail from './pages/PurchaseOrders/PurchaseOrderDetail';
import AiApprovals from './pages/PurchaseOrders/AiApprovals';
import SupplierAnalytics from './pages/PurchaseOrders/SupplierAnalytics';

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

          {/* Student 2: Supply Chain Manager Routes */}
          <Route
            path="/purchase-orders"
            element={
              <ProtectedRoute>
                <PurchaseOrderList />
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
            path="/ai-approvals"
            element={
              <ProtectedRoute allowedRoles={[1]}>
                <AiApprovals />
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

          {/* Role Dashboard Redirects */}
          <Route path="/dashboard/manager" element={<Navigate to="/dashboard/admin" replace />} />
          <Route
            path="/dashboard/admin"
            element={
              <ProtectedRoute>
                <AdminDashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/dashboard/worker"
            element={
              <ProtectedRoute>
                <WorkerDashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/dashboard/quality"
            element={
              <ProtectedRoute>
                <QualityDashboard />
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
