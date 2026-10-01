import React from 'react';

/* ──────────────────────────────────────────────────────────── */
/*  Skeleton primitives — pure CSS shimmer, zero dependencies  */
/* ──────────────────────────────────────────────────────────── */

function SkeletonBar({ className = '' }) {
  return <div className={`skeleton-shimmer h-4 ${className}`} />;
}

/* Stat card skeleton — matches KpiCards layout */
export function StatSkeleton() {
  return (
    <div className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 flex items-center justify-between animate-pulse">
      <div className="space-y-2 flex-1">
        <SkeletonBar className="h-3 w-24" />
        <SkeletonBar className="h-7 w-16" />
        <SkeletonBar className="h-2.5 w-32" />
      </div>
      <div className="w-12 h-12 rounded-xl skeleton-shimmer" />
    </div>
  );
}

/* Table row skeleton — matches inventory tables */
export function TableRowSkeleton({ cols = 7 }) {
  return (
    <tr>
      {Array.from({ length: cols }).map((_, i) => (
        <td key={i} className="px-6 py-4">
          <SkeletonBar className={`h-4 ${i === 0 ? 'w-20' : i === cols - 1 ? 'w-16' : 'w-28'}`} />
        </td>
      ))}
    </tr>
  );
}

/* Full table skeleton — renders header + N rows */
export function TableSkeleton({ rows = 5, cols = 7 }) {
  return (
    <div className="border border-slate-800 rounded-2xl bg-slate-900/60 overflow-hidden">
      <table className="w-full text-left text-sm">
        <thead className="bg-slate-950/80 border-b border-slate-800">
          <tr>
            {Array.from({ length: cols }).map((_, i) => (
              <th key={i} className="px-6 py-3.5">
                <SkeletonBar className="h-3 w-20" />
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-800/60">
          {Array.from({ length: rows }).map((_, i) => (
            <TableRowSkeleton key={i} cols={cols} />
          ))}
        </tbody>
      </table>
    </div>
  );
}

/* Card grid skeleton — matches alert cards layout */
export function CardSkeleton({ count = 4 }) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} className="p-5 rounded-2xl bg-slate-900/60 border border-slate-800 space-y-3 animate-pulse">
          <div className="flex items-center justify-between">
            <SkeletonBar className="h-4 w-28" />
            <SkeletonBar className="h-5 w-16 rounded-full" />
          </div>
          <SkeletonBar className="h-3 w-48" />
          <div className="flex items-center justify-between pt-2 border-t border-slate-800/80">
            <SkeletonBar className="h-3 w-20" />
            <div className="flex gap-1.5">
              <SkeletonBar className="h-6 w-20 rounded" />
              <SkeletonBar className="h-6 w-16 rounded" />
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

export default { StatSkeleton, TableSkeleton, TableRowSkeleton, CardSkeleton };

