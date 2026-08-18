import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'

import { GoogleOAuthProvider } from '@react-oauth/google'

// NOTE: Replace this placeholder with your actual Google Client ID from Google Cloud Console
const GOOGLE_CLIENT_ID = "933911313790-13cjef02fqivfpgpvmebrb9dktlk1cno.apps.googleusercontent.com";

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <GoogleOAuthProvider clientId={GOOGLE_CLIENT_ID}>
      <App />
    </GoogleOAuthProvider>
  </StrictMode>,
)
