import React from 'react';
import { Link } from 'react-router-dom';
import { Package, ArrowRight, ShieldCheck, Cpu, Factory } from 'lucide-react';

export default function Landing() {
  return (
    <div className="min-h-screen bg-slate-950 text-white selection:bg-brand-500 selection:text-white font-sans overflow-x-hidden relative flex flex-col justify-between">
      {/* High-Tech Factory Background Image with Dark Overlay */}
      <div 
        className="absolute inset-0 bg-cover bg-center bg-no-repeat z-0 scale-105 transition-transform duration-1000"
        style={{ backgroundImage: `url('/assets/factory-bg.png')` }}
      ></div>
      
      {/* Dark Gradient Overlay for optimal text readability */}
      <div className="absolute inset-0 bg-gradient-to-b from-slate-950/85 via-slate-950/75 to-slate-950/95 z-0 backdrop-blur-[2px]"></div>

      {/* Decorative ambient lighting */}
      <div className="absolute top-0 -left-40 w-96 h-96 bg-brand-600 rounded-full mix-blend-screen filter blur-[128px] opacity-30 animate-blob pointer-events-none z-0"></div>
      <div className="absolute top-0 -right-40 w-96 h-96 bg-cyan-600 rounded-full mix-blend-screen filter blur-[128px] opacity-30 animate-blob animation-delay-2000 pointer-events-none z-0"></div>
      <div className="absolute -bottom-8 left-20 w-72 h-72 bg-blue-600 rounded-full mix-blend-screen filter blur-[128px] opacity-30 animate-blob animation-delay-4000 pointer-events-none z-0"></div>

      {/* Navigation */}
      <nav className="relative z-10 flex items-center justify-between px-8 py-6 w-full max-w-7xl mx-auto border-b border-white/10 backdrop-blur-md bg-slate-950/30 rounded-b-2xl">
        {/* Left Side: AMIC Logo */}
        <div className="flex items-center gap-3">
          <img 
            src="/assets/amic-logo.png" 
            alt="AMIC Logo" 
            className="w-12 h-12 object-contain drop-shadow-[0_0_12px_rgba(14,165,233,0.5)]" 
          />
          <h1 className="text-2xl font-bold tracking-tight bg-clip-text text-transparent bg-gradient-to-r from-white to-white/70">
            AMIC
          </h1>
        </div>

        {/* Right Side: Login/Signup */}
        <div className="flex items-center gap-4">
          <Link 
            to="/login" 
            className="group relative px-6 py-2.5 font-semibold text-white rounded-full bg-white/10 hover:bg-white/20 border border-white/20 backdrop-blur-md transition-all duration-300 shadow-[0_0_20px_rgba(255,255,255,0.1)] hover:shadow-[0_0_30px_rgba(255,255,255,0.2)] hover:-translate-y-0.5"
          >
            <span className="relative z-10 flex items-center gap-2">
              Login
            </span>
            <div className="absolute inset-0 h-full w-full rounded-full bg-gradient-to-r from-brand-600 to-cyan-600 opacity-0 group-hover:opacity-100 transition-opacity duration-300 -z-10"></div>
          </Link>
          <Link 
            to="/signup" 
            className="px-6 py-2.5 font-semibold text-slate-900 bg-white rounded-full hover:bg-slate-100 transition-all shadow-lg hover:shadow-white/20 hover:-translate-y-0.5"
          >
            Sign Up
          </Link>
        </div>
      </nav>

      {/* Main Content Hero */}
      <main className="relative z-10 flex flex-col items-center justify-center py-20 px-4 text-center max-w-5xl mx-auto my-auto">
        <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/10 border border-white/15 backdrop-blur-md mb-8 shadow-inner">
          <span className="flex h-2.5 w-2.5 rounded-full bg-emerald-400 animate-pulse"></span>
          <span className="text-sm font-medium text-white/90">Automated Manufacturing & Inventory System</span>
        </div>
        
        <h2 className="text-5xl md:text-7xl font-extrabold tracking-tight mb-6 bg-clip-text text-transparent bg-gradient-to-b from-white via-slate-100 to-slate-400 drop-shadow-lg leading-tight">
          Automated <br className="hidden md:block" />
          Manufacturing Coordinator
        </h2>
        
        <p className="text-lg md:text-xl text-slate-300 max-w-3xl font-normal mb-10 leading-relaxed drop-shadow">
          The next-generation <strong className="text-white font-semibold">Inventory Coordinator</strong>. 
          Streamline your supply chain, empower floor workers, and elevate quality control in one unified platform.
        </p>

        <div className="flex flex-col sm:flex-row gap-4 w-full sm:w-auto justify-center">
          <Link 
            to="/signup" 
            className="inline-flex items-center justify-center gap-2 px-8 py-4 rounded-full bg-gradient-to-r from-brand-500 to-cyan-500 text-white font-bold text-lg hover:from-brand-400 hover:to-cyan-400 transition-all shadow-[0_0_30px_rgba(14,165,233,0.4)] hover:shadow-[0_0_50px_rgba(14,165,233,0.6)] hover:-translate-y-0.5"
          >
            Get Started <ArrowRight className="w-5 h-5" />
          </Link>
          <Link 
            to="/login" 
            className="inline-flex items-center justify-center gap-2 px-8 py-4 rounded-full bg-white/10 hover:bg-white/20 border border-white/20 backdrop-blur-md text-white font-semibold text-lg transition-all hover:-translate-y-0.5"
          >
            Sign In to Dashboard
          </Link>
        </div>

        {/* Highlight Feature Badges */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-6 mt-16 w-full max-w-4xl">
          <div className="flex items-center gap-3 p-4 rounded-2xl bg-white/5 border border-white/10 backdrop-blur-md text-left">
            <div className="p-3 rounded-xl bg-brand-500/20 text-brand-400">
              <Factory className="w-6 h-6" />
            </div>
            <div>
              <h3 className="font-semibold text-white text-sm">Floor Operations</h3>
              <p className="text-xs text-slate-400">Real-time material tracking</p>
            </div>
          </div>
          <div className="flex items-center gap-3 p-4 rounded-2xl bg-white/5 border border-white/10 backdrop-blur-md text-left">
            <div className="p-3 rounded-xl bg-cyan-500/20 text-cyan-400">
              <Cpu className="w-6 h-6" />
            </div>
            <div>
              <h3 className="font-semibold text-white text-sm">AI Predictive Alerts</h3>
              <p className="text-xs text-slate-400">Automated stock forecasting</p>
            </div>
          </div>
          <div className="flex items-center gap-3 p-4 rounded-2xl bg-white/5 border border-white/10 backdrop-blur-md text-left">
            <div className="p-3 rounded-xl bg-emerald-500/20 text-emerald-400">
              <ShieldCheck className="w-6 h-6" />
            </div>
            <div>
              <h3 className="font-semibold text-white text-sm">Quality Assurance</h3>
              <p className="text-xs text-slate-400">Inspection & compliance</p>
            </div>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="relative z-10 py-6 text-center text-sm text-slate-500 border-t border-white/10 backdrop-blur-md bg-slate-950/40">
        AMIC &copy; 2026 Automated Manufacturing Inventory Coordinator. All rights reserved.
      </footer>
    </div>
  );
}
