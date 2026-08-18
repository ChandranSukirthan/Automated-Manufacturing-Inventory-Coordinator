import { useState } from 'react';
import authService from '../services/authService';
import { AuthContext } from './authContext';

function readStoredUser() {
  const storedUser = localStorage.getItem('user');
  const token = localStorage.getItem('accessToken');

  if (!storedUser || !token) return null;

  try {
    return JSON.parse(storedUser);
  } catch (error) {
    console.error('Failed to parse stored user data', error);
    localStorage.removeItem('user');
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');
    return null;
  }
}

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(readStoredUser);

  const login = async (email, password) => {
    const data = await authService.login(email, password);
    localStorage.setItem('accessToken', data.accessToken);
    localStorage.setItem('refreshToken', data.refreshToken);
    localStorage.setItem('user', JSON.stringify(data.user));
    setUser(data.user);
    return data;
  };

  const register = async (payload) => {
    return authService.register(payload);
  };

  const googleLogin = async (tokenId) => {
    const data = await authService.googleLogin(tokenId);
    if (!data.requiresRoleSelection && data.authResponse) {
      localStorage.setItem('accessToken', data.authResponse.accessToken);
      localStorage.setItem('refreshToken', data.authResponse.refreshToken);
      localStorage.setItem('user', JSON.stringify(data.authResponse.user));
      setUser(data.authResponse.user);
    }
    return data;
  };

  const googleRegister = async (tokenId, role) => {
    const data = await authService.googleRegister(tokenId, role);
    localStorage.setItem('accessToken', data.accessToken);
    localStorage.setItem('refreshToken', data.refreshToken);
    localStorage.setItem('user', JSON.stringify(data.user));
    setUser(data.user);
    return data;
  };

  const logout = () => {
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');
    localStorage.removeItem('user');
    setUser(null);
  };

  const value = {
    user,
    login,
    register,
    googleLogin,
    googleRegister,
    logout,
    isAuthenticated: !!user
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};
