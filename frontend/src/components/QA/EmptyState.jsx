import React from 'react';
import { SearchX, RotateCcw } from 'lucide-react';

export default function EmptyState({
  icon: Icon = SearchX,
  title = 'No records found',
  description = 'No results match your current selection or filter parameters.',
  actionLabel,
  onAction
}) {
  return (
    <div className="flex flex-col items-center justify-center p-12 text-center rounded-2xl border border-slate-800 bg-slate-900/40 my-4">
      <div className="w-12 h-12 rounded-2xl bg-slate-800/80 border border-slate-700 flex items-center justify-center text-slate-400 mb-4 shadow-sm">
        <Icon className="w-6 h-6 text-slate-400" />
      </div>
      <h3 className="text-base font-bold text-white tracking-tight">{title}</h3>
      <p className="text-sm text-slate-400 mt-1 max-w-md">{description}</p>
      {actionLabel && onAction && (
        <button
          onClick={onAction}
          className="mt-5 inline-flex items-center gap-2 px-4 py-2 rounded-xl border border-slate-700 bg-slate-900 text-sm font-medium text-slate-200 hover:bg-slate-800 hover:text-white transition-all shadow-sm"
        >
          <RotateCcw className="w-4 h-4 text-purple-400" />
          <span>{actionLabel}</span>
        </button>
      )}
    </div>
  );
}

