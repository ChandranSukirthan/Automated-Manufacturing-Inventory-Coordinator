import React from 'react';

const statusStyles = {
  open: 'bg-violet-500/10 text-violet-300 border-violet-500/30',
  inreview: 'bg-amber-500/10 text-amber-300 border-amber-500/30',
  resolved: 'bg-purple-500/10 text-purple-300 border-purple-500/30',
  closed: 'bg-slate-800/60 text-slate-400 border-slate-700/60',
  active: 'bg-amber-500/10 text-amber-300 border-amber-500/30',
  released: 'bg-purple-500/10 text-purple-300 border-purple-500/30'
};

const statusLabels = {
  open: 'Open',
  inreview: 'In Review',
  resolved: 'Resolved',
  closed: 'Closed',
  active: 'Active Hold',
  released: 'Released'
};

const statusDots = {
  open: 'bg-violet-400',
  inreview: 'bg-amber-400 animate-pulse',
  resolved: 'bg-purple-400',
  closed: 'bg-slate-500',
  active: 'bg-amber-400 animate-pulse',
  released: 'bg-purple-400'
};

export default function StatusBadge({ status, className = '' }) {
  if (!status) return null;
  const key = String(status).toLowerCase().replace(/\s+/g, '');
  const style = statusStyles[key] || 'bg-slate-800 text-slate-300 border-slate-700';
  const label = statusLabels[key] || status;
  const dotColor = statusDots[key] || 'bg-slate-400';

  return (
    <span
      className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold border tracking-wide uppercase ${style} ${className}`}
    >
      <span className={`w-1.5 h-1.5 rounded-full ${dotColor}`} />
      <span>{label}</span>
    </span>
  );
}

