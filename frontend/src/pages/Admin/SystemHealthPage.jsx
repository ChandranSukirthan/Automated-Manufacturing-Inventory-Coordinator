import { useState, useEffect } from 'react';
import { 
  Activity, 
  RefreshCw, 
  AlertTriangle, 
  Server, 
  Database, 
  Bot, 
  Layers, 
  Globe, 
  Loader2,
} from 'lucide-react';
import AdminLayout from '../../components/Layout/AdminLayout';
import adminService from '../../services/adminService';

export default function SystemHealthPage() {
  const [healthData, setHealthData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [lastChecked, setLastChecked] = useState(null);
  const [error, setError] = useState('');

  const fetchHealth = async (isManual = false) => {
    if (isManual) setRefreshing(true);
    else setLoading(true);
    setError('');

    try {
      const data = await adminService.getSystemHealth();
      setHealthData(data);
      setLastChecked(new Date());
    } catch (err) {
      console.error(err);
      setError('Failed to query cluster diagnostic endpoints.');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    const timer = setTimeout(() => {
      void fetchHealth();
    }, 0);
    return () => clearTimeout(timer);
  }, []);

  const getServiceIcon = (name) => {
    switch (name) {
      case 'ASP.NET API':
        return <Server className="w-6 h-6 text-blue-400" />;
      case 'PostgreSQL':
        return <Database className="w-6 h-6 text-cyan-400" />;
      case 'FastAPI':
        return <Layers className="w-6 h-6 text-emerald-400" />;
      case 'Agentic AI':
        return <Bot className="w-6 h-6 text-purple-400" />;
      default:
        return <Globe className="w-6 h-6 text-amber-400" />;
    }
  };

  const getStatusBadge = (status) => {
    switch (status) {
      case 'ONLINE':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
            ONLINE
          </span>
        );
      case 'OFFLINE':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-red-500/10 text-red-400 border border-red-500/20">
            <span className="w-2 h-2 rounded-full bg-red-400" />
            OFFLINE
          </span>
        );
      case 'DEGRADED':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-amber-500/10 text-amber-400 border border-amber-500/20">
            <span className="w-2 h-2 rounded-full bg-amber-400" />
            DEGRADED
          </span>
        );
      default:
        return (
          <span className="px-3 py-1 rounded-full text-xs font-bold bg-slate-800 text-slate-300">
            UNKNOWN
          </span>
        );
    }
  };

  return (
    <AdminLayout 
      title="System Health & Infrastructure" 
      subtitle="Live uptime, microservice availability, and database connectivity monitoring"
    >
      {/* Overview Banner */}
      <div className="bg-slate-900/60 border border-white/10 rounded-3xl p-6 backdrop-blur-xl flex flex-col sm:flex-row sm:items-center justify-between gap-6 shadow-xl">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-brand-500/20 to-cyan-500/20 border border-brand-500/30 flex items-center justify-center">
            <Activity className="w-8 h-8 text-brand-400" />
          </div>
          <div>
            <span className="text-xs uppercase tracking-wider font-semibold text-slate-400">Cluster Overall Status</span>
            <div className="flex items-center gap-3 mt-1">
              <h2 className="text-2xl sm:text-3xl font-extrabold text-white tracking-tight">
                {loading ? 'Diagnosing...' : healthData?.overallStatus || 'DEGRADED'}
              </h2>
              {healthData && getStatusBadge(healthData.overallStatus)}
            </div>
          </div>
        </div>

        <div className="flex flex-col sm:items-end gap-2 shrink-0">
          <button
            onClick={() => fetchHealth(true)}
            disabled={refreshing}
            className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-brand-600 to-cyan-600 hover:from-brand-500 hover:to-cyan-500 text-white font-semibold rounded-xl text-sm transition-all shadow-md shadow-brand-500/20 disabled:opacity-50"
          >
            <RefreshCw className={`w-4 h-4 ${refreshing ? 'animate-spin' : ''}`} />
            <span>{refreshing ? 'Polling Services...' : 'Run Diagnostics'}</span>
          </button>
          {lastChecked && (
            <span className="text-xs text-slate-400 font-mono">
              Last check: {lastChecked.toLocaleTimeString()}
            </span>
          )}
        </div>
      </div>

      {error && (
        <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm flex items-center gap-3">
          <AlertTriangle className="w-5 h-5 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Microservice Health Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
        {loading ? (
          <div className="col-span-full py-16 text-center text-slate-400">
            <Loader2 className="w-8 h-8 animate-spin mx-auto text-brand-400 mb-2" />
            Pinging subsystem health endpoints...
          </div>
        ) : (
          healthData?.services.map((service, idx) => (
            <div 
              key={idx}
              className="bg-slate-900/60 border border-white/10 rounded-2xl p-6 backdrop-blur-xl flex flex-col justify-between space-y-4 hover:border-white/20 transition-all shadow-lg"
            >
              <div className="flex items-start justify-between">
                <div className="p-3 rounded-2xl bg-white/5 border border-white/10">
                  {getServiceIcon(service.name)}
                </div>
                {getStatusBadge(service.status)}
              </div>

              <div>
                <h3 className="text-lg font-bold text-white tracking-tight">{service.name}</h3>
                <p className="text-xs text-slate-400 mt-1 leading-relaxed">{service.message || 'Service telemetry nominal.'}</p>
              </div>

              <div className="pt-3 border-t border-white/5 flex items-center justify-between text-xs text-slate-500 font-mono">
                <span>Protocol: HTTP/REST</span>
                <span className="text-slate-400">Auto-pinging</span>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Operational Note */}
      <div className="p-4 rounded-2xl bg-white/5 border border-white/10 text-xs text-slate-400 backdrop-blur-xl flex items-center justify-between">
        <span>FastAPI and Agentic AI microservices will turn <strong className="text-emerald-400">ONLINE</strong> as soon as the Agentic AI service is launched.</span>
        <span className="font-mono text-slate-500 hidden sm:inline">Port 5070 / 5432</span>
      </div>
    </AdminLayout>
  );
}

