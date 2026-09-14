import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { 
  Factory, 
  Target, 
  Boxes, 
  TrendingUp, 
  SlidersHorizontal, 
  Cpu, 
  Clock, 
  AlertTriangle, 
  CheckCircle2, 
  ArrowRight,
  RefreshCw,
  Loader2,
  Sparkles,
  Check
} from 'lucide-react';
import AdminLayout from '../../components/Layout/AdminLayout';
import machineService from '../../services/machineService';
import shiftService from '../../services/shiftService';
import adminService from '../../services/adminService';

export default function ProductionDashboard() {
  const [machines, setMachines] = useState([]);
  const [shifts, setShifts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [successMsg, setSuccessMsg] = useState('');
  const [pendingWorkflows, setPendingWorkflows] = useState([]);
  const [approvingId, setApprovingId] = useState(null);

  const fetchData = async () => {
    setLoading(true);
    setError('');
    try {
      const [machinesData, shiftsData, workflowsData] = await Promise.all([
        machineService.getAll(),
        shiftService.getAll(),
        adminService.getAgentWorkflows().catch(() => [])
      ]);
      setMachines(machinesData);
      setShifts(shiftsData);
      if (Array.isArray(workflowsData)) {
        const pending = workflowsData.filter(
          w => (w.status === 3 || w.approvalStatus === 0) && w.status !== 1 && w.status !== 2
        );
        setPendingWorkflows(pending);
      }
    } catch (err) {
      console.error(err);
      setError('Failed to load production data.');
    } finally {
      setLoading(false);
    }
  };

  const handleQuickApprove = async (workflowId) => {
    setApprovingId(workflowId);
    setError('');
    setSuccessMsg('');
    try {
      await adminService.approveWorkflow(workflowId);
      setSuccessMsg(`Workflow ${workflowId} approved! Target machine placed under maintenance.`);
      await fetchData();
    } catch (err) {
      console.error(err);
      setError(err.response?.data?.message || `Failed to approve workflow ${workflowId}.`);
    } finally {
      setApprovingId(null);
    }
  };

  const activeAlertWorkflows = pendingWorkflows.filter(pw => {
    const matchedMachine = machines.find(m => 
      (m.id && pw.objective && pw.objective.toLowerCase().includes(m.id.toLowerCase())) ||
      (m.name && m.name.trim().length > 2 && m.name.toLowerCase() !== 'string' && pw.objective && pw.objective.toLowerCase().includes(m.name.toLowerCase()))
    );

    if (matchedMachine) {
      const isOverdue = matchedMachine.isMaintenanceDue || (matchedMachine.uptimeHours >= matchedMachine.maintenanceIntervalHours);
      return matchedMachine.status === 0 && isOverdue;
    }
    return false;
  });

  useEffect(() => {
    fetchData();
  }, []);

  // Compute metrics from current active or most recent shift
  const currentShift = shifts.find(s => s.status === 1) || shifts[0] || null; // 1 = InProgress
  const totalTarget = currentShift ? currentShift.productionTarget : 0;
  const availableMaterial = currentShift ? currentShift.availableMaterial : 0;
  const adjustedOutput = currentShift ? currentShift.adjustedOutput : 0;
  const maxPossibleOutput = Math.min(totalTarget, availableMaterial);

  const operationalMachines = machines.filter(m => m.status === 0).length;
  const maintenanceDueMachines = machines.filter(m => m.isMaintenanceDue).length;

  return (
    <AdminLayout 
      title="Production & Equipment" 
      subtitle="Real-time capacity scheduling, material limits, and equipment telemetry"
    >
      {/* Top action bar */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-white tracking-tight">Real-Time Production Telemetry</h2>
          <p className="text-sm text-slate-400">Monitoring output constraints and active shift operations</p>
        </div>
        <button
          onClick={fetchData}
          disabled={loading}
          className="flex items-center gap-2 px-4 py-2 bg-slate-800/80 hover:bg-slate-700/80 text-slate-200 rounded-xl border border-white/10 text-sm font-medium transition-all shadow-sm"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin text-brand-400' : ''}`} />
          <span>Refresh Telemetry</span>
        </button>
      </div>

      {/* Success Notification */}
      {successMsg && (
        <div className="p-4 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-sm flex items-center gap-3 animate-in fade-in">
          <CheckCircle2 className="w-5 h-5 shrink-0" />
          <span>{successMsg}</span>
        </div>
      )}

      {/* Autonomous AI Telemetry Alert Banner */}
      {activeAlertWorkflows.length > 0 && (
        <div className="space-y-3">
          {activeAlertWorkflows.map(pw => (
            <div 
              key={pw.id}
              className="p-4 rounded-2xl bg-amber-500/10 border border-amber-500/30 backdrop-blur-xl shadow-lg shadow-amber-500/5 flex flex-col md:flex-row md:items-center justify-between gap-4 animate-in fade-in"
            >
              <div className="flex items-start gap-3.5">
                <div className="p-2.5 rounded-xl bg-amber-500/20 text-amber-300 border border-amber-500/40 shrink-0">
                  <Sparkles className="w-5 h-5 animate-pulse" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-mono text-xs font-bold text-amber-300 bg-amber-500/20 px-2 py-0.5 rounded border border-amber-500/30">
                      {pw.workflowId}
                    </span>
                    <span className="text-xs font-bold uppercase tracking-wider text-amber-200">Autonomous AI Telemetry Alert</span>
                    <span className="px-2 py-0.5 rounded-full text-[10px] font-extrabold bg-amber-400 text-slate-950 animate-pulse">
                      ACTION REQUIRED
                    </span>
                  </div>
                  <p className="text-sm text-slate-200 mt-1 font-medium leading-relaxed">
                    {pw.objective}
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-2.5 shrink-0">
                <button
                  onClick={() => handleQuickApprove(pw.workflowId)}
                  disabled={approvingId === pw.workflowId}
                  className="flex items-center gap-1.5 px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-xs font-bold transition-all shadow-md shadow-emerald-600/20 disabled:opacity-50"
                >
                  {approvingId === pw.workflowId ? (
                    <Loader2 className="w-3.5 h-3.5 animate-spin" />
                  ) : (
                    <Check className="w-3.5 h-3.5" />
                  )}
                  <span>Approve & Place Under Maintenance</span>
                </button>
                <Link
                  to="/admin/agent-workflows"
                  className="px-3.5 py-2 bg-slate-800/90 hover:bg-slate-700 text-slate-300 rounded-xl border border-white/10 text-xs font-semibold transition-colors"
                >
                  View Pipeline
                </Link>
              </div>
            </div>
          ))}
        </div>
      )}

      {error && (
        <div className="p-4 rounded-2xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm flex items-center gap-3">
          <AlertTriangle className="w-5 h-5 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* KPI Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        {/* Production Target */}
        <div className="bg-slate-900/60 border border-white/10 rounded-2xl p-5 backdrop-blur-xl relative overflow-hidden group hover:border-brand-500/30 transition-all">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-400">Production Target</span>
            <div className="p-2 rounded-xl bg-blue-500/10 text-blue-400 border border-blue-500/20">
              <Target className="w-4 h-4" />
            </div>
          </div>
          <div className="text-3xl font-extrabold text-white tracking-tight">
            {loading ? <Loader2 className="w-6 h-6 animate-spin" /> : totalTarget.toLocaleString()}
            <span className="text-xs font-normal text-slate-400 ml-1">units</span>
          </div>
          <p className="text-xs text-slate-400 mt-2">Planned quota for current shift</p>
          <div className="absolute top-0 right-0 w-24 h-24 bg-blue-500/5 rounded-full blur-2xl -z-10 group-hover:bg-blue-500/10 transition-colors" />
        </div>

        {/* Available Material */}
        <div className="bg-slate-900/60 border border-white/10 rounded-2xl p-5 backdrop-blur-xl relative overflow-hidden group hover:border-cyan-500/30 transition-all">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-400">Available Material</span>
            <div className="p-2 rounded-xl bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
              <Boxes className="w-4 h-4" />
            </div>
          </div>
          <div className="text-3xl font-extrabold text-white tracking-tight">
            {loading ? <Loader2 className="w-6 h-6 animate-spin" /> : availableMaterial.toLocaleString()}
            <span className="text-xs font-normal text-slate-400 ml-1">units worth</span>
          </div>
          <p className="text-xs text-slate-400 mt-2">Floor inventory supply level</p>
          <div className="absolute top-0 right-0 w-24 h-24 bg-cyan-500/5 rounded-full blur-2xl -z-10 group-hover:bg-cyan-500/10 transition-colors" />
        </div>

        {/* Max Possible Output */}
        <div className="bg-slate-900/60 border border-white/10 rounded-2xl p-5 backdrop-blur-xl relative overflow-hidden group hover:border-purple-500/30 transition-all">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-400">Max Possible Output</span>
            <div className="p-2 rounded-xl bg-purple-500/10 text-purple-400 border border-purple-500/20">
              <TrendingUp className="w-4 h-4" />
            </div>
          </div>
          <div className="text-3xl font-extrabold text-white tracking-tight">
            {loading ? <Loader2 className="w-6 h-6 animate-spin" /> : maxPossibleOutput.toLocaleString()}
            <span className="text-xs font-normal text-slate-400 ml-1">units</span>
          </div>
          <p className="text-xs text-slate-400 mt-2">Theoretical physical upper bound</p>
          <div className="absolute top-0 right-0 w-24 h-24 bg-purple-500/5 rounded-full blur-2xl -z-10 group-hover:bg-purple-500/10 transition-colors" />
        </div>

        {/* Adjusted Output */}
        <div className="bg-slate-900/60 border border-white/10 rounded-2xl p-5 backdrop-blur-xl relative overflow-hidden group hover:border-emerald-500/30 transition-all">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-400">Adjusted Output</span>
            <div className="p-2 rounded-xl bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
              <SlidersHorizontal className="w-4 h-4" />
            </div>
          </div>
          <div className="text-3xl font-extrabold text-emerald-400 tracking-tight">
            {loading ? <Loader2 className="w-6 h-6 animate-spin" /> : adjustedOutput.toLocaleString()}
            <span className="text-xs font-normal text-slate-400 ml-1">units</span>
          </div>
          <p className="text-xs text-emerald-400/80 mt-2 font-medium">Enforced by Business Rule</p>
          <div className="absolute top-0 right-0 w-24 h-24 bg-emerald-500/5 rounded-full blur-2xl -z-10 group-hover:bg-emerald-500/10 transition-colors" />
        </div>
      </div>

      {/* Two Column Layout: Current Shift & Machine Overview */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Current Shift Card */}
        <div className="lg:col-span-1 bg-slate-900/60 border border-white/10 rounded-3xl p-6 backdrop-blur-xl flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <Clock className="w-5 h-5 text-brand-400" />
                <h3 className="text-base font-bold text-white">Current Active Shift</h3>
              </div>
              <span className={`px-2.5 py-1 text-xs font-semibold rounded-full border ${
                currentShift?.status === 1 
                  ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30 animate-pulse' 
                  : 'bg-slate-800 text-slate-300 border-white/10'
              }`}>
                {currentShift ? (currentShift.status === 1 ? 'In Progress' : currentShift.status === 2 ? 'Completed' : 'Planned') : 'No Active Shift'}
              </span>
            </div>

            {currentShift ? (
              <div className="space-y-4">
                <div>
                  <span className="text-xs text-slate-400">Shift Name</span>
                  <p className="text-lg font-bold text-white">{currentShift.name}</p>
                </div>

                <div className="space-y-2 py-3 border-y border-white/5">
                  <div className="flex justify-between text-sm">
                    <span className="text-slate-400">Target vs Material</span>
                    <span className="font-semibold text-slate-200">
                      {currentShift.productionTarget.toLocaleString()} / {currentShift.availableMaterial.toLocaleString()}
                    </span>
                  </div>
                  {/* Progress bar of material sufficiency */}
                  <div className="w-full bg-slate-800 rounded-full h-2 overflow-hidden">
                    <div 
                      className={`h-full rounded-full transition-all ${
                        currentShift.availableMaterial < currentShift.productionTarget 
                          ? 'bg-amber-500' 
                          : 'bg-emerald-500'
                      }`}
                      style={{ width: `${Math.min(100, (currentShift.availableMaterial / currentShift.productionTarget) * 100)}%` }}
                    />
                  </div>
                  {currentShift.availableMaterial < currentShift.productionTarget && (
                    <p className="text-xs text-amber-400 flex items-center gap-1.5 mt-1">
                      <AlertTriangle className="w-3.5 h-3.5 shrink-0" />
                      Output capped to {currentShift.availableMaterial.toLocaleString()} due to raw material shortage.
                    </p>
                  )}
                </div>

                <div className="grid grid-cols-2 gap-3 text-sm">
                  <div className="bg-white/5 p-3 rounded-xl border border-white/5">
                    <span className="text-xs text-slate-400 block">Actual Output</span>
                    <span className="text-base font-bold text-white">{currentShift.actualOutput.toLocaleString()}</span>
                  </div>
                  <div className="bg-white/5 p-3 rounded-xl border border-white/5">
                    <span className="text-xs text-slate-400 block">Adjusted Output</span>
                    <span className="text-base font-bold text-emerald-400">{currentShift.adjustedOutput.toLocaleString()}</span>
                  </div>
                </div>
              </div>
            ) : (
              <p className="text-sm text-slate-400 py-6 text-center">No shifts scheduled at this time.</p>
            )}
          </div>

          <div className="mt-6 pt-4 border-t border-white/10">
            <Link 
              to="/shifts"
              className="w-full py-2.5 px-4 rounded-xl bg-white/5 hover:bg-white/10 text-white font-semibold text-sm flex items-center justify-center gap-2 border border-white/10 transition-colors"
            >
              <span>Manage Shift Schedules</span>
              <ArrowRight className="w-4 h-4" />
            </Link>
          </div>
        </div>

        {/* Machine Status Overview */}
        <div className="lg:col-span-2 bg-slate-900/60 border border-white/10 rounded-3xl p-6 backdrop-blur-xl flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <Cpu className="w-5 h-5 text-cyan-400" />
                <h3 className="text-base font-bold text-white">Equipment Fleet Health</h3>
              </div>
              <div className="flex items-center gap-2 text-xs">
                <span className="px-2.5 py-1 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-medium">
                  {operationalMachines} Operational
                </span>
                {maintenanceDueMachines > 0 && (
                  <span className="px-2.5 py-1 rounded-full bg-amber-500/10 text-amber-400 border border-amber-500/20 font-medium">
                    {maintenanceDueMachines} Due for Service
                  </span>
                )}
              </div>
            </div>

            <div className="divide-y divide-white/5">
              {machines.slice(0, 4).map((machine) => (
                <div key={machine.id} className="py-3.5 flex items-center justify-between gap-4">
                  <div className="flex items-center gap-3 min-w-0">
                    <div className={`w-3 h-3 rounded-full shrink-0 ${
                      machine.status === 0 ? 'bg-emerald-400 shadow-md shadow-emerald-500/40' :
                      machine.status === 1 ? 'bg-amber-400 shadow-md shadow-amber-500/40' :
                      'bg-slate-500'
                    }`} />
                    <div className="truncate">
                      <p className="text-sm font-semibold text-white truncate">{machine.name}</p>
                      <p className="text-xs text-slate-400">{machine.location || 'Main Floor'}</p>
                    </div>
                  </div>

                  <div className="flex items-center gap-4 text-right shrink-0">
                    <div>
                      <span className="text-xs text-slate-400 block">Uptime</span>
                      <span className="text-sm font-mono text-slate-200">{machine.uptimeHours} / {machine.maintenanceIntervalHours}h</span>
                    </div>

                    <span className={`px-2.5 py-1 rounded-lg text-xs font-semibold border ${
                      machine.isMaintenanceDue
                        ? 'bg-red-500/10 text-red-400 border-red-500/20'
                        : 'bg-slate-800 text-slate-300 border-white/10'
                    }`}>
                      {machine.isMaintenanceDue ? 'Maintenance Due' : `${machine.remainingHours}h left`}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="mt-6 pt-4 border-t border-white/10 flex items-center justify-between">
            <span className="text-xs text-slate-400">Total equipment registered: {machines.length}</span>
            <Link 
              to="/machines"
              className="py-2 px-4 rounded-xl bg-white/5 hover:bg-white/10 text-white font-semibold text-sm flex items-center gap-2 border border-white/10 transition-colors"
            >
              <span>View All Machines</span>
              <ArrowRight className="w-4 h-4" />
            </Link>
          </div>
        </div>
      </div>
    </AdminLayout>
  );
}

