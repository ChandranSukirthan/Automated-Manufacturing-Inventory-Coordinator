import React from 'react';
import { Package, AlertTriangle, QrCode, FileText, Bot, Search } from 'lucide-react';

const iconMap = {
  package: Package,
  alert: AlertTriangle,
  qr: QrCode,
  file: FileText,
  bot: Bot,
  search: Search,
};

export default function EmptyState({ icon = 'package', title, description, actionLabel, onAction }) {
  const Icon = typeof icon === 'string' ? (iconMap[icon] || Package) : icon;

  return (
    <div className="flex flex-col items-center justify-center py-16 px-6 text-center">
      <div className="w-16 h-16 rounded-2xl bg-slate-800/80 border border-slate-700/50 flex items-center justify-center mb-5">
        <Icon className="w-7 h-7 text-slate-500" />
      </div>
      <h4 className="text-sm font-semibold text-slate-300 mb-1">{title}</h4>
      <p className="text-xs text-slate-500 max-w-xs">{description}</p>
      {actionLabel && onAction && (
        <button
          onClick={onAction}
          className="mt-4 px-4 py-2 bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-400 border border-cyan-500/30 text-xs font-semibold rounded-xl transition"
        >
          {actionLabel}
        </button>
      )}
    </div>
  );
}

