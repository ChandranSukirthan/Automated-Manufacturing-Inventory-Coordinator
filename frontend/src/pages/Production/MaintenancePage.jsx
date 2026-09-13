import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { 
  Wrench, 
  Plus, 
  AlertTriangle, 
  CheckCircle2, 
  Clock, 
  Search, 
  Calendar, 
  Cpu, 
  User, 
  Loader2,
  X,
  ExternalLink
} from 'lucide-react';
import AdminLayout from '../../components/Layout/AdminLayout';
import machineService from '../../services/machineService';
import maintenanceService from '../../services/maintenanceService';

export default function MaintenancePage() {
  const [machines, setMachines] = useState([]);
  const [selectedMachineId, setSelectedMachineId] = useState('');
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [logsLoading, setLogsLoading] = useState(false);
  const [search, setSearch] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Log Creation Modal
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [modalMachineId, setModalMachineId] = useState('');
  const [description, setDescription] = useState('');
  const [performedBy, setPerformedBy] = useState('');
  const [type, setType] = useState(0);
  const [submitting, setSubmitting] = useState(false);

  const fetchFleet = async () => {
    setLoading(true);
    try {
      const data = await machineService.getAll();
      setMachines(data);
      if (data.length > 0 && !selectedMachineId) {
        setSelectedMachineId(data[0].id);
      }
    } catch (err) {
      console.error(err);
      setError('Failed to fetch machine equipment fleet.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchFleet();
  }, []);

  // Fetch logs whenever selected machine changes
  useEffect(() => {
    if (!selectedMachineId) return;

    const fetchLogs = async () => {
      setLogsLoading(true);
      try {
        const data = await maintenanceService.getByMachineId(selectedMachineId);
        setLogs(data);
      } catch (err) {
        console.error(err);
      } finally {
        setLogsLoading(false);
      }
    };

    fetchLogs();
  }, [selectedMachineId]);

  const openLogModal = (machineId = null) => {
    setModalMachineId(machineId || selectedMachineId || (machines[0]?.id || ''));
    setDescription('');
    setPerformedBy('Technician Specialist');
    setType(0);
    setIsModalOpen(true);
  };

  const handleCreateLog = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    setError('');
    setSuccess('');

    try {
      await maintenanceService.create({
        machineId: modalMachineId,
        description,
        performedBy,
        type: parseInt(type, 10),
        performedAt: new Date().toISOString()
      });

      setSuccess('Maintenance record added to ledger.');
      setIsModalOpen(false);

      // Refresh both machines & logs
      const updatedMachines = await machineService.getAll();
      setMachines(updatedMachines);
      if (modalMachineId === selectedMachineId) {
        const updatedLogs = await maintenanceService.getByMachineId(selectedMachineId);
        setLogs(updatedLogs);
      }
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to submit maintenance log.');
    } finally {
      setSubmitting(false);
    }
  };

  const selectedMachine = machines.find(m => m.id === selectedMachineId);

  const getMaintenanceTypeBadge = (typeVal) => {
    switch (typeVal) {
      case 0:
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-blue-500/10 text-blue-400 border border-blue-500/20">Scheduled</span>;
      case 1:
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-red-500/10 text-red-400 border border-red-500/20">Emergency</span>;
      case 2:
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">Preventive</span>;
      default:
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-800 text-slate-300">Routine</span>;
    }
  };

  return (
    <AdminLayout 
      title="Maintenance & Equipment Servicing" 
      subtitle="Track operating cycles, service intervals, and preventative intervention history"
    >
      {/* Header Actions */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-white tracking-tight">Machine Maintenance Ledger</h2>
          <p className="text-sm text-slate-400">Monitoring safe run hours vs required service intervals</p>
        </div>

        <button
          onClick={() => openLogModal()}
          className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-brand-600 to-cyan-600 hover:from-brand-500 hover:to-cyan-500 text-white font-semibold rounded-xl text-sm transition-all shadow-lg shadow-brand-500/20 shrink-0"
        >
          <Plus className="w-4 h-4" />
          <span>Log Maintenance Event</span>
        </button>
      </div>

      {error && (
        <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm flex items-center gap-3">
          <AlertTriangle className="w-5 h-5 shrink-0" />
          <span>{error}</span>
        </div>
      )}
      {success && (
        <div className="p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-sm flex items-center gap-3">
          <CheckCircle2 className="w-5 h-5 shrink-0" />
          <span>{success}</span>
        </div>
      )}

      {/* Fleet Interval Overview Table */}
      <div className="bg-slate-900/60 border border-white/10 rounded-2xl overflow-hidden backdrop-blur-xl">
        <div className="p-5 border-b border-white/10 flex items-center justify-between">
          <h3 className="text-base font-bold text-white flex items-center gap-2">
            <Cpu className="w-4 h-4 text-brand-400" />
            Equipment Fleet Telemetry & Overdue Status
          </h3>
          <span className="text-xs text-slate-400">Click a machine to inspect its history</span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b border-white/10 bg-white/5 text-xs uppercase tracking-wider text-slate-400">
                <th className="py-3 px-4">Machine</th>
                <th className="py-3 px-4">Uptime Hours</th>
                <th className="py-3 px-4">Interval Hours</th>
                <th className="py-3 px-4">Remaining Hours</th>
                <th className="py-3 px-4">Status</th>
                <th className="py-3 px-4 text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5 text-sm">
              {loading ? (
                <tr>
                  <td colSpan={6} className="py-8 text-center text-slate-400">
                    <Loader2 className="w-6 h-6 animate-spin mx-auto text-brand-400 mb-2" />
                    Loading equipment status...
                  </td>
                </tr>
              ) : machines.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-8 text-center text-slate-400">
                    No equipment currently registered.
                  </td>
                </tr>
              ) : (
                machines.map((m) => {
                  const isSelected = m.id === selectedMachineId;
                  return (
                    <tr 
                      key={m.id}
                      onClick={() => setSelectedMachineId(m.id)}
                      className={`cursor-pointer transition-colors ${
                        isSelected 
                          ? 'bg-brand-500/10 border-l-4 border-l-brand-500' 
                          : 'hover:bg-white/[0.02]'
                      }`}
                    >
                      <td className="py-3.5 px-4 font-semibold text-white">
                        <div className="flex items-center gap-2">
                          <Cpu className={`w-4 h-4 ${isSelected ? 'text-brand-400' : 'text-slate-400'}`} />
                          <span>{m.name}</span>
                        </div>
                      </td>
                      <td className="py-3.5 px-4 font-mono text-slate-200">{m.uptimeHours} hrs</td>
                      <td className="py-3.5 px-4 font-mono text-slate-200">{m.maintenanceIntervalHours} hrs</td>
                      <td className="py-3.5 px-4 font-mono font-medium">
                        <span className={m.remainingHours <= 50 ? 'text-amber-400 font-bold' : 'text-slate-300'}>
                          {m.remainingHours} hrs
                        </span>
                      </td>
                      <td className="py-3.5 px-4">
                        {m.isMaintenanceDue ? (
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-red-500/20 text-red-400 border border-red-500/30">
                            <AlertTriangle className="w-3.5 h-3.5" />
                            DUE NOW
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                            <CheckCircle2 className="w-3.5 h-3.5" />
                            OK
                          </span>
                        )}
                      </td>
                      <td className="py-3.5 px-4 text-right">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            openLogModal(m.id);
                          }}
                          className="px-3 py-1.5 rounded-lg bg-white/5 hover:bg-white/10 text-xs font-semibold text-slate-300 hover:text-white border border-white/10 transition-colors"
                        >
                          + Log Service
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Selected Machine History Section */}
      {selectedMachine && (
        <div className="bg-slate-900/60 border border-white/10 rounded-3xl p-6 backdrop-blur-xl space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-white/10">
            <div>
              <h3 className="text-lg font-bold text-white flex items-center gap-2">
                <Wrench className="w-5 h-5 text-brand-400" />
                Maintenance History: {selectedMachine.name}
              </h3>
              <p className="text-xs text-slate-400">
                Uptime: <span className="text-slate-200 font-mono font-semibold">{selectedMachine.uptimeHours}h</span> / Interval: <span className="text-slate-200 font-mono font-semibold">{selectedMachine.maintenanceIntervalHours}h</span>
              </p>
            </div>

            <Link
              to={`/machines/${selectedMachine.id}`}
              className="inline-flex items-center gap-2 text-xs text-brand-400 hover:text-brand-300 font-semibold"
            >
              <span>Inspect Full Machine Spec</span>
              <ExternalLink className="w-3.5 h-3.5" />
            </Link>
          </div>

          {logsLoading ? (
            <div className="py-8 text-center text-slate-400">
              <Loader2 className="w-6 h-6 animate-spin mx-auto text-brand-400 mb-2" />
              Loading maintenance logs for {selectedMachine.name}...
            </div>
          ) : logs.length === 0 ? (
            <div className="py-8 text-center text-slate-400">
              <p className="text-sm">No recorded service events for this machine yet.</p>
            </div>
          ) : (
            <div className="divide-y divide-white/5">
              {logs.map((log) => (
                <div key={log.id} className="py-3.5 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      {getMaintenanceTypeBadge(log.type)}
                      <span className="text-xs text-slate-400 font-mono flex items-center gap-1">
                        <Calendar className="w-3.5 h-3.5" />
                        {new Date(log.performedAt).toLocaleDateString()} at {new Date(log.performedAt).toLocaleTimeString()}
                      </span>
                    </div>
                    <p className="text-sm text-slate-200 font-medium">{log.description}</p>
                  </div>

                  <div className="flex items-center gap-2 text-xs text-slate-400 bg-slate-950/40 px-3 py-1.5 rounded-xl border border-white/5 shrink-0 self-start sm:self-auto">
                    <User className="w-3.5 h-3.5 text-brand-400" />
                    <span>{log.performedBy}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Log Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-in fade-in">
          <div className="bg-slate-900 border border-white/10 rounded-2xl w-full max-w-lg p-6 shadow-2xl">
            <div className="flex items-center justify-between pb-4 border-b border-white/10">
              <h3 className="text-lg font-bold text-white flex items-center gap-2">
                <Wrench className="w-5 h-5 text-brand-400" />
                Record Maintenance Intervention
              </h3>
              <button 
                onClick={() => setIsModalOpen(false)}
                className="text-slate-400 hover:text-white p-1 rounded-lg hover:bg-white/5"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleCreateLog} className="space-y-4 pt-4">
              <div>
                <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">Target Equipment *</label>
                <select
                  value={modalMachineId}
                  onChange={(e) => setModalMachineId(e.target.value)}
                  className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none"
                >
                  {machines.map((m) => (
                    <option key={m.id} value={m.id}>
                      {m.name} ({m.isMaintenanceDue ? 'DUE' : `${m.remainingHours}h remaining`})
                    </option>
                  ))}
                </select>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">Service Type *</label>
                  <select
                    value={type}
                    onChange={(e) => setType(e.target.value)}
                    className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none"
                  >
                    <option value={0}>Scheduled Maintenance</option>
                    <option value={1}>Emergency Repair</option>
                    <option value={2}>Preventive Servicing</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">Assigned Technician *</label>
                  <input
                    type="text"
                    required
                    value={performedBy}
                    onChange={(e) => setPerformedBy(e.target.value)}
                    placeholder="e.g. Lead Tech John Doe"
                    className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">Work Done & Component Notes *</label>
                <textarea
                  rows={3}
                  required
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="Detail operations performed, components replaced, or diagnostic results..."
                  className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-4 border-t border-white/10">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2 rounded-xl text-sm font-semibold text-slate-300 hover:text-white hover:bg-white/5 border border-white/10"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-5 py-2 rounded-xl text-sm font-semibold text-white bg-gradient-to-r from-brand-600 to-cyan-600 hover:from-brand-500 hover:to-cyan-500 disabled:opacity-50"
                >
                  {submitting ? 'Logging...' : 'Save to Ledger'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </AdminLayout>
  );
}

