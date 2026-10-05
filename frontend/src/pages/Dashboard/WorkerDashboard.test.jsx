import React from 'react';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import inventoryService from '../../services/inventoryService';
import WorkerDashboard from './WorkerDashboard';

vi.mock('../../components/Layout/RoleLayout', () => ({ default: ({ children }) => <div>{children}</div> }));
vi.mock('../../services/inventoryService', () => ({ default: {
  getItems: vi.fn(), getRawMaterials: vi.fn(), getRolls: vi.fn(),
  getAlerts: vi.fn(), getStockLevels: vi.fn(), deleteItem: vi.fn(),
} }));

const item = { id: 42, sku: 'BP-FILM-042', name: 'Film', stockLevel: 0, reorderThreshold: 5 };

describe('Worker inventory deletion', () => {
  beforeEach(() => {
    vi.resetAllMocks();
    vi.spyOn(window, 'confirm').mockReturnValue(true);
    inventoryService.getItems.mockResolvedValue([item]);
    for (const method of ['getRawMaterials', 'getRolls', 'getAlerts', 'getStockLevels']) {
      inventoryService[method].mockResolvedValue([]);
    }
  });
  afterEach(() => { cleanup(); vi.restoreAllMocks(); });

  it('shows the backend conflict reason and retains the item', async () => {
    const reason = 'This SKU has purchase-order history and cannot be deleted.';
    inventoryService.deleteItem.mockRejectedValue({ response: { status: 409, data: reason } });
    render(<MemoryRouter><WorkerDashboard /></MemoryRouter>);
    fireEvent.click(await screen.findByRole('button', { name: `Delete ${item.sku}` }));
    expect(await screen.findByText(reason)).toBeInTheDocument();
    expect(screen.getByText(item.sku)).toBeInTheDocument();
    expect(inventoryService.deleteItem).toHaveBeenCalledWith(42);
  });

  it('refreshes the list after successful deletion', async () => {
    inventoryService.getItems.mockResolvedValueOnce([item]).mockResolvedValue([]);
    inventoryService.deleteItem.mockResolvedValue(undefined);
    render(<MemoryRouter><WorkerDashboard /></MemoryRouter>);
    fireEvent.click(await screen.findByRole('button', { name: `Delete ${item.sku}` }));
    await waitFor(() => expect(screen.queryByText(item.sku)).not.toBeInTheDocument());
    expect(await screen.findByText('Item deleted successfully.')).toBeInTheDocument();
  });

  it('keeps delete clickable and explains why stocked items cannot be deleted', async () => {
    inventoryService.getItems.mockResolvedValue([{ ...item, stockLevel: 10 }]);
    render(<MemoryRouter><WorkerDashboard /></MemoryRouter>);
    const button = await screen.findByRole('button', { name: `Delete ${item.sku}` });
    expect(button).toBeEnabled();
    fireEvent.click(button);
    expect(await screen.findByText(/Cannot delete BP-FILM-042: it has 10 units remaining/)).toBeInTheDocument();
    expect(inventoryService.deleteItem).not.toHaveBeenCalled();
  });
});
