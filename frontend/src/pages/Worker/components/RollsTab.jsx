import React, { useState } from 'react';
import { QrCode, Search, Trash2, Copy, Check, PlusCircle } from 'lucide-react';
import EmptyState from './EmptyState';

/* ── Status color helper ────────────────────────────────────── */
function statusBadge(status) {
  const s = (status || 'In Stock').toLowerCase();
  if (s === 'depleted') return 'bg-slate-700/50 text-slate-400 border-slate-600';
  if (s === 'quarantined') return 'bg-rose-500/10 text-rose-400 border-rose-500/20';
  return 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20';
}

export default function RollsTab({
  rolls,
  inventoryItems,
  rawMaterials,
  rollIdentifier,
  setRollIdentifier,
  rollQuantity,
  setRollQuantity,
  rollRawMaterialId,
  setRollRawMaterialId,
  registeredRoll,
  onCreateRoll,
  onDeleteRoll,
  qrQuery,
  setQrQuery,
  qrSearchResult,
  qrSearching,
  onQrSearch,
  loading,
}) {
  const [rollSearch, setRollSearch] = useState('');
  const [rollMaterialFilter, setRollMaterialFilter] = useState('');
  const [copied, setCopied] = useState(false);

  const materialBySku = new Map(
    rawMaterials
      .filter((material) => material.skuCode?.trim())
      .map((material) => [material.skuCode.trim().toLowerCase(), material])
  );
  const sourceItems = inventoryItems?.length ? inventoryItems : rawMaterials;
  const uniqueRawMaterials = sourceItems.filter((item, index, materials) => {
    const skuCode = (item.sku || item.skuCode)?.trim().toLowerCase();
    return skuCode && materials.findIndex((candidate) => (candidate.sku || candidate.skuCode)?.trim().toLowerCase() === skuCode) === index;
  }).map((item) => {
    const skuCode = (item.sku || item.skuCode).trim();
    const rawMaterial = materialBySku.get(skuCode.toLowerCase());
    return {
      id: rawMaterial?.id,
      skuCode,
      name: item.name || rawMaterial?.name || 'Raw Material',
    };
  });

  const filteredRolls = rolls.filter(
    (r) =>
      (!rollMaterialFilter || String(r.rawMaterialId) === rollMaterialFilter) &&
      r.rollIdentifier?.toLowerCase().includes(rollSearch.toLowerCase()) ||
      ((!rollMaterialFilter || String(r.rawMaterialId) === rollMaterialFilter) &&
        (r.status || 'In Stock').toLowerCase().includes(rollSearch.toLowerCase()))
  );

  const handleCopy = (text) => {
    navigator.clipboard.writeText(text).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  };

  return (
    <div className="space-y-6 tab-slide-in">
      {/* ── QR Scanner / Lookup ──────────────────────────── */}
      <div className="p-6 rounded-2xl bg-slate-900/80 border border-slate-800 space-y-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-cyan-500/20 to-blue-500/20 border border-cyan-500/30 flex items-center justify-center text-cyan-400">
            <QrCode className="w-5 h-5" />
          </div>
          <div>
            <h3 className="text-base font-bold text-white">QR / Barcode Roll Scanner</h3>
            <p className="text-xs text-slate-400">
              Identify rolls and view real-time batch allocation
            </p>
          </div>
        </div>

        <form onSubmit={onQrSearch} className="flex gap-3">
          <input
            type="text"
            placeholder="Enter QR barcode value (e.g. ROLL-001, ROLL-2026-STEEL-009)..."
            value={qrQuery}
            onChange={(e) => setQrQuery(e.target.value)}
            className="flex-1 bg-slate-950 border border-slate-800 rounded-xl px-4 py-2.5 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500 transition"
          />
          <button
            type="submit"
            disabled={qrSearching}
            className="px-5 py-2.5 bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold text-xs rounded-xl transition disabled:opacity-50"
          >
            {qrSearching ? 'Scanning...' : 'Scan / Lookup'}
          </button>
        </form>

        {/* QR Result Card */}
        {qrSearchResult && (
          <div className="p-4 rounded-xl bg-cyan-950/20 border border-cyan-500/30 mt-3">
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <div>
                <span className="text-[10px] text-slate-400 uppercase font-mono block">
                  Roll Identifier
                </span>
                <div className="flex items-center gap-2 mt-0.5">
                  <p className="font-mono font-bold text-cyan-400 text-sm">
                    {qrSearchResult.rollIdentifier}
                  </p>
                  <button
                    onClick={() => handleCopy(qrSearchResult.rollIdentifier)}
                    className="p-1 rounded text-slate-500 hover:text-cyan-400 transition"
                    title="Copy to clipboard"
                  >
                    {copied ? (
                      <Check className="w-3 h-3 text-emerald-400" />
                    ) : (
                      <Copy className="w-3 h-3" />
                    )}
                  </button>
                </div>
              </div>
              <div>
                <span className="text-[10px] text-slate-400 uppercase font-mono block">Material</span>
                <p className="font-semibold text-white text-sm mt-0.5">
                  {qrSearchResult.materialName} ({qrSearchResult.skuCode})
                </p>
              </div>
              <div>
                <span className="text-[10px] text-slate-400 uppercase font-mono block">
                  Remaining Qty
                </span>
                <p className="font-semibold text-emerald-400 text-sm mt-0.5">
                  {qrSearchResult.remainingQuantity} / {qrSearchResult.initialQuantity} units
                </p>
              </div>
              <div>
                <span className="text-[10px] text-slate-400 uppercase font-mono block">Status</span>
                <p className="font-semibold text-cyan-300 text-sm mt-0.5">
                  {qrSearchResult.status}
                </p>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* ── Roll Management ──────────────────────────────── */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Register Roll Form */}
        <div className="p-6 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-4">
          <div className="flex items-center gap-2">
            <PlusCircle className="w-4 h-4 text-cyan-400" />
            <h3 className="text-base font-bold text-white">Register New Roll</h3>
          </div>

          <form onSubmit={onCreateRoll} className="space-y-4">
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1">
                Roll Identifier
              </label>
              <input
                type="text"
                required
                placeholder="e.g. ROLL-2026-STEEL-009"
                value={rollIdentifier}
                onChange={(e) => setRollIdentifier(e.target.value)}
                className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500 transition"
              />
            </div>
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1">
                Roll Quantity
              </label>
              <input
                type="number"
                required
                min="1"
                step="0.01"
                value={rollQuantity}
                onChange={(e) => setRollQuantity(e.target.value)}
                className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500 transition"
              />
              <p className="mt-1 text-[11px] text-slate-500">Cannot exceed current stock.</p>
            </div>
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1">
                Raw Material
              </label>
              {uniqueRawMaterials.length > 0 ? (
                <select
                  value={rollRawMaterialId}
                  onChange={(e) => setRollRawMaterialId(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white focus:outline-none focus:border-cyan-500 transition"
                >
                  {uniqueRawMaterials.map((m) => (
                    <option key={m.skuCode} value={m.id} disabled={!m.id}>
                      {m.skuCode} — {m.name}
                    </option>
                  ))}
                </select>
              ) : (
                <input
                  type="number"
                  required
                  min={1}
                  value={rollRawMaterialId}
                  onChange={(e) => setRollRawMaterialId(e.target.value)}
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2 text-sm text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500 transition"
                />
              )}
            </div>
            <button
              type="submit"
              className="w-full py-2.5 bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold rounded-xl text-sm transition"
            >
              Register Roll
            </button>
          </form>

          {/* Recently registered */}
          {registeredRoll && (
            <div className="p-3 rounded-xl bg-emerald-950/20 border border-emerald-500/30 glow-pulse">
              <div className="flex items-center gap-1.5 mb-1">
                <span className="text-[10px] font-bold text-emerald-400 uppercase">✓ Registered</span>
              </div>
              <p className="font-mono text-sm text-emerald-300">
                {registeredRoll.rollIdentifier || 'New Roll'}
              </p>
            </div>
          )}
        </div>

        {/* Active Rolls List */}
        <div className="lg:col-span-2 border border-slate-800 rounded-2xl bg-slate-900/60 overflow-hidden flex flex-col">
          <div className="px-6 py-4 border-b border-slate-800 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-2">
            <div>
              <h3 className="text-sm font-bold text-white">Warehouse Inventory Rolls</h3>
              <span className="text-xs text-slate-400">{filteredRolls.length} rolls shown</span>
            </div>
            <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-2 w-full sm:w-auto">
              <select
                value={rollMaterialFilter}
                onChange={(e) => setRollMaterialFilter(e.target.value)}
                className="bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-200 focus:outline-none focus:border-cyan-500"
                aria-label="Filter rolls by raw material"
              >
                <option value="">All Raw Materials</option>
                {uniqueRawMaterials.filter((material) => material.id).map((material) => (
                  <option key={material.id} value={material.id}>
                    {material.skuCode} — {material.name}
                  </option>
                ))}
              </select>
              <div className="flex items-center gap-2 bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5">
                <Search className="w-3.5 h-3.5 text-slate-500" />
                <input
                  type="text"
                  placeholder="Filter rolls..."
                  value={rollSearch}
                  onChange={(e) => setRollSearch(e.target.value)}
                  className="bg-transparent border-none text-xs text-slate-200 placeholder-slate-500 focus:outline-none w-full sm:w-36"
                />
              </div>
            </div>
          </div>

          <div className="divide-y divide-slate-800 max-h-[420px] overflow-y-auto flex-1">
            {filteredRolls.length === 0 ? (
              <EmptyState
                icon="qr"
                title={rollSearch ? 'No rolls match your filter' : 'No rolls registered yet'}
                description={
                  rollSearch
                    ? 'Try adjusting your search query.'
                    : 'Register your first inventory roll using the form on the left.'
                }
              />
            ) : (
              filteredRolls.map((roll) => (
                <div
                  key={roll.id}
                  className="p-4 flex items-center justify-between hover:bg-slate-800/30 transition group"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-lg bg-slate-800 border border-slate-700 flex items-center justify-center">
                      <QrCode className="w-3.5 h-3.5 text-slate-400" />
                    </div>
                    <div>
                      <p className="font-mono font-bold text-cyan-400 text-xs">
                        {roll.rollIdentifier}
                      </p>
                      <p className="text-xs text-slate-400 mt-0.5">
                        Qty: <span className="text-slate-200">{roll.currentQuantity}</span>
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <span
                      className={`text-[10px] px-2 py-0.5 rounded-full font-semibold border ${statusBadge(
                        roll.status
                      )}`}
                    >
                      {roll.status || 'In Stock'}
                    </span>
                    <span className="text-xs text-slate-500 hidden sm:inline">
                      {new Date(roll.createdAt).toLocaleDateString()}
                    </span>
                    <button
                      onClick={() => onDeleteRoll(roll.id)}
                      className="p-1.5 text-slate-500 hover:text-rose-400 opacity-0 group-hover:opacity-100 transition"
                      title="Delete Roll"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

