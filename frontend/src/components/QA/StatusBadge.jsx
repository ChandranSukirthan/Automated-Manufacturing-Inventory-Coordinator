import React from 'react';

const statusStyles = {
  open: 'bg-violet-500/15 text-violet-300 border-violet-500/35',
  inreview: 'bg-amber-500/15 text-amber-300 border-amber-500/35',
  resolved: 'bg-emerald-500/15 text-emerald-300 border-emerald-500/35',
  closed: 'bg-slate-800/80 text-slate-400 border-slate-700/80',
  active: 'bg-rose-500/15 text-rose-300 border-rose-500/35 font-semibold',
  released: 'bg-emerald-500/15 text-emerald-300 border-emerald-500/35 font-semibold',
  clear: 'bg-emerald-500/15 text-emerald-300 border-emerald-500/35',
  quarantinerequired: 'bg-rose-500/15 text-rose-300 border-rose-500/40 font-bold',
  quarantineactive: 'bg-rose-500/15 text-rose-300 border-rose-500/40 font-bold'
};

const statusLabels = {
  open: 'Open',
  inreview: 'In Review',
  resolved: 'Resolved',
  closed: 'Closed',
  active: 'Active Hold',
  released: 'Released',
  clear: 'Clear',
  quarantinerequired: 'Quarantine Required',
  quarantineactive: 'Quarantine Active'
};

const statusDots = {
  open: 'bg-violet-400',
  inreview: 'bg-amber-400 animate-pulse',
  resolved: 'bg-emerald-400',
  closed: 'bg-slate-500',
  active: 'bg-rose-400 animate-pulse',
  released: 'bg-emerald-400',
  clear: 'bg-emerald-400',
  quarantinerequired: 'bg-rose-400 animate-pulse',
  quarantineactive: 'bg-rose-400 animate-pulse'
};

export default function StatusBadge({ status, className = '' }) {
  if (!status) return null;
  const key = String(status).toLowerCase().replace(/[\s_-]+/g, '');
  const style = statusStyles[key] || 'bg-slate-800 text-slate-300 border-slate-700';
  const label = statusLabels[key] || status;
  const dotColor = statusDots[key] || 'bg-slate-400';

  return (
    <span
      className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold border tracking-wider uppercase ${style} ${className}`}
    >
      <span className={`w-1.5 h-1.5 rounded-full ${dotColor}`} />
      <span>{label}</span>
    </span>
  );
}

