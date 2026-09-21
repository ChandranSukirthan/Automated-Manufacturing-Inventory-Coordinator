import React from 'react';
import { AlertTriangle, AlertCircle, ShieldAlert, CheckCircle2 } from 'lucide-react';

const severityStyles = {
  low: 'bg-purple-500/10 text-purple-300 border-purple-500/30',
  medium: 'bg-amber-500/10 text-amber-300 border-amber-500/30',
  high: 'bg-orange-500/10 text-orange-300 border-orange-500/30',
  critical: 'bg-rose-500/10 text-rose-300 border-rose-500/30 font-bold'
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
      className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold border tracking-wide uppercase ${style} ${className}`}
    >
      <Icon className="w-3.5 h-3.5 shrink-0" />
      <span>{label}</span>
    </span>
  );
}

