import React from 'react';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import inventoryService from '../../services/inventoryService';
import WorkerDashboard from './WorkerDashboard';

vi.mock('../../components/Layout/RoleLayout', () => ({ default: ({ children }) => <div>{children}</div> }));
vi.mock('../../services/inventoryService', () => ({ default: {
  getItems: vi.fn(), getRawMaterials: vi.fn(), getRolls: vi.fn(),
  getAlerts: vi.fn(), getStockLevels: vi.fn(), deleteItem: vi.fn(), updateItem: vi.fn(),
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

  it('renders the operations overview on /dashboard/worker', async () => {
    render(
      <MemoryRouter initialEntries={['/dashboard/worker']}>
        <WorkerDashboard />
      </MemoryRouter>
    );
    expect(await screen.findByText('Operations Dashboard')).toBeInTheDocument();
    expect(screen.getByText('Floor Worker Quick Actions')).toBeInTheDocument();
  });

  it('renders the inventory catalogue workspace on /inventory', async () => {
    render(
      <MemoryRouter initialEntries={['/inventory']}>
        <WorkerDashboard />
      </MemoryRouter>
    );
    expect(await screen.findByText('Inventory Workspace')).toBeInTheDocument();
    expect(screen.getByText('Raw Materials & Items')).toBeInTheDocument();
  });

  it('opens edit modal and updates the item', async () => {
    inventoryService.updateItem.mockResolvedValue({});
    inventoryService.getItems.mockResolvedValueOnce([item]).mockResolvedValue([{ ...item, stockLevel: 25 }]);
    render(<MemoryRouter><WorkerDashboard /></MemoryRouter>);
    const editButton = await screen.findByRole('button', { name: `Edit ${item.sku}` });
    fireEvent.click(editButton);
    expect(await screen.findByText('Edit Catalog Item')).toBeInTheDocument();
    const stockInputs = screen.getAllByRole('spinbutton');
    // First spinbutton is Current Stock (Units), second is Reorder Level (Units)
    fireEvent.change(stockInputs[0], { target: { value: '25' } });
    fireEvent.click(screen.getByRole('button', { name: 'Save Changes' }));
    await waitFor(() => expect(inventoryService.updateItem).toHaveBeenCalledWith(42, expect.objectContaining({
      id: 42,
      stockLevel: 25,
    })));
  });
});
