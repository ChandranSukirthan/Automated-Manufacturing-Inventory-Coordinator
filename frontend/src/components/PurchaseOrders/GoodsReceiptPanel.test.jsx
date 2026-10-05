import { afterEach, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import GoodsReceiptPanel from './GoodsReceiptPanel';
import purchaseOrderService from '../../services/purchaseOrderService';
import inventoryService from '../../services/inventoryService';

vi.mock('../../services/purchaseOrderService', () => ({ default: { getReceipts: vi.fn(), receiveGoods: vi.fn() } }));
vi.mock('../../services/inventoryService', () => ({ default: { getRolls: vi.fn().mockResolvedValue([]) } }));
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
  fireEvent.change(screen.getByLabelText('Supplier batch / lot number'), { target: { value: 'BATCH-1' } });
  fireEvent.click(screen.getByRole('button', { name: 'Record arrival' }));
  await screen.findByRole('alert');
  const first = purchaseOrderService.receiveGoods.mock.calls[0][1];
  fireEvent.click(screen.getByRole('button', { name: 'Record arrival' }));
  await waitFor(() => expect(refreshed).toHaveBeenCalledTimes(1));
  expect(purchaseOrderService.receiveGoods.mock.calls[1][1]).toEqual(first);
  expect(screen.getByRole('option', { name: 'Film · 6 remaining' })).toBeInTheDocument();
  expect(screen.getByLabelText('Supplier batch / lot number')).toHaveValue('BATCH-1');
  expect(screen.getByLabelText('Physical roll identifier').value).toMatch(/^ROLL-/);
  expect(screen.getByLabelText('Physical roll identifier')).not.toHaveValue('ROLL-1');
  expect(screen.getByLabelText('Quantity received')).toHaveValue(null);
});

it('generates editable roll IDs and suggests only batches for the selected material', async () => {
  purchaseOrderService.getReceipts.mockResolvedValue([]);
  inventoryService.getRolls.mockResolvedValue([
    { rawMaterialId: 11, batchId: 'FILM-LOT-1' },
    { rawMaterialId: 11, batchId: 'FILM-LOT-1' },
    { rawMaterialId: 12, batchId: 'PAPER-LOT-1' },
  ]);
  render(<GoodsReceiptPanel po={{ id: 2, status: 'InTransit', orderLines: [
    { id: 1, rawMaterialId: 11, quantity: 10, rawMaterialName: 'Film' },
    { id: 2, rawMaterialId: 12, quantity: 20, rawMaterialName: 'Paper' },
  ] }} onReceived={vi.fn()} />);
  const roll = screen.getByLabelText('Physical roll identifier');
  const firstId = roll.value;
  expect(firstId).toMatch(/^ROLL-/);
  fireEvent.click(screen.getByRole('button', { name: 'Generate another roll ID' }));
  expect(roll.value).not.toBe(firstId);
  fireEvent.change(screen.getByLabelText('Order line'), { target: { value: '1' } });
  await waitFor(() => expect(screen.getByRole('option', { name: 'FILM-LOT-1', hidden: true })).toBeInTheDocument());
  expect(screen.queryByRole('option', { name: 'PAPER-LOT-1', hidden: true })).not.toBeInTheDocument();
  fireEvent.change(screen.getByLabelText('Supplier batch / lot number'), { target: { value: 'NEW-LOT-3' } });
  fireEvent.change(screen.getByLabelText('Order line'), { target: { value: '2' } });
  expect(screen.getByLabelText('Supplier batch / lot number')).toHaveValue('');
  expect(screen.getByRole('option', { name: 'PAPER-LOT-1', hidden: true })).toBeInTheDocument();
});

it('allows a new supplier batch and an automatic roll ID when suggestions are unavailable', async () => {
  purchaseOrderService.getReceipts.mockResolvedValueOnce([]).mockResolvedValueOnce([
    { id: 1, orderLineId: 1, quantity: 10, rollIdentifier: 'GENERATED', batchId: 'NEW-LOT', receivedAt: '2026-10-05T10:00:00Z' },
  ]);
  inventoryService.getRolls.mockRejectedValue(new Error('Offline'));
  purchaseOrderService.receiveGoods.mockResolvedValue({});
  render(<GoodsReceiptPanel po={{ id: 3, status: 'Sent', orderLines: [{ id: 1, rawMaterialId: 11, quantity: 10, rawMaterialName: 'Film' }] }} onReceived={vi.fn()} />);
  await screen.findByText(/Existing batches could not be loaded/);
  fireEvent.change(screen.getByLabelText('Order line'), { target: { value: '1' } });
  fireEvent.change(screen.getByLabelText('Quantity received'), { target: { value: '10' } });
  fireEvent.change(screen.getByLabelText('Supplier batch / lot number'), { target: { value: 'NEW-LOT' } });
  fireEvent.click(screen.getByRole('button', { name: 'Record arrival' }));
  await screen.findByRole('status');
  expect(purchaseOrderService.receiveGoods).toHaveBeenCalledWith(3, expect.objectContaining({ orderLineId: 1, quantity: 10, batchId: 'NEW-LOT', rollIdentifier: expect.stringMatching(/^ROLL-/), receiptKey: expect.any(String) }));
  expect(screen.getByLabelText('Order line')).toHaveValue('');
  expect(screen.getByLabelText('Supplier batch / lot number')).toHaveValue('');
});

it('shows a receipt load failure and does not offer receipt entry before dispatch', async () => {
  purchaseOrderService.getReceipts.mockRejectedValue(new Error('Receipts unavailable'));
  render(<GoodsReceiptPanel po={{ id: 1, status: 'Approved' }} onReceived={vi.fn()} />);
  expect(await screen.findByRole('alert')).toHaveTextContent('Receipts unavailable');
  expect(screen.queryByRole('button', { name: 'Record arrival' })).not.toBeInTheDocument();
});
