import { Link } from 'react-router-dom';
import { Package } from 'lucide-react';

export default function Landing() {
  return (
    <div className="min-h-screen bg-slate-950 text-white selection:bg-brand-500 selection:text-white font-sans overflow-x-hidden relative">
      {/* Background Decorative Elements */}
      <div className="absolute top-0 -left-40 w-96 h-96 bg-brand-600 rounded-full mix-blend-multiply filter blur-[128px] opacity-50 animate-blob"></div>
      <div className="absolute top-0 -right-40 w-96 h-96 bg-cyan-600 rounded-full mix-blend-multiply filter blur-[128px] opacity-50 animate-blob animation-delay-2000"></div>
      <div className="absolute -bottom-8 left-20 w-72 h-72 bg-blue-600 rounded-full mix-blend-multiply filter blur-[128px] opacity-50 animate-blob animation-delay-4000"></div>

      {/* Navigation */}
      <nav className="relative z-10 flex items-center justify-between px-8 py-6 w-full max-w-7xl mx-auto border-b border-white/10">
        {/* Left Side: AMIC Logo */}
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-brand-500 to-cyan-600 flex items-center justify-center shadow-lg shadow-brand-500/30">
            <Package className="w-6 h-6 text-white" />
          </div>
          <h1 className="text-2xl font-bold tracking-tight bg-clip-text text-transparent bg-gradient-to-r from-white to-white/70">
            AMIC
          </h1>
        </div>

        {/* Right Side: Login/Signup */}
        <div className="flex items-center gap-4">
          <Link to="/login" className="group relative px-6 py-2.5 font-semibold text-white rounded-full bg-white/10 hover:bg-white/20 border border-white/20 backdrop-blur-md transition-all duration-300 shadow-[0_0_20px_rgba(255,255,255,0.1)] hover:shadow-[0_0_30px_rgba(255,255,255,0.2)] hover:-translate-y-0.5">
            <span className="relative z-10 flex items-center gap-2">
              Login
            </span>
            <div className="absolute inset-0 h-full w-full rounded-full bg-gradient-to-r from-brand-600 to-cyan-600 opacity-0 group-hover:opacity-100 transition-opacity duration-300 -z-10"></div>
          </Link>
          <Link to="/signup" className="px-6 py-2.5 font-semibold text-slate-900 bg-white rounded-full hover:bg-slate-100 transition-colors shadow-lg">
            Sign Up
          </Link>
        </div>
      </nav>

      {/* Main Content */}
      <main className="relative z-10 flex flex-col items-center justify-center min-h-[calc(100vh-100px)] px-4 text-center">
        <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/5 border border-white/10 backdrop-blur-md mb-8">
          <span className="flex h-2 w-2 rounded-full bg-emerald-500 animate-pulse"></span>
          <span className="text-sm font-medium text-white/80">System Online & Ready</span>
        </div>
        
        <h2 className="text-6xl md:text-8xl font-extrabold tracking-tighter mb-6 bg-clip-text text-transparent bg-gradient-to-b from-white via-white to-white/40 drop-shadow-sm">
          Automated <br className="hidden md:block" />
          Manufacturing
        </h2>
        
        <p className="text-xl md:text-2xl text-slate-400 max-w-2xl font-light mb-12 leading-relaxed">
          The next-generation <strong className="text-white font-medium">Inventory Coordinator</strong>. 
          Streamline your supply chain, empower floor workers, and elevate quality control in one unified platform.
        </p>

        <div className="flex flex-col sm:flex-row gap-4 w-full sm:w-auto">
          <Link to="/signup" className="px-8 py-4 rounded-full bg-white text-slate-900 font-semibold text-lg hover:bg-slate-100 transition-colors shadow-[0_0_40px_rgba(255,255,255,0.3)] hover:shadow-[0_0_60px_rgba(255,255,255,0.4)]">
            Get Started
          </Link>
        </div>
      </main>
    </div>
  );
}
