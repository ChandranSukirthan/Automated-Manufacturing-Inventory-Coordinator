import React from 'react';

export default function PageHeader({
  category = 'Quality Assurance',
  title,
  subtitle,
  actions
}) {
  return (
    <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between border-b border-slate-800 pb-6 mb-6">
      <div>
        <div className="flex items-center gap-2">
          <span className="text-purple-400 uppercase tracking-widest text-xs font-bold">
            {category}
          </span>
          <span className="text-slate-600">•</span>
          <span className="text-slate-400 text-xs font-medium">Control Center</span>
        </div>
        <h1 className="text-3xl font-extrabold text-white tracking-tight mt-1">
          {title}
        </h1>
        {subtitle && (
          <p className="text-sm text-slate-400 mt-1">
            {subtitle}
          </p>
        )}
      </div>

      {actions && (
        <div className="flex flex-wrap items-center gap-3">
          {actions}
        </div>
      )}
    </div>
  );
}

