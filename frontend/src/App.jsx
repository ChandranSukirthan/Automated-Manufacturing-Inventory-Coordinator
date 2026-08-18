import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext.jsx';
import Landing from './pages/Landing';
import Login from './pages/Auth/Login';
import Signup from './pages/Auth/Signup';
import OTPVerification from './pages/Auth/OTPVerification';
import AdminDashboard from './pages/Dashboard/AdminDashboard';
import WorkerDashboard from './pages/Dashboard/WorkerDashboard';
import QualityDashboard from './pages/Dashboard/QualityDashboard';

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Landing />} />
          <Route path="/login" element={<Login />} />
          <Route path="/signup" element={<Signup />} />
          <Route path="/otp-verify" element={<OTPVerification />} />
          <Route path="/dashboard/admin" element={<AdminDashboard />} />
          <Route path="/dashboard/worker" element={<WorkerDashboard />} />
          <Route path="/dashboard/quality" element={<QualityDashboard />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}

export default App;
