import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { 
  Cpu, 
  Plus, 
  Search, 
  AlertTriangle, 
  CheckCircle2, 
  Trash2, 
  Edit, 
  Wrench, 
  ExternalLink,
  Loader2,
  X
} from 'lucide-react';
import AdminLayout from '../../components/Layout/AdminLayout';
import machineService from '../../services/machineService';

export default function MachineList() {
  const [machines, setMachines] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Modal State
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingMachine, setEditingMachine] = useState(null);
  const [submitting, setSubmitting] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    status: 0,
    uptimeHours: 0,
    maintenanceIntervalHours: 500,
    location: ''
  });

  const fetchMachines = async () => {
    setLoading(true);
    try {
      const data = await machineService.getAll();
      setMachines(data);
    } catch (err) {
      console.error(err);
      setError('Failed to fetch machines from backend.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMachines();
  }, []);

  const openCreateModal = () => {
    setEditingMachine(null);
    setFormData({
      name: '',
      status: 0,
      uptimeHours: 0,
      maintenanceIntervalHours: 500,
      location: ''
    });
    setIsModalOpen(true);
  };

  const openEditModal = (machine) => {
    setEditingMachine(machine);
    setFormData({
      name: machine.name,
      status: machine.status,
      uptimeHours: machine.uptimeHours,
      maintenanceIntervalHours: machine.maintenanceIntervalHours,
      location: machine.location || ''
    });
    setIsModalOpen(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    setError('');
    setSuccess('');

    try {
      if (editingMachine) {
        await machineService.update(editingMachine.id, {
          ...formData,
          status: parseInt(formData.status, 10),
          uptimeHours: parseFloat(formData.uptimeHours),
          maintenanceIntervalHours: parseFloat(formData.maintenanceIntervalHours)
        });
        setSuccess('Machine updated successfully.');
      } else {
        await machineService.create({
          ...formData,
          status: parseInt(formData.status, 10),
          uptimeHours: parseFloat(formData.uptimeHours),
          maintenanceIntervalHours: parseFloat(formData.maintenanceIntervalHours)
        });
        setSuccess('New machine registered successfully.');
      }
      setIsModalOpen(false);
      fetchMachines();
    } catch (err) {
      setError(err.response?.data?.message || 'Operation failed.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async (id, name) => {
    if (!window.confirm(`Are you sure you want to decommission "${name}"? This action cannot be undone.`)) {
      return;
    }

    try {
      await machineService.delete(id);
      setSuccess(`Machine "${name}" deleted.`);
      fetchMachines();
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to delete machine.');
    }
  };

  const getStatusBadge = (status) => {
    switch (status) {
      case 0:
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">Operational</span>;
      case 1:
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-amber-500/10 text-amber-400 border border-amber-500/20">Under Maintenance</span>;
      case 2:
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-red-500/10 text-red-400 border border-red-500/20">Offline</span>;
      default:
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-800 text-slate-400">Unknown</span>;
    }
  };

  const filteredMachines = machines.filter(m => 
    m.name.toLowerCase().includes(search.toLowerCase()) ||
    m.location?.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <AdminLayout 
      title="Machine Fleet Management" 
      subtitle="Register, monitor telemetry, and schedule maintenance on industrial machinery"
    >
      {/* Action Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="relative flex-1 max-w-md">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search by machine name or sector location..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-9 pr-4 py-2 bg-slate-900/60 border border-white/10 rounded-xl text-sm text-white placeholder-slate-500 focus:ring-2 focus:ring-brand-500 focus:outline-none"
          />
        </div>

        <button
          onClick={openCreateModal}
          className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-brand-600 to-cyan-600 hover:from-brand-500 hover:to-cyan-500 text-white font-semibold rounded-xl text-sm transition-all shadow-lg shadow-brand-500/20 shrink-0"
        >
          <Plus className="w-4 h-4" />
          <span>Register New Machine</span>
        </button>
      </div>

      {/* Alerts */}
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

      {/* Machine Data Table */}
      <div className="bg-slate-900/60 border border-white/10 rounded-2xl overflow-hidden backdrop-blur-xl shadow-xl">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b border-white/10 bg-white/5 text-xs uppercase tracking-wider text-slate-400">
                <th className="py-3.5 px-4 font-semibold">Machine Name</th>
                <th className="py-3.5 px-4 font-semibold">Status</th>
                <th className="py-3.5 px-4 font-semibold">Uptime</th>
                <th className="py-3.5 px-4 font-semibold">Interval</th>
                <th className="py-3.5 px-4 font-semibold">Remaining</th>
                <th className="py-3.5 px-4 font-semibold">Maintenance Due</th>
                <th className="py-3.5 px-4 font-semibold text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5 text-sm">
              {loading ? (
                <tr>
                  <td colSpan={7} className="py-12 text-center text-slate-400">
                    <Loader2 className="w-6 h-6 animate-spin mx-auto mb-2 text-brand-400" />
                    Loading machine fleet telemetry...
                  </td>
                </tr>
              ) : filteredMachines.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-12 text-center text-slate-400">
                    No machines found matching your query.
                  </td>
                </tr>
              ) : (
                filteredMachines.map((m) => (
                  <tr key={m.id} className="hover:bg-white/[0.02] transition-colors group">
                    <td className="py-3.5 px-4 font-semibold text-white">
                      <Link 
                        to={`/machines/${m.id}`}
                        className="flex items-center gap-2 hover:text-brand-400 transition-colors"
                      >
                        <Cpu className="w-4 h-4 text-brand-400 shrink-0" />
                        <span>{m.name}</span>
                      </Link>
                      <span className="block text-xs text-slate-400 font-normal">{m.location || 'Unassigned location'}</span>
                    </td>
                    <td className="py-3.5 px-4">{getStatusBadge(m.status)}</td>
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
                          OVERDUE
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                          <CheckCircle2 className="w-3.5 h-3.5" />
                          Healthy
                        </span>
                      )}
                    </td>
                    <td className="py-3.5 px-4 text-right">
                      <div className="flex items-center justify-end gap-2">
                        <Link
                          to={`/machines/${m.id}`}
                          title="View telemetry & maintenance logs"
                          className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-white/10 transition-colors"
                        >
                          <ExternalLink className="w-4 h-4" />
                        </Link>
                        <button
                          onClick={() => openEditModal(m)}
                          title="Edit machine configuration"
                          className="p-1.5 rounded-lg text-slate-400 hover:text-brand-400 hover:bg-white/10 transition-colors"
                        >
                          <Edit className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => handleDelete(m.id, m.name)}
                          title="Decommission equipment"
                          className="p-1.5 rounded-lg text-slate-400 hover:text-red-400 hover:bg-red-500/10 transition-colors"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Create / Edit Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-in fade-in">
          <div className="bg-slate-900 border border-white/10 rounded-2xl w-full max-w-lg p-6 shadow-2xl relative overflow-hidden">
            <div className="flex items-center justify-between pb-4 border-b border-white/10">
              <h3 className="text-lg font-bold text-white flex items-center gap-2">
                <Cpu className="w-5 h-5 text-brand-400" />
                {editingMachine ? 'Edit Machine Specifications' : 'Register New Machine'}
              </h3>
              <button 
                onClick={() => setIsModalOpen(false)}
                className="text-slate-400 hover:text-white p-1 rounded-lg hover:bg-white/5"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4 pt-4">
              <div>
                <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">Machine Name *</label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="e.g. CNC Milling Machine 01"
                  className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">Operational Status</label>
                  <select
                    value={formData.status}
                    onChange={(e) => setFormData({ ...formData, status: parseInt(e.target.value, 10) })}
                    className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none"
                  >
                    <option value={0}>Operational</option>
                    <option value={1}>Under Maintenance</option>
                    <option value={2}>Offline</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">Location / Sector</label>
                  <input
                    type="text"
                    value={formData.location}
                    onChange={(e) => setFormData({ ...formData, location: e.target.value })}
                    placeholder="e.g. Floor A - Sector 1"
                    className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">Current Uptime (Hours)</label>
                  <input
                    type="number"
                    min="0"
                    step="0.5"
                    value={formData.uptimeHours}
                    onChange={(e) => setFormData({ ...formData, uptimeHours: e.target.value })}
                    className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none font-mono"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">Maintenance Interval (Hours) *</label>
                  <input
                    type="number"
                    min="1"
                    step="1"
                    required
                    value={formData.maintenanceIntervalHours}
                    onChange={(e) => setFormData({ ...formData, maintenanceIntervalHours: e.target.value })}
                    className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none font-mono"
                  />
                </div>
              </div>

              <div className="flex items-center justify-end gap-3 pt-4 border-t border-white/10">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2.5 rounded-xl text-sm font-semibold text-slate-300 hover:text-white hover:bg-white/5 border border-white/10 transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-5 py-2.5 rounded-xl text-sm font-semibold text-white bg-gradient-to-r from-brand-600 to-cyan-600 hover:from-brand-500 hover:to-cyan-500 transition-all shadow-md shadow-brand-500/20 disabled:opacity-50"
                >
                  {submitting ? 'Saving...' : editingMachine ? 'Update Machine' : 'Create Machine'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </AdminLayout>
  );
}

