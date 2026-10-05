export const DEFAULT_CURRENCY = 'LKR';
export const APPROVAL_THRESHOLD_LKR = 1_500_000;

export function formatMoney(value, currency = DEFAULT_CURRENCY) {
  const amount = Number(typeof value === 'string' ? value.replace(/,/g, '') : value);
  const code = /^[A-Z]{3}$/.test(String(currency).toUpperCase()) ? String(currency).toUpperCase() : DEFAULT_CURRENCY;
  if (!Number.isFinite(amount)) return 'Not available';
  return new Intl.NumberFormat('en-LK', { style: 'currency', currency: code, currencyDisplay: 'code', minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(amount);
}

export function formatColomboDate(value, method = 'toLocaleString') {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Not available';
  return date[method]('en-GB', { timeZone: 'Asia/Colombo' });
}

export function toColomboInput(value) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '' : new Date(date.getTime() + 330 * 60_000).toISOString().slice(0, 16);
}

export function fromColomboInput(value) {
  return new Date(`${value}+05:30`).toISOString();
}
