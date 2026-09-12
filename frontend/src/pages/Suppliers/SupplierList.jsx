import React, { useState, useEffect, useMemo } from 'react';
import { Link } from 'react-router-dom';
import {
  Building2,
  Plus,
  Search,
  Filter,
  Mail,
  Phone,
  MapPin,
  CheckCircle2,
  XCircle,
  MoreVertical,
  Edit2,
  Trash2,
  ExternalLink,
  Loader2,
  AlertCircle,
  ArrowUpDown
} from 'lucide-react';
import AppLayout from '../../components/Layout/AppLayout';
import ConfirmModal from '../../components/Common/ConfirmModal';
import supplierService from '../../services/supplierService';
import { parseErrorMessage } from '../../utils/errorHandler';

export default function SupplierList() {
  const [suppliers, setSuppliers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Search, Filter, Sort & Pagination
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('all'); // 'all' | 'active' | 'inactive'
  const [sortBy, setSortBy] = useState('name'); // 'name' | 'date'
  const [sortOrder, setSortOrder] = useState('asc'); // 'asc' | 'desc'
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 8;

  // Modal states
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const [selectedSupplier, setSelectedSupplier] = useState(null);
  const [deleteModalOpen, setDeleteModalOpen] = useState(false);
  const [supplierToDelete, setSupplierToDelete] = useState(null);
  const [actionLoading, setActionLoading] = useState(false);

  // Form state
  const [formData, setFormData] = useState({
    name: '',
    contactEmail: '',
    contactPhone: '',
    address: '',
    isActive: true
  });
  const [formError, setFormError] = useState('');

  const fetchSuppliers = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await supplierService.getSuppliers();
      setSuppliers(data);
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to load suppliers.'));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchSuppliers();
  }, []);

  // Filtered & Sorted Suppliers
  const filteredSuppliers = useMemo(() => {
    return suppliers
      .filter((s) => {
        const matchesSearch =
          s.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
          s.contactEmail.toLowerCase().includes(searchTerm.toLowerCase()) ||
          (s.contactPhone && s.contactPhone.toLowerCase().includes(searchTerm.toLowerCase())) ||
          (s.address && s.address.toLowerCase().includes(searchTerm.toLowerCase()));

        if (!matchesSearch) return false;

        if (statusFilter === 'active') return s.isActive;
        if (statusFilter === 'inactive') return !s.isActive;
        return true;
      })
      .sort((a, b) => {
        if (sortBy === 'name') {
          return sortOrder === 'asc'
            ? a.name.localeCompare(b.name)
            : b.name.localeCompare(a.name);
        }
        if (sortBy === 'date') {
          const dateA = new Date(a.createdAt || 0);
          const dateB = new Date(b.createdAt || 0);
          return sortOrder === 'asc' ? dateA - dateB : dateB - dateA;
        }
        return 0;
      });
  }, [suppliers, searchTerm, statusFilter, sortBy, sortOrder]);

  // Pagination calculation
  const totalPages = Math.ceil(filteredSuppliers.length / itemsPerPage) || 1;
  const paginatedSuppliers = useMemo(() => {
    const start = (currentPage - 1) * itemsPerPage;
    return filteredSuppliers.slice(start, start + itemsPerPage);
  }, [filteredSuppliers, currentPage]);

  // Open Create Modal
  const handleOpenCreate = () => {
    setFormData({
      name: '',
      contactEmail: '',
      contactPhone: '',
      address: '',
      isActive: true
    });
    setFormError('');
    setIsCreateModalOpen(true);
  };

  // Open Edit Modal
  const handleOpenEdit = (supplier, e) => {
    e.stopPropagation();
    setSelectedSupplier(supplier);
    setFormData({
      name: supplier.name,
      contactEmail: supplier.contactEmail,
      contactPhone: supplier.contactPhone || '',
      address: supplier.address || '',
      isActive: supplier.isActive
    });
    setFormError('');
    setIsEditModalOpen(true);
  };

  // Submit Create Supplier
  const handleCreateSubmit = async (e) => {
    e.preventDefault();
    if (!formData.name.trim() || !formData.contactEmail.trim()) {
      setFormError('Supplier name and email are required.');
      return;
    }
    setActionLoading(true);
    setFormError('');
    try {
      await supplierService.createSupplier(formData);
      setIsCreateModalOpen(false);
      await fetchSuppliers();
    } catch (err) {
      setFormError(parseErrorMessage(err, 'Failed to create supplier.'));
    } finally {
      setActionLoading(false);
    }
  };

  // Submit Edit Supplier
  const handleEditSubmit = async (e) => {
    e.preventDefault();
    if (!formData.name.trim() || !formData.contactEmail.trim()) {
      setFormError('Supplier name and email are required.');
      return;
    }
    setActionLoading(true);
    setFormError('');
    try {
      await supplierService.updateSupplier(selectedSupplier.id, formData);
      setIsEditModalOpen(false);
      await fetchSuppliers();
    } catch (err) {
      setFormError(parseErrorMessage(err, 'Failed to update supplier.'));
    } finally {
      setActionLoading(false);
    }
  };

  // Soft Delete Supplier
  const handleDeleteConfirm = async () => {
    if (!supplierToDelete) return;
    setActionLoading(true);
    try {
      await supplierService.deleteSupplier(supplierToDelete.id);
      setDeleteModalOpen(false);
      setSupplierToDelete(null);
      await fetchSuppliers();
    } catch (err) {
      setError(parseErrorMessage(err, 'Failed to deactivate supplier.'));
    } finally {
      setActionLoading(false);
    }
  };

  // Metrics
  const totalCount = suppliers.length;
  const activeCount = suppliers.filter((s) => s.isActive).length;
  const inactiveCount = totalCount - activeCount;

  return (
    <AppLayout
      title="Suppliers Directory"
      subtitle="Manage raw material vendors, contract details, and supplier performance"
      actionButton={
        <button
          onClick={handleOpenCreate}
          className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-brand-600 to-brand-700 hover:from-brand-500 hover:to-brand-600 text-white font-semibold rounded-xl text-sm transition-all shadow-lg shadow-brand-600/20"
        >
          <Plus className="w-4 h-4" />
          <span>Add Supplier</span>
        </button>
      }
    >
      {/* Top Metrics Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Total Vendors</p>
            <Building2 className="w-5 h-5 text-brand-400" />
          </div>
          <p className="text-2xl font-bold text-white mt-2">{totalCount}</p>
        </div>
        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Active Partners</p>
            <CheckCircle2 className="w-5 h-5 text-emerald-400" />
          </div>
          <p className="text-2xl font-bold text-emerald-400 mt-2">{activeCount}</p>
        </div>
        <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 backdrop-blur-sm">
          <div className="flex items-center justify-between">
            <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Inactive Vendors</p>
            <XCircle className="w-5 h-5 text-slate-500" />
          </div>
          <p className="text-2xl font-bold text-slate-400 mt-2">{inactiveCount}</p>
        </div>
      </div>

      {/* Search, Filter and Controls */}
      <div className="flex flex-col md:flex-row gap-3 items-center justify-between bg-slate-900/40 p-4 rounded-2xl border border-slate-800/80">
        <div className="relative w-full md:w-80">
          <Search className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-500" />
          <input
            type="text"
            placeholder="Search suppliers by name, email..."
            value={searchTerm}
            onChange={(e) => {
              setSearchTerm(e.target.value);
              setCurrentPage(1);
            }}
            className="w-full pl-9 pr-4 py-2 bg-slate-950/80 border border-slate-800 rounded-xl text-sm text-white placeholder-slate-500 focus:outline-hidden focus:ring-2 focus:ring-brand-500"
          />
        </div>

        <div className="flex flex-wrap items-center gap-2 w-full md:w-auto">
          {/* Status Filter */}
          <div className="flex items-center bg-slate-950 p-1 rounded-xl border border-slate-800 text-xs">
            <button
              onClick={() => {
                setStatusFilter('all');
                setCurrentPage(1);
              }}
              className={`px-3 py-1.5 rounded-lg font-medium transition-all ${
                statusFilter === 'all' ? 'bg-brand-600 text-white' : 'text-slate-400 hover:text-white'
              }`}
            >
              All
            </button>
            <button
              onClick={() => {
                setStatusFilter('active');
                setCurrentPage(1);
              }}
              className={`px-3 py-1.5 rounded-lg font-medium transition-all ${
                statusFilter === 'active' ? 'bg-emerald-600 text-white' : 'text-slate-400 hover:text-white'
              }`}
            >
              Active
            </button>
            <button
              onClick={() => {
                setStatusFilter('inactive');
                setCurrentPage(1);
              }}
              className={`px-3 py-1.5 rounded-lg font-medium transition-all ${
                statusFilter === 'inactive' ? 'bg-slate-700 text-white' : 'text-slate-400 hover:text-white'
              }`}
            >
              Inactive
            </button>
          </div>

          {/* Sort Order */}
          <button
            onClick={() => setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc')}
            className="flex items-center gap-1.5 px-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-slate-300 hover:text-white hover:border-slate-700"
          >
            <ArrowUpDown className="w-3.5 h-3.5 text-slate-400" />
            <span>{sortOrder === 'asc' ? 'Ascending' : 'Descending'}</span>
          </button>
        </div>
      </div>

      {/* Error display */}
      {error && (
        <div className="p-4 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-400 text-sm flex items-center gap-3">
          <AlertCircle className="w-5 h-5 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Suppliers Table */}
      {loading ? (
        <div className="p-16 flex flex-col items-center justify-center gap-3 bg-slate-900/30 rounded-2xl border border-slate-800">
          <Loader2 className="w-8 h-8 text-brand-500 animate-spin" />
          <p className="text-sm text-slate-400">Loading suppliers directory...</p>
        </div>
      ) : filteredSuppliers.length === 0 ? (
        <div className="p-16 text-center bg-slate-900/30 rounded-2xl border border-slate-800 space-y-3">
          <Building2 className="w-12 h-12 text-slate-600 mx-auto" />
          <h3 className="text-base font-semibold text-white">No suppliers found</h3>
          <p className="text-sm text-slate-400 max-w-sm mx-auto">
            Try adjusting your search criteria or register a new supplier to get started.
          </p>
        </div>
      ) : (
        <div className="bg-slate-900/40 border border-slate-800 rounded-2xl overflow-hidden shadow-xl shadow-black/20">
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-slate-800/80 bg-slate-950/60 text-xs font-semibold text-slate-400 uppercase tracking-wider">
                  <th className="py-3.5 px-4">Supplier Name</th>
                  <th className="py-3.5 px-4">Contact Details</th>
                  <th className="py-3.5 px-4">Address</th>
                  <th className="py-3.5 px-4">Status</th>
                  <th className="py-3.5 px-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60 text-sm">
                {paginatedSuppliers.map((supplier) => (
                  <tr
                    key={supplier.id}
                    className="hover:bg-slate-800/40 transition-colors group cursor-pointer"
                  >
                    <td className="py-4 px-4 font-medium text-white">
                      <Link
                        to={`/suppliers/${supplier.id}`}
                        className="flex items-center gap-2 text-brand-400 hover:text-brand-300 group-hover:underline"
                      >
                        <Building2 className="w-4 h-4 text-slate-400" />
                        <span>{supplier.name}</span>
                      </Link>
                    </td>
                    <td className="py-4 px-4 space-y-1">
                      <div className="flex items-center gap-1.5 text-xs text-slate-300">
                        <Mail className="w-3.5 h-3.5 text-slate-500" />
                        <span>{supplier.contactEmail}</span>
                      </div>
                      {supplier.contactPhone && (
                        <div className="flex items-center gap-1.5 text-xs text-slate-400">
                          <Phone className="w-3.5 h-3.5 text-slate-500" />
                          <span>{supplier.contactPhone}</span>
                        </div>
                      )}
                    </td>
                    <td className="py-4 px-4 text-xs text-slate-400 max-w-xs truncate">
                      {supplier.address ? (
                        <div className="flex items-center gap-1.5 truncate">
                          <MapPin className="w-3.5 h-3.5 text-slate-500 shrink-0" />
                          <span className="truncate">{supplier.address}</span>
                        </div>
                      ) : (
                        '—'
                      )}
                    </td>
                    <td className="py-4 px-4">
                      {supplier.isActive ? (
                        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                          <span className="w-1.5 h-1.5 rounded-full bg-emerald-400" />
                          Active
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-800 text-slate-400 border border-slate-700">
                          <span className="w-1.5 h-1.5 rounded-full bg-slate-500" />
                          Inactive
                        </span>
                      )}
                    </td>
                    <td className="py-4 px-4 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        <Link
                          to={`/suppliers/${supplier.id}`}
                          className="p-1.5 text-slate-400 hover:text-white rounded-lg hover:bg-slate-800"
                          title="View Details"
                        >
                          <ExternalLink className="w-4 h-4" />
                        </Link>
                        <button
                          onClick={(e) => handleOpenEdit(supplier, e)}
                          className="p-1.5 text-slate-400 hover:text-brand-400 rounded-lg hover:bg-slate-800"
                          title="Edit Supplier"
                        >
                          <Edit2 className="w-4 h-4" />
                        </button>
                        {supplier.isActive && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              setSupplierToDelete(supplier);
                              setDeleteModalOpen(true);
                            }}
                            className="p-1.5 text-slate-400 hover:text-rose-400 rounded-lg hover:bg-slate-800"
                            title="Deactivate Supplier"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="p-4 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-400">
              <span>
                Showing {(currentPage - 1) * itemsPerPage + 1} to{' '}
                {Math.min(currentPage * itemsPerPage, filteredSuppliers.length)} of{' '}
                {filteredSuppliers.length} suppliers
              </span>
              <div className="flex items-center gap-1.5">
                <button
                  onClick={() => setCurrentPage((p) => Math.max(p - 1, 1))}
                  disabled={currentPage === 1}
                  className="px-3 py-1.5 rounded-lg border border-slate-800 bg-slate-950 text-slate-300 hover:text-white disabled:opacity-40"
                >
                  Previous
                </button>
                <span className="px-2 font-medium text-white">
                  Page {currentPage} of {totalPages}
                </span>
                <button
                  onClick={() => setCurrentPage((p) => Math.min(p + 1, totalPages))}
                  disabled={currentPage === totalPages}
                  className="px-3 py-1.5 rounded-lg border border-slate-800 bg-slate-950 text-slate-300 hover:text-white disabled:opacity-40"
                >
                  Next
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Create / Edit Supplier Modal */}
      {(isCreateModalOpen || isEditModalOpen) && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-xs animate-in fade-in">
          <div className="bg-slate-900 border border-slate-800 w-full max-w-lg rounded-2xl shadow-2xl p-6 space-y-4">
            <h3 className="text-lg font-bold text-white">
              {isCreateModalOpen ? 'Add New Supplier' : `Edit Supplier — ${selectedSupplier?.name}`}
            </h3>

            {formError && (
              <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-xs flex items-center gap-2">
                <AlertCircle className="w-4 h-4 shrink-0" />
                <span>{formError}</span>
              </div>
            )}

            <form
              onSubmit={isCreateModalOpen ? handleCreateSubmit : handleEditSubmit}
              className="space-y-3.5"
            >
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Supplier / Company Name <span className="text-rose-400">*</span>
                </label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="e.g. Apex Industrial Steel Corp"
                  className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white placeholder-slate-500 focus:outline-hidden focus:ring-2 focus:ring-brand-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Contact Email <span className="text-rose-400">*</span>
                </label>
                <input
                  type="email"
                  required
                  value={formData.contactEmail}
                  onChange={(e) => setFormData({ ...formData, contactEmail: e.target.value })}
                  placeholder="sales@supplier.com"
                  className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white placeholder-slate-500 focus:outline-hidden focus:ring-2 focus:ring-brand-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Phone Number
                </label>
                <input
                  type="text"
                  value={formData.contactPhone}
                  onChange={(e) => setFormData({ ...formData, contactPhone: e.target.value })}
                  placeholder="+1 (555) 019-2834"
                  className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white placeholder-slate-500 focus:outline-hidden focus:ring-2 focus:ring-brand-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Physical / Billing Address
                </label>
                <textarea
                  rows={2}
                  value={formData.address}
                  onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                  placeholder="100 Manufacturing Way, Industrial Park, OH"
                  className="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-800 rounded-xl text-sm text-white placeholder-slate-500 focus:outline-hidden focus:ring-2 focus:ring-brand-500"
                />
              </div>

              {isEditModalOpen && (
                <div className="flex items-center gap-2 pt-1">
                  <input
                    type="checkbox"
                    id="isActive"
                    checked={formData.isActive}
                    onChange={(e) => setFormData({ ...formData, isActive: e.target.checked })}
                    className="w-4 h-4 rounded-sm border-slate-700 bg-slate-950 text-brand-600 focus:ring-brand-500"
                  />
                  <label htmlFor="isActive" className="text-xs font-medium text-slate-300">
                    Active Partner (Inactive suppliers cannot receive new Purchase Orders)
                  </label>
                </div>
              )}

              <div className="flex items-center justify-end gap-3 pt-3">
                <button
                  type="button"
                  onClick={() => {
                    setIsCreateModalOpen(false);
                    setIsEditModalOpen(false);
                  }}
                  disabled={actionLoading}
                  className="px-4 py-2 text-sm font-medium text-slate-300 hover:text-white bg-slate-800/60 rounded-xl"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={actionLoading}
                  className="flex items-center gap-2 px-5 py-2 bg-gradient-to-r from-brand-600 to-brand-700 hover:from-brand-500 text-white text-sm font-semibold rounded-xl shadow-lg shadow-brand-600/20 disabled:opacity-50"
                >
                  {actionLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : null}
                  {isCreateModalOpen ? 'Create Supplier' : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete / Deactivate Confirmation Modal */}
      <ConfirmModal
        isOpen={deleteModalOpen}
        onClose={() => setDeleteModalOpen(false)}
        onConfirm={handleDeleteConfirm}
        title="Deactivate Supplier"
        message={`Are you sure you want to deactivate ${supplierToDelete?.name}? Existing purchase orders will be preserved, but new orders cannot be assigned to this vendor.`}
        confirmText="Deactivate"
        variant="danger"
        loading={actionLoading}
      />
    </AppLayout>
  );
}
