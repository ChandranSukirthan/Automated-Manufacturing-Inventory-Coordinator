import { createContext } from 'react';

export const AuthContext = createContext();

export { AuthProvider } from './AuthContext.jsx';
export { useAuth } from './useAuth.js';