import React from 'react';
import { MemoryRouter } from 'react-router-dom';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import ReplenishmentRequestPage from './ReplenishmentRequestPage';
import inventoryService from '../../services/inventoryService';

vi.mock('../../services/inventoryService', () => ({
  default: {
    getStockLevels: vi.fn(),
    getAlerts: vi.fn(),
    createAlert: vi.fn(),
    triggerWorkflow: vi.fn(),
  },
}));

const criticalMaterial = {
  skuCode: 'RM-STEEL-001',
  materialName: 'Cold Rolled Steel',
  status: 'CRITICAL',
  currentStock: 25,
  minimumStock: 100,
  daysRemaining: 2,
};

const renderPage = () => render(
  <MemoryRouter>
    <ReplenishmentRequestPage />
  </MemoryRouter>,
);

describe('ReplenishmentRequestPage', () => {
  afterEach(cleanup);

  beforeEach(() => {
    vi.clearAllMocks();
    inventoryService.getStockLevels.mockResolvedValue([criticalMaterial]);
    inventoryService.getAlerts.mockResolvedValue([]);
  });

  it('submits a validated replenishment alert and starts the shared API workflow', async () => {
    inventoryService.createAlert.mockResolvedValue({ sku: 'RM-STEEL-001', quantityRequested: 1500 });
    inventoryService.triggerWorkflow.mockResolvedValue({ workflowId: 'WF-123', status: 'WaitingForApproval', approvalStatus: 'Pending' });
    renderPage();

    expect(await screen.findByRole('option', { name: /RM-STEEL-001/i })).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText(/Requested quantity/i), { target: { value: '1500' } });
    fireEvent.click(screen.getByRole('button', { name: /Submit and start AI workflow/i }));

    await waitFor(() => expect(inventoryService.createAlert).toHaveBeenCalledWith({
      sku: 'RM-STEEL-001',
      packagingType: 'Standard Roll',
      quantityRequested: 1500,
    }));
    expect(inventoryService.triggerWorkflow).toHaveBeenCalledWith(
      'Floor Worker Stock Replenishment: Reorder 1500 units of RM-STEEL-001',
      'RM-STEEL-001',
      1500,
    );
    expect(await screen.findByText(/Replenishment request saved/i)).toBeInTheDocument();
    expect(screen.getByText(/WF-123/i)).toBeInTheDocument();
  });

  it('blocks a zero quantity before calling the API', async () => {
    renderPage();
    await screen.findByRole('option', { name: /RM-STEEL-001/i });
    fireEvent.change(screen.getByLabelText(/Requested quantity/i), { target: { value: '0' } });
    fireEvent.click(screen.getByRole('button', { name: /Submit and start AI workflow/i }));

    expect(await screen.findByText(/Requested quantity must be greater than zero/i)).toBeInTheDocument();
    expect(inventoryService.createAlert).not.toHaveBeenCalled();
    expect(inventoryService.triggerWorkflow).not.toHaveBeenCalled();
  });

  it('shows a retryable error when the API data cannot be loaded', async () => {
    inventoryService.getStockLevels.mockRejectedValueOnce(new Error('API unavailable'));
    renderPage();

    expect(await screen.findByRole('alert')).toHaveTextContent(/Unable to load stock levels/i);
    fireEvent.click(screen.getByRole('button', { name: /Try again/i }));

    await waitFor(() => expect(inventoryService.getStockLevels).toHaveBeenCalledTimes(2));
    expect(await screen.findByRole('option', { name: /RM-STEEL-001/i })).toBeInTheDocument();
  });
});
