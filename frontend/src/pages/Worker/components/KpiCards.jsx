import React from 'react';
import { Package, TrendingDown, QrCode, ShieldAlert } from 'lucide-react';
import { StatSkeleton } from './SkeletonLoader';

const cards = [
  {
    key: 'totalItems',
    label: 'Total Stock SKUs',
    sub: 'Managed inventory items',
    icon: Package,
    accentBorder: 'border-l-blue-500',
    iconBg: 'bg-blue-500/10 border-blue-500/20',
    iconColor: 'text-blue-400',
    valueColor: 'text-white',
    tab: 'inventory',
  },
  {
    key: 'lowStock',
    label: 'Low Stock Items',
    sub: 'Below safety threshold',
    icon: TrendingDown,
    accentBorder: 'border-l-amber-500',
    iconBg: 'bg-amber-500/10 border-amber-500/20',
    iconColor: 'text-amber-400',
    valueColor: 'text-amber-400',
    tab: 'stock-levels',
  },
  {
    key: 'rolls',
    label: 'Inventory Rolls',
    sub: 'Active scanned batches',
    icon: QrCode,
    accentBorder: 'border-l-cyan-500',
    iconBg: 'bg-cyan-500/10 border-cyan-500/20',
    iconColor: 'text-cyan-400',
    valueColor: 'text-cyan-400',
    tab: 'rolls',
  },
  {
    key: 'activeAlerts',
    label: 'Active Alerts',
    sub: null, // dynamic
    icon: ShieldAlert,
    accentBorder: 'border-l-rose-500',
    iconBg: 'bg-rose-500/10 border-rose-500/20',
    iconColor: 'text-rose-400',
    valueColor: 'text-rose-400',
    tab: 'alerts',
  },
];

export default function KpiCards({
  loading,
  totalItems,
  lowStockCount,
  rollsCount,
  activeAlertsCount,
  totalAlertsCount,
  onTabChange,
}) {
  if (loading) {
    return (
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <StatSkeleton key={i} />
        ))}
      </div>
    );
  }

  const values = {
    totalItems,
    lowStock: lowStockCount,
    rolls: rollsCount,
    activeAlerts: activeAlertsCount,
  };

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      {cards.map((card) => {
        const Icon = card.icon;
        const value = values[card.key];
        const showPulse = card.key === 'activeAlerts' && value > 0;

        return (
          <button
            key={card.key}
            onClick={() => onTabChange(card.tab)}
            className={`p-5 rounded-2xl bg-slate-900/60 border border-slate-800 border-l-4 ${card.accentBorder} flex items-center justify-between text-left transition hover:bg-slate-900/80 hover:border-slate-700 group cursor-pointer`}
          >
            <div>
              <p className="text-xs text-slate-400 font-medium">{card.label}</p>
              <h3 className={`text-2xl font-bold mt-1 count-entrance ${card.valueColor}`}>
                {value}
              </h3>
              <p className="text-[11px] text-slate-500 mt-1">
                {card.key === 'activeAlerts'
                  ? `${totalAlertsCount} total logged`
                  : card.sub}
              </p>
            </div>
            <div className={`relative w-12 h-12 rounded-xl ${card.iconBg} border flex items-center justify-center ${card.iconColor} transition group-hover:scale-105`}>
              <Icon className="w-6 h-6" />
              {showPulse && (
                <span className="absolute -top-1 -right-1 w-3 h-3 rounded-full bg-rose-500 pulse-dot" />
              )}
            </div>
          </button>
        );
      })}
    </div>
  );
}

