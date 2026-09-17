import { useState, useEffect, useCallback } from 'react';
import { useParams, Link } from 'react-router-dom';
import { 
  ArrowLeft, 
  Wrench, 
  Calculator, 
  Calendar, 
  CheckCircle2, 
  AlertTriangle, 
  Loader2,
  User,
  Plus,
  Sparkles,
  Check,
} from 'lucide-react';
import AdminLayout from '../../components/Layout/AdminLayout';
import machineService from '../../services/machineService';
import maintenanceService from '../../services/maintenanceService';
import adminService from '../../services/adminService';

export default function MachineDetail() {
  const { id } = useParams();
  const [machine, setMachine] = useState(null);
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [calculating, setCalculating] = useState(false);
  const [calcResult, setCalcResult] = useState(null);
  const [error, setError] = useState('');
  const [successMsg, setSuccessMsg] = useState('');
  const [pendingWorkflow, setPendingWorkflow] = useState(null);
  const [approvingWf, setApprovingWf] = useState(false);

  // Add Log modal state
  const [isLogModalOpen, setIsLogModalOpen] = useState(false);
  const [logDescription, setLogDescription] = useState('');
  const [logPerformedBy, setLogPerformedBy] = useState('Tech Specialist');
  const [logType, setLogType] = useState(0); // Scheduled = 0
  const [submittingLog, setSubmittingLog] = useState(false);

  const fetchMachineData = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const [machineData, logsData, workflowsData] = await Promise.all([
        machineService.getById(id),
        maintenanceService.getByMachineId(id),
        adminService.getAgentWorkflows().catch(() => [])
      ]);
      setMachine(machineData);
      setLogs(logsData);

      if (Array.isArray(workflowsData) && machineData) {
        const isOverdue = machineData.isMaintenanceDue || (machineData.uptimeHours >= machineData.maintenanceIntervalHours);
        if ((machineData.status === 0 || machineData.status === 'Operational') && isOverdue) {
          const match = workflowsData.find(w => 
            (w.status === 3 || w.status === 'WaitingForApproval' || w.approvalStatus === 0 || w.approvalStatus === 'Pending') &&
            w.status !== 1 && w.status !== 'Completed' &&
            w.status !== 2 && w.status !== 'Failed' &&
            ((w.objective && machineData.id && w.objective.toLowerCase().includes(machineData.id.toLowerCase())) ||
             (machineData.name && machineData.name.trim().length > 2 && machineData.name.toLowerCase() !== 'string' &&
              w.objective && w.objective.toLowerCase().includes(machineData.name.toLowerCase())))
          );
          setPendingWorkflow(match || null);
        } else {
          setPendingWorkflow(null);
        }
      }
    } catch (err) {
      console.error(err);
      setError('Failed to load machine details or maintenance records.');
    } finally {
      setLoading(false);
    }
  }, [id]);

  const handleApproveWorkflow = async (workflowId) => {
    setApprovingWf(true);
    setError('');
    setSuccessMsg('');
    try {
      await adminService.approveWorkflow(workflowId);
      setSuccessMsg(`AI Workflow ${workflowId} approved! Equipment has been placed Under Maintenance.`);
      await fetchMachineData();
    } catch (err) {
      console.error(err);
      setError(err.response?.data?.message || `Failed to approve workflow ${workflowId}.`);
    } finally {
      setApprovingWf(false);
    }
  };

  useEffect(() => {
    const timer = setTimeout(() => {
      void fetchMachineData();
    }, 0);
    return () => clearTimeout(timer);
  }, [fetchMachineData]);

  const handleCalculateMaintenance = async () => {
    setCalculating(true);
    try {
      const res = await machineService.calculateMaintenance(id);
      setCalcResult(res);
    } catch (err) {
      console.error(err);
      alert('Failed to calculate maintenance due status.');
    } finally {
      setCalculating(false);
    }
  };

  const handleCreateLog = async (e) => {
    e.preventDefault();
    setSubmittingLog(true);
    try {
      await maintenanceService.create({
        machineId: id,
        description: logDescription,
        performedBy: logPerformedBy,
        type: parseInt(logType, 10),
        performedAt: new Date().toISOString()
      });
      setIsLogModalOpen(false);
      setLogDescription('');
      fetchMachineData();
    } catch (err) {
      alert(err.response?.data?.message || 'Failed to submit maintenance log.');
    } finally {
      setSubmittingLog(false);
    }
  };

  const getMaintenanceTypeBadge = (type) => {
    switch (type) {
      case 0:
      case 'Scheduled':
        return <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-blue-500/10 text-blue-400 border border-blue-500/20">Scheduled</span>;
      case 1:
      case 'Emergency':
        return <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-red-500/10 text-red-400 border border-red-500/20">Emergency</span>;
      case 2:
      case 'Preventive':
        return <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">Preventive</span>;
      default:
        return <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-slate-800 text-slate-300">{type || 'Routine'}</span>;
    }
  };

  if (loading) {
    return (
      <AdminLayout title="Machine Telemetry">
        <div className="flex flex-col items-center justify-center py-20 text-slate-400">
          <Loader2 className="w-8 h-8 animate-spin text-brand-400 mb-3" />
          <p>Querying equipment telemetry & maintenance ledger...</p>
        </div>
      </AdminLayout>
    );
  }

  if (error || !machine) {
    return (
      <AdminLayout title="Machine Not Found">
        <div className="bg-red-500/10 border border-red-500/20 rounded-2xl p-6 text-center max-w-md mx-auto">
          <AlertTriangle className="w-10 h-10 text-red-400 mx-auto mb-3" />
          <h3 className="text-lg font-bold text-white mb-1">Equipment Record Missing</h3>
          <p className="text-sm text-red-300 mb-4">{error || 'Requested machine could not be located.'}</p>
          <Link to="/machines" className="inline-flex items-center gap-2 px-4 py-2 bg-white/10 hover:bg-white/20 text-white rounded-xl text-sm font-semibold transition-colors">
            <ArrowLeft className="w-4 h-4" /> Back to Fleet
          </Link>
        </div>
      </AdminLayout>
    );
  }

  return (
    <AdminLayout 
      title={machine.name} 
      subtitle={`ID: ${machine.id} | Location: ${machine.location || 'Main Production Floor'}`}
    >
      {/* Back Link & Primary Action */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <Link 
          to="/machines" 
          className="inline-flex items-center gap-2 text-sm text-slate-400 hover:text-white transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          <span>Back to Fleet Overview</span>
        </Link>

        <div className="flex items-center gap-3">
          <button
            onClick={handleCalculateMaintenance}
            disabled={calculating}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-white/10 text-sm font-semibold transition-all shadow-sm"
          >
            <Calculator className={`w-4 h-4 ${calculating ? 'animate-spin text-brand-400' : 'text-brand-400'}`} />
            <span>{calculating ? 'Computing...' : 'Calculate Maintenance Due'}</span>
          </button>

          <button
            onClick={() => setIsLogModalOpen(true)}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-brand-600 to-cyan-600 hover:from-brand-500 hover:to-cyan-500 text-white text-sm font-semibold transition-all shadow-md shadow-brand-500/20"
          >
            <Plus className="w-4 h-4" />
            <span>Log Maintenance</span>
          </button>
        </div>
      </div>

      {/* Success Notification */}
      {successMsg && (
        <div className="p-4 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-sm flex items-center gap-3 animate-in fade-in">
          <CheckCircle2 className="w-5 h-5 shrink-0" />
          <span>{successMsg}</span>
        </div>
      )}

      {/* Autonomous AI Telemetry Alert Box */}
      {pendingWorkflow && (
        <div className="p-6 rounded-3xl bg-amber-500/10 border border-amber-500/40 text-white backdrop-blur-xl shadow-xl shadow-amber-500/10 animate-in fade-in space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div className="flex items-center gap-3">
              <div className="p-2.5 rounded-2xl bg-amber-500/20 text-amber-300 border border-amber-500/40">
                <Sparkles className="w-6 h-6 animate-pulse" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <span className="font-mono text-xs font-bold text-amber-300 bg-amber-500/20 px-2.5 py-0.5 rounded-lg border border-amber-500/40">
                    {pendingWorkflow.workflowId}
                  </span>
                  <span className="text-xs font-bold uppercase tracking-wider text-amber-200">Autonomous Overhaul Authorization</span>
                </div>
                <h4 className="text-base font-bold text-white mt-1">Autonomous Maintenance Overhaul Awaiting Approval</h4>
              </div>
            </div>
            <span className="px-3 py-1 rounded-full text-xs font-extrabold bg-amber-400 text-slate-950 uppercase tracking-wider animate-pulse self-start sm:self-auto">
              ACTION REQUIRED
            </span>
          </div>

          <div className="p-4 rounded-2xl bg-black/40 border border-white/5 space-y-2">
            <p className="text-sm text-slate-200 font-medium">
              {pendingWorkflow.objective}
            </p>
            <p className="text-xs text-slate-400">
              Supervised by <strong className="text-white">{pendingWorkflow.currentAgent}</strong>. Approving will automatically switch machine status to <strong className="text-amber-400">Under Maintenance</strong> and register a preventive overhaul record in the maintenance ledger.
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-3 pt-1">
            <button
              onClick={() => handleApproveWorkflow(pendingWorkflow.workflowId)}
              disabled={approvingWf}
              className="flex items-center gap-2 px-5 py-2.5 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-sm font-bold transition-all shadow-lg shadow-emerald-600/30 disabled:opacity-50"
            >
              {approvingWf ? <Loader2 className="w-4 h-4 animate-spin" /> : <Check className="w-4 h-4" />}
              <span>Approve & Place Under Maintenance</span>
            </button>

            <Link
              to="/admin/agent-workflows"
              className="px-4 py-2.5 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-xl border border-white/10 text-sm font-semibold transition-colors"
            >
              View in AI Workflows Console
            </Link>
          </div>
        </div>
      )}

      {/* Live Calculation Banner if triggered */}
      {calcResult && (
        <div className="p-5 rounded-2xl bg-brand-500/10 border border-brand-500/30 text-white backdrop-blur-xl animate-in fade-in slide-in-from-top-3">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
              <Calculator className="w-5 h-5 text-brand-400" />
              <h4 className="font-bold text-sm tracking-wide uppercase">Maintenance Interval Evaluation Rule</h4>
            </div>
            <span className={`px-3 py-1 rounded-full text-xs font-bold border ${
              calcResult.isMaintenanceDue 
                ? 'bg-red-500/20 text-red-400 border-red-500/30 animate-pulse'
                : 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30'
            }`}>
              {calcResult.isMaintenanceDue ? 'MAINTENANCE REQUIRED' : 'OPERATIONAL SAFE'}
            </span>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 text-xs font-mono bg-black/30 p-3.5 rounded-xl border border-white/5">
            <div>
              <span className="text-slate-400 block">Current Uptime</span>
              <span className="text-base font-bold text-white">{calcResult.uptimeHours} hrs</span>
            </div>
            <div>
              <span className="text-slate-400 block">Service Interval</span>
              <span className="text-base font-bold text-white">{calcResult.maintenanceIntervalHours} hrs</span>
            </div>
            <div>
              <span className="text-slate-400 block">Remaining Hours</span>
              <span className="text-base font-bold text-cyan-400">{calcResult.remainingHours} hrs</span>
            </div>
            <div>
              <span className="text-slate-400 block">Overdue Condition</span>
              <span className={`text-base font-bold ${calcResult.isMaintenanceDue ? 'text-red-400' : 'text-emerald-400'}`}>
                {calcResult.isMaintenanceDue ? 'YES (Remaining <= 0)' : 'NO (Within limits)'}
              </span>
            </div>
          </div>
        </div>
      )}

      {/* Metrics Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <div className="bg-slate-900/60 border border-white/10 rounded-2xl p-5 backdrop-blur-xl">
          <span className="text-xs uppercase tracking-wider text-slate-400 font-semibold block mb-1">Fleet Status</span>
          <div className="flex items-center gap-2 mt-2">
            <div className={`w-3 h-3 rounded-full ${
              (machine.status === 0 || machine.status === 'Operational') ? 'bg-emerald-400 shadow-lg shadow-emerald-500/50' :
              (machine.status === 1 || machine.status === 'UnderMaintenance') ? 'bg-amber-400 shadow-lg shadow-amber-500/50' : 'bg-red-400'
            }`} />
            <span className="text-lg font-bold text-white">
              {(machine.status === 0 || machine.status === 'Operational') ? 'Operational' :
               (machine.status === 1 || machine.status === 'UnderMaintenance') ? 'Under Maintenance' : 'Offline'}
            </span>
          </div>
        </div>

        <div className="bg-slate-900/60 border border-white/10 rounded-2xl p-5 backdrop-blur-xl">
          <span className="text-xs uppercase tracking-wider text-slate-400 font-semibold block mb-1">Total Operating Uptime</span>
          <p className="text-2xl font-extrabold text-white mt-1 font-mono">{machine.uptimeHours} <span className="text-xs font-normal text-slate-400">hours</span></p>
        </div>

        <div className="bg-slate-900/60 border border-white/10 rounded-2xl p-5 backdrop-blur-xl">
          <span className="text-xs uppercase tracking-wider text-slate-400 font-semibold block mb-1">Maintenance Interval</span>
          <p className="text-2xl font-extrabold text-white mt-1 font-mono">{machine.maintenanceIntervalHours} <span className="text-xs font-normal text-slate-400">hours</span></p>
        </div>

        <div className="bg-slate-900/60 border border-white/10 rounded-2xl p-5 backdrop-blur-xl">
          <span className="text-xs uppercase tracking-wider text-slate-400 font-semibold block mb-1">Remaining Safe Runtime</span>
          <p className={`text-2xl font-extrabold mt-1 font-mono ${machine.remainingHours <= 50 ? 'text-amber-400' : 'text-emerald-400'}`}>
            {machine.remainingHours} <span className="text-xs font-normal text-slate-400">hours</span>
          </p>
        </div>
      </div>

      {/* Maintenance History Timeline */}
      <div className="bg-slate-900/60 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <div className="flex items-center justify-between mb-6 pb-4 border-b border-white/10">
          <div className="flex items-center gap-2">
            <Wrench className="w-5 h-5 text-brand-400" />
            <h3 className="text-base font-bold text-white">Service History & Maintenance Ledger</h3>
          </div>
          <span className="text-xs text-slate-400">Recorded events: {logs.length}</span>
        </div>

        {logs.length === 0 ? (
          <div className="text-center py-12 text-slate-400">
            <Wrench className="w-8 h-8 mx-auto mb-2 text-slate-600" />
            <p className="text-sm">No maintenance interventions recorded for this machine.</p>
          </div>
        ) : (
          <div className="space-y-4">
            {logs.map((log) => (
              <div 
                key={log.id}
                className="p-4 rounded-2xl bg-white/5 border border-white/5 hover:border-white/10 transition-colors flex flex-col sm:flex-row sm:items-center justify-between gap-4"
              >
                <div className="space-y-1">
                  <div className="flex items-center gap-2.5">
                    {getMaintenanceTypeBadge(log.type)}
                    <span className="text-xs text-slate-400 flex items-center gap-1 font-mono">
                      <Calendar className="w-3.5 h-3.5" />
                      {new Date(log.performedAt).toLocaleString()}
                    </span>
                  </div>
                  <p className="text-sm text-slate-200 font-medium pt-1">{log.description}</p>
                </div>

                <div className="flex items-center gap-2 text-xs text-slate-400 bg-slate-950/40 px-3 py-1.5 rounded-xl border border-white/5 shrink-0">
                  <User className="w-3.5 h-3.5 text-brand-400" />
                  <span>{log.performedBy}</span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Log Maintenance Modal */}
      {isLogModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-in fade-in">
          <div className="bg-slate-900 border border-white/10 rounded-2xl w-full max-w-lg p-6 shadow-2xl">
            <h3 className="text-lg font-bold text-white mb-1 flex items-center gap-2">
              <Wrench className="w-5 h-5 text-brand-400" />
              Log Equipment Maintenance
            </h3>
            <p className="text-xs text-slate-400 mb-4">Record repair, inspection, or scheduled servicing for {machine.name}</p>

            <form onSubmit={handleCreateLog} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">Service Type *</label>
                <select
                  value={logType}
                  onChange={(e) => setLogType(e.target.value)}
                  className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none"
                >
                  <option value={0}>Scheduled Maintenance</option>
                  <option value={1}>Emergency Repair</option>
                  <option value={2}>Preventive Servicing</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">Technician Name *</label>
                <input
                  type="text"
                  required
                  value={logPerformedBy}
                  onChange={(e) => setLogPerformedBy(e.target.value)}
                  placeholder="e.g. Lead Tech Sarah Smith"
                  className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">Intervention Details & Remarks *</label>
                <textarea
                  rows={3}
                  required
                  value={logDescription}
                  onChange={(e) => setLogDescription(e.target.value)}
                  placeholder="Describe parts replaced, fluids replenished, or sensor calibration performed..."
                  className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-4 border-t border-white/10">
                <button
                  type="button"
                  onClick={() => setIsLogModalOpen(false)}
                  className="px-4 py-2 rounded-xl text-sm font-semibold text-slate-300 hover:text-white hover:bg-white/5 border border-white/10"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submittingLog}
                  className="px-5 py-2 rounded-xl text-sm font-semibold text-white bg-gradient-to-r from-brand-600 to-cyan-600 hover:from-brand-500 hover:to-cyan-500 disabled:opacity-50"
                >
                  {submittingLog ? 'Saving...' : 'Submit Log'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </AdminLayout>
  );
}

