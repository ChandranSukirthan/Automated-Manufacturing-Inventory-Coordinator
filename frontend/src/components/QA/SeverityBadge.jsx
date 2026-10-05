import React from 'react';
import { AlertTriangle, AlertCircle, ShieldAlert, CheckCircle2 } from 'lucide-react';

const severityStyles = {
  low: 'bg-slate-800/80 text-slate-300 border-slate-700/80',
  medium: 'bg-amber-500/10 text-amber-300 border-amber-500/30',
  high: 'bg-orange-500/15 text-orange-300 border-orange-500/35 shadow-sm shadow-orange-500/10',
  critical: 'bg-rose-500/15 text-rose-300 border-rose-500/40 shadow-sm shadow-rose-500/15 font-bold animate-pulse'
};

const severityIcons = {
  low: CheckCircle2,
  medium: AlertCircle,
  high: AlertTriangle,
  critical: ShieldAlert
};

export default function SeverityBadge({ severity, className = '' }) {
  if (!severity) return <span className="text-slate-500 text-xs">—</span>;
  const key = String(severity).toLowerCase().trim();
  const style = severityStyles[key] || 'bg-slate-800 text-slate-300 border-slate-700';
  const Icon = severityIcons[key] || AlertCircle;
  const label = key.toUpperCase();

  return (
    <span
      className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold border tracking-wider uppercase ${style} ${className}`}
    >
      <Icon className="w-3.5 h-3.5 shrink-0" />
      <span>{label}</span>
    </span>
  );
}

