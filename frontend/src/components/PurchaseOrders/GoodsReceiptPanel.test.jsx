import { afterEach, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import GoodsReceiptPanel from './GoodsReceiptPanel';
import purchaseOrderService from '../../services/purchaseOrderService';

vi.mock('../../services/purchaseOrderService', () => ({ default: { getReceipts: vi.fn(), receiveGoods: vi.fn() } }));
afterEach(() => { cleanup(); vi.resetAllMocks(); });

it('keeps the same receipt key after a lost response and refreshes a partial delivery', async () => {
  purchaseOrderService.getReceipts.mockResolvedValueOnce([]).mockResolvedValueOnce([
    { id: 'receipt', orderLineId: 1, quantity: 4, rollIdentifier: 'ROLL-1', batchId: 'BATCH-1', receivedAt: '2026-10-03T10:00:00Z' },
  ]);
  purchaseOrderService.receiveGoods.mockRejectedValueOnce(new Error('Connection lost')).mockResolvedValueOnce({ id: 'receipt' });
  const refreshed = vi.fn();
  render(<GoodsReceiptPanel po={{ id: 1, status: 'Sent', orderLines: [{ id: 1, quantity: 10, rawMaterialName: 'Film' }] }} onReceived={refreshed} />);
  await waitFor(() => expect(purchaseOrderService.getReceipts).toHaveBeenCalledTimes(1));
  fireEvent.change(screen.getByLabelText('Order line'), { target: { value: '1' } });
  fireEvent.change(screen.getByLabelText('Quantity received'), { target: { value: '4' } });
  fireEvent.change(screen.getByLabelText('Physical roll identifier'), { target: { value: 'ROLL-1' } });
  fireEvent.change(screen.getByLabelText('Batch identifier'), { target: { value: 'BATCH-1' } });
  fireEvent.click(screen.getByRole('button', { name: 'Record arrival' }));
  await screen.findByRole('alert');
  const first = purchaseOrderService.receiveGoods.mock.calls[0][1];
  fireEvent.click(screen.getByRole('button', { name: 'Record arrival' }));
  await waitFor(() => expect(refreshed).toHaveBeenCalledTimes(1));
  expect(purchaseOrderService.receiveGoods.mock.calls[1][1]).toEqual(first);
  expect(screen.getByRole('option', { name: 'Film · 6 remaining' })).toBeInTheDocument();
});

it('shows a receipt load failure and does not offer receipt entry before dispatch', async () => {
  purchaseOrderService.getReceipts.mockRejectedValue(new Error('Receipts unavailable'));
  render(<GoodsReceiptPanel po={{ id: 1, status: 'Approved' }} onReceived={vi.fn()} />);
  expect(await screen.findByRole('alert')).toHaveTextContent('Receipts unavailable');
  expect(screen.queryByRole('button', { name: 'Record arrival' })).not.toBeInTheDocument();
});
