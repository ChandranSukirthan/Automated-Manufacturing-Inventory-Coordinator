import { useState, useEffect } from 'react';
import { 
  Clock, 
  Plus, 
  SlidersHorizontal, 
  AlertTriangle, 
  CheckCircle2, 
  Edit, 
  Loader2,
  X
} from 'lucide-react';
import AdminLayout from '../../components/Layout/AdminLayout';
import shiftService from '../../services/shiftService';

export default function ShiftPage() {
  const [shifts, setShifts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [adjustingId, setAdjustingId] = useState(null);
  const [adjustmentMessage, setAdjustmentMessage] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Modal State
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingShift, setEditingShift] = useState(null);
  const [submitting, setSubmitting] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    productionTarget: 10000,
    availableMaterial: 6000,
    actualOutput: 0,
    status: 0,
    startTime: '',
    endTime: ''
  });

  const fetchShifts = async () => {
    setLoading(true);
    try {
      const data = await shiftService.getAll();
      setShifts(data);
    } catch (err) {
      console.error(err);
      setError('Failed to load production shifts.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const timer = setTimeout(() => {
      void fetchShifts();
    }, 0);
    return () => clearTimeout(timer);
  }, []);

  const openCreateModal = () => {
    setEditingShift(null);
    const now = new Date();
    const end = new Date(now.getTime() + 8 * 60 * 60 * 1000);

    setFormData({
      name: '',
      productionTarget: 10000,
      availableMaterial: 6000,
      actualOutput: 0,
      status: 0,
      startTime: now.toISOString().slice(0, 16),
      endTime: end.toISOString().slice(0, 16)
    });
    setIsModalOpen(true);
  };

  const parseShiftStatus = (s) => {
    if (s === 'Planned' || s === 0) return 0;
    if (s === 'InProgress' || s === 1) return 1;
    if (s === 'Completed' || s === 2) return 2;
    return 0;
  };

  const openEditModal = (shift) => {
    setEditingShift(shift);
    setFormData({
      name: shift.name,
      productionTarget: shift.productionTarget,
      availableMaterial: shift.availableMaterial,
      actualOutput: shift.actualOutput,
      status: parseShiftStatus(shift.status),
      startTime: new Date(shift.startTime).toISOString().slice(0, 16),
      endTime: new Date(shift.endTime).toISOString().slice(0, 16)
    });
    setIsModalOpen(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    setError('');
    setSuccess('');

    try {
      const payload = {
        name: formData.name,
        productionTarget: parseInt(formData.productionTarget, 10),
        availableMaterial: parseInt(formData.availableMaterial, 10),
        actualOutput: parseInt(formData.actualOutput, 10),
        status: parseInt(formData.status, 10),
        startTime: new Date(formData.startTime).toISOString(),
        endTime: new Date(formData.endTime).toISOString()
      };

      if (editingShift) {
        await shiftService.update(editingShift.id, payload);
        setSuccess('Shift updated successfully.');
      } else {
        await shiftService.create(payload);
        setSuccess('Shift created successfully.');
      }

      setIsModalOpen(false);
      fetchShifts();
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to save shift.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleAdjustOutput = async (id, name) => {
    setAdjustingId(id);
    setAdjustmentMessage('');
    setError('');
    setSuccess('');

    try {
      const result = await shiftService.adjustOutput(id);
      setAdjustmentMessage(`Rule Enforced for ${name}: ${result.message}`);
      setSuccess(`Adjusted output updated to ${result.adjustedOutput.toLocaleString()} units.`);
      fetchShifts();
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to execute production adjustment rule.');
    } finally {
      setAdjustingId(null);
    }
  };

  const getStatusBadge = (status) => {
    switch (status) {
      case 0:
      case 'Planned':
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-blue-500/10 text-blue-400 border border-blue-500/20">Planned</span>;
      case 1:
      case 'InProgress':
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 animate-pulse">In Progress</span>;
      case 2:
      case 'Completed':
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-800 text-slate-300 border border-white/10">Completed</span>;
      default:
        return <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-800 text-slate-400">{status || 'Scheduled'}</span>;
    }
  };

  return (
    <AdminLayout 
      title="Work Shifts & Capacity Scheduling" 
      subtitle="Shift scheduling and material-constrained production adjustments"
    >
      {/* Header Actions */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-white tracking-tight">Shift Operations & Constraints</h2>
          <p className="text-sm text-slate-400">Backend strictly caps adjusted output to available raw inventory</p>
        </div>

        <button
          onClick={openCreateModal}
          className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-brand-600 to-cyan-600 hover:from-brand-500 hover:to-cyan-500 text-white font-semibold rounded-xl text-sm transition-all shadow-lg shadow-brand-500/20 shrink-0"
        >
          <Plus className="w-4 h-4" />
          <span>Schedule New Shift</span>
        </button>
      </div>

      {/* Adjustment Rule Banner */}
      {adjustmentMessage && (
        <div className="p-4 rounded-2xl bg-brand-500/10 border border-brand-500/30 text-white backdrop-blur-xl flex items-center justify-between gap-4 animate-in fade-in">
          <div className="flex items-center gap-3">
            <SlidersHorizontal className="w-5 h-5 text-brand-400 shrink-0" />
            <span className="text-sm font-medium">{adjustmentMessage}</span>
          </div>
          <button 
            onClick={() => setAdjustmentMessage('')}
            className="text-slate-400 hover:text-white text-xs underline"
          >
            Dismiss
          </button>
        </div>
      )}

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

      {/* Shifts Table */}
      <div className="bg-slate-900/60 border border-white/10 rounded-2xl overflow-hidden backdrop-blur-xl shadow-xl">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b border-white/10 bg-white/5 text-xs uppercase tracking-wider text-slate-400">
                <th className="py-3.5 px-4 font-semibold">Shift Name</th>
                <th className="py-3.5 px-4 font-semibold">Status</th>
                <th className="py-3.5 px-4 font-semibold">Production Target</th>
                <th className="py-3.5 px-4 font-semibold">Available Material</th>
                <th className="py-3.5 px-4 font-semibold">Adjusted Output</th>
                <th className="py-3.5 px-4 font-semibold">Actual Output</th>
                <th className="py-3.5 px-4 font-semibold text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5 text-sm">
              {loading ? (
                <tr>
                  <td colSpan={7} className="py-12 text-center text-slate-400">
                    <Loader2 className="w-6 h-6 animate-spin mx-auto text-brand-400 mb-2" />
                    Loading production shifts...
                  </td>
                </tr>
              ) : shifts.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-12 text-center text-slate-400">
                    No shifts planned. Click "Schedule New Shift" to create one.
                  </td>
                </tr>
              ) : (
                shifts.map((shift) => {
                  const isCapped = shift.availableMaterial < shift.productionTarget;
                  return (
                    <tr key={shift.id} className="hover:bg-white/[0.02] transition-colors">
                      <td className="py-3.5 px-4 font-semibold text-white">
                        <div className="flex items-center gap-2">
                          <Clock className="w-4 h-4 text-brand-400 shrink-0" />
                          <span>{shift.name}</span>
                        </div>
                        <span className="block text-xs text-slate-400 font-normal mt-0.5">
                          {new Date(shift.startTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })} - {new Date(shift.endTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                        </span>
                      </td>
                      <td className="py-3.5 px-4">{getStatusBadge(shift.status)}</td>
                      <td className="py-3.5 px-4 font-mono font-medium text-slate-200">
                        {shift.productionTarget.toLocaleString()} <span className="text-xs text-slate-500">units</span>
                      </td>
                      <td className="py-3.5 px-4 font-mono font-medium">
                        <span className={isCapped ? 'text-amber-400 font-bold' : 'text-slate-200'}>
                          {shift.availableMaterial.toLocaleString()}
                        </span>
                        <span className="text-xs text-slate-500 ml-1">units</span>
                      </td>
                      <td className="py-3.5 px-4 font-mono font-bold">
                        <div className="flex items-center gap-2">
                          <span className="text-emerald-400">{shift.adjustedOutput.toLocaleString()}</span>
                          {isCapped && (
                            <span 
                              title="Material shortage: Capped at available material"
                              className="px-1.5 py-0.5 text-[10px] rounded bg-amber-500/10 text-amber-400 border border-amber-500/20"
                            >
                              CAPPED
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="py-3.5 px-4 font-mono text-slate-200">
                        {shift.actualOutput.toLocaleString()} <span className="text-xs text-slate-500">units</span>
                      </td>
                      <td className="py-3.5 px-4 text-right">
                        <div className="flex items-center justify-end gap-2">
                          <button
                            onClick={() => handleAdjustOutput(shift.id, shift.name)}
                            disabled={adjustingId === shift.id}
                            title="Re-calculate & enforce output adjustment rule"
                            className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 text-xs font-semibold border border-emerald-500/20 transition-colors disabled:opacity-50"
                          >
                            <SlidersHorizontal className={`w-3.5 h-3.5 ${adjustingId === shift.id ? 'animate-spin' : ''}`} />
                            <span>Adjust Output</span>
                          </button>

                          <button
                            onClick={() => openEditModal(shift)}
                            title="Edit shift targets"
                            className="p-1.5 rounded-lg text-slate-400 hover:text-brand-400 hover:bg-white/10 transition-colors"
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Create / Edit Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-in fade-in">
          <div className="bg-slate-900 border border-white/10 rounded-2xl w-full max-w-lg p-6 shadow-2xl">
            <div className="flex items-center justify-between pb-4 border-b border-white/10">
              <h3 className="text-lg font-bold text-white flex items-center gap-2">
                <Clock className="w-5 h-5 text-brand-400" />
                {editingShift ? 'Edit Shift Quota' : 'Schedule Production Shift'}
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
                <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">Shift Name *</label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="e.g. Shift Morning A"
                  className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">Production Target *</label>
                  <input
                    type="number"
                    min="1"
                    required
                    value={formData.productionTarget}
                    onChange={(e) => setFormData({ ...formData, productionTarget: e.target.value })}
                    className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none font-mono"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">Available Material *</label>
                  <input
                    type="number"
                    min="0"
                    required
                    value={formData.availableMaterial}
                    onChange={(e) => setFormData({ ...formData, availableMaterial: e.target.value })}
                    className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none font-mono"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">Actual Output</label>
                  <input
                    type="number"
                    min="0"
                    value={formData.actualOutput}
                    onChange={(e) => setFormData({ ...formData, actualOutput: e.target.value })}
                    className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none font-mono"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">Shift Status</label>
                  <select
                    value={formData.status}
                    onChange={(e) => setFormData({ ...formData, status: parseInt(e.target.value, 10) })}
                    className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none"
                  >
                    <option value={0}>Planned</option>
                    <option value={1}>In Progress</option>
                    <option value={2}>Completed</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">Start Time *</label>
                  <input
                    type="datetime-local"
                    required
                    value={formData.startTime}
                    onChange={(e) => setFormData({ ...formData, startTime: e.target.value })}
                    className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1">End Time *</label>
                  <input
                    type="datetime-local"
                    required
                    value={formData.endTime}
                    onChange={(e) => setFormData({ ...formData, endTime: e.target.value })}
                    className="w-full px-3.5 py-2.5 bg-slate-950/60 border border-white/10 rounded-xl text-white text-sm focus:ring-2 focus:ring-brand-500 focus:outline-none"
                  />
                </div>
              </div>

              <div className="p-3 bg-white/5 rounded-xl border border-white/5 text-xs text-slate-400">
                <span className="font-semibold text-white block mb-0.5">Automated Production Adjustment Rule:</span>
                If Available Material &lt; Target, the backend will automatically constrain Adjusted Output to the available material.
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
                  {submitting ? 'Saving...' : editingShift ? 'Update Shift' : 'Create Shift'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </AdminLayout>
  );
}

