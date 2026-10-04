import { ArrowLeft } from 'lucide-react';
import { Link } from 'react-router-dom';

export default function AuthLayout({ children, title, subtitle }) {
  return (
    <div className="min-h-screen bg-slate-950 text-white selection:bg-brand-500 selection:text-white font-sans flex items-center justify-center relative overflow-y-auto py-8 sm:py-12">
      {/* Background Decorative Elements */}
      <div className="absolute top-0 -left-40 w-96 h-96 bg-brand-600 rounded-full mix-blend-multiply filter blur-[128px] opacity-40 animate-blob pointer-events-none"></div>
      <div className="absolute top-0 -right-40 w-96 h-96 bg-cyan-600 rounded-full mix-blend-multiply filter blur-[128px] opacity-40 animate-blob animation-delay-2000 pointer-events-none"></div>
      <div className="absolute -bottom-8 left-20 w-72 h-72 bg-blue-600 rounded-full mix-blend-multiply filter blur-[128px] opacity-40 animate-blob animation-delay-4000 pointer-events-none"></div>

      {/* Back Button */}
      <Link 
        to="/" 
        className="fixed top-6 left-6 z-20 flex items-center gap-2 px-4 py-2 text-sm font-medium text-slate-300 hover:text-white bg-white/5 hover:bg-white/10 rounded-full border border-white/10 transition-colors backdrop-blur-md"
      >
        <ArrowLeft className="w-4 h-4" />
        Back to Home
      </Link>

      <div className="relative z-10 w-[450px] max-w-[95vw] mx-auto px-4 my-auto flex flex-col justify-center">
        <div className="text-center mb-4">
          <Link to="/" className="inline-flex items-center gap-3 mb-3">
            <img 
              src="/assets/amic-logo.png" 
              alt="AMIC Logo" 
              className="w-12 h-12 object-contain filter drop-shadow-[0_0_15px_rgba(14,165,233,0.6)]" 
            />
            <span className="text-2xl font-bold tracking-tight bg-clip-text text-transparent bg-gradient-to-r from-white to-white/70">
              AMIC
            </span>
          </Link>
          <h2 className="text-2xl font-bold text-white mb-1">{title}</h2>
          <p className="text-sm text-slate-400">{subtitle}</p>
        </div>

        <div className="bg-white/5 border border-white/10 backdrop-blur-xl rounded-2xl p-6 sm:p-7 shadow-2xl shadow-black/50 relative overflow-hidden">
          {/* Subtle inner glow */}
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full h-1 bg-gradient-to-r from-transparent via-brand-500/50 to-transparent"></div>
          {children}
        </div>
      </div>
    </div>
  );
}

