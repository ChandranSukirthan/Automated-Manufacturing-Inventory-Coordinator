const roles = ['FloorWorker', 'SupplyChainManager', 'QualityInspector', 'ITAdmin'];
const aliases = {
  worker: 'FloorWorker', manager: 'SupplyChainManager', quality: 'QualityInspector',
  admin: 'ITAdmin', systemadmin: 'ITAdmin', 'system admin': 'ITAdmin',
};

export function normalizeRole(value) {
  if (value && typeof value === 'object') value = value.name ?? value.id;
  const key = String(value ?? '').trim().toLowerCase();
  return roles.find((role, index) => key === String(index) || key === role.toLowerCase())
    || aliases[key] || '';
}

export function roleHome(value) {
  return {
    FloorWorker: '/dashboard/worker', SupplyChainManager: '/dashboard/manager',
    QualityInspector: '/quality', ITAdmin: '/admin',
  }[normalizeRole(value)] || '/login';
}
