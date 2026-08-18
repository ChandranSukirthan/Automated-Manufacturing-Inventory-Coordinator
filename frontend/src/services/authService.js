import api from './api';

const authService = {
  login: async (email, password) => {
    const response = await api.post('/auth/login', { email, password });
    return response.data;
  },
  
  register: async (data) => {
    const response = await api.post('/auth/register', data);
    return response.data;
  },
  
  verifyOtp: async (email, code) => {
    const response = await api.post('/auth/verify-otp', { email, code });
    return response.data;
  },
  
  resendOtp: async (email) => {
    const response = await api.post('/auth/resend-otp', { email });
    return response.data;
  }
};

export default authService;
