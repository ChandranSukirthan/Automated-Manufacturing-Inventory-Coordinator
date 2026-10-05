import { expect, it } from 'vitest';
import { formatColomboDate, formatMoney, fromColomboInput, toColomboInput } from './locale';

it('formats LKR amounts consistently and preserves explicit foreign currency', () => {
  expect(formatMoney(1350)).toMatch(/LKR\s+1,350\.00/);
  expect(formatMoney('1,350.00', 'lkr')).toMatch(/LKR\s+1,350\.00/);
  expect(formatMoney(4.5, 'USD')).toMatch(/USD\s+4\.50/);
  expect(formatMoney(Number.NaN)).toBe('Not available');
});

it('round-trips shift form times in Colombo regardless of the browser timezone', () => {
  expect(toColomboInput('2026-10-05T20:00:00Z')).toBe('2026-10-06T01:30');
  expect(fromColomboInput('2026-10-06T01:30')).toBe('2026-10-05T20:00:00.000Z');
  expect(toColomboInput('invalid')).toBe('');
});

it('displays Colombo time and handles the UTC date boundary', () => {
  expect(formatColomboDate('2026-10-05T20:00:00Z', 'toLocaleDateString')).toBe('06/10/2026');
  expect(formatColomboDate('2026-10-05T20:00:00Z', 'toLocaleTimeString')).toBe('01:30:00');
  expect(formatColomboDate('invalid')).toBe('Not available');
});
