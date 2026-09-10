import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext.jsx';
import Landing from './pages/Landing';
import Login from './pages/Auth/Login';
import Signup from './pages/Auth/Signup';
import OTPVerification from './pages/Auth/OTPVerification';
import AdminDashboard from './pages/Dashboard/AdminDashboard';
import WorkerDashboard from './pages/Dashboard/WorkerDashboard';
import QualityDashboard from './pages/Dashboard/QualityDashboard';
import DefectReportsPage from './pages/Dashboard/DefectReportsPage';
import DefectFormPage from './pages/Dashboard/DefectFormPage';
import DefectDetailPage from './pages/Dashboard/DefectDetailPage';
import ForgotPassword from './pages/Auth/ForgotPassword';
import QuarantineManagementPage from './pages/Dashboard/QuarantineManagementPage';
import QuarantineDetailPage from './pages/Dashboard/QuarantineDetailPage';
import ProtectedRoute from './components/Auth/ProtectedRoute';

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Landing />} />
          <Route path="/login" element={<Login />} />
          <Route path="/signup" element={<Signup />} />
          <Route path="/otp-verify" element={<OTPVerification />} />
          <Route path="/forgot-password" element={<ForgotPassword />} />
          <Route path="/dashboard/admin" element={<AdminDashboard />} />
          <Route path="/dashboard/worker" element={<WorkerDashboard />} />
          <Route element={<ProtectedRoute allowedRoles={[2, 'QualityInspector']} />}>
            <Route path="/dashboard/quality" element={<QualityDashboard />} />
            <Route path="/dashboard/defects" element={<DefectReportsPage />} />
            <Route path="/dashboard/defects/new" element={<DefectFormPage />} />
            <Route path="/dashboard/defects/:id" element={<DefectDetailPage />} />
            <Route path="/dashboard/defects/:id/edit" element={<DefectFormPage />} />
            <Route path="/dashboard/quarantine" element={<QuarantineManagementPage />} />
            <Route path="/dashboard/quarantine/history" element={<QuarantineManagementPage />} />
            <Route path="/dashboard/quarantine/:id" element={<QuarantineDetailPage />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}

export default App;
