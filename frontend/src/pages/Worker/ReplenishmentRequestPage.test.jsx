import React from 'react';
import { MemoryRouter } from 'react-router-dom';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import ReplenishmentRequestPage from './ReplenishmentRequestPage';
import inventoryService from '../../services/inventoryService';

vi.mock('../../context/useAuth', () => ({
  useAuth: () => ({ user: { role: 'FloorWorker', fullName: 'Test Worker' }, logout: vi.fn() }),
}));

vi.mock('../../services/inventoryService', () => ({
  default: {
    getStockLevels: vi.fn(),
    getAlerts: vi.fn(),
    createAlert: vi.fn(),
    triggerWorkflow: vi.fn(),
    updateAlertStatus: vi.fn(),
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
    inventoryService.createAlert.mockResolvedValue({ id: 7, sku: 'RM-STEEL-001', quantityRequested: 1500 });
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
      'WF-WORKER-ALERT-7',
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

  it('retries a saved alert after an AI outage without duplicating the request', async () => {
    const alert = { id: 8, sku: criticalMaterial.skuCode, quantityRequested: 1500, status: 'Pending' };
    inventoryService.createAlert.mockResolvedValue(alert);
    inventoryService.getAlerts.mockResolvedValueOnce([]).mockResolvedValue([alert]);
    inventoryService.triggerWorkflow.mockRejectedValueOnce({ response: { status: 503, data: { message: 'AI service unavailable' } } })
      .mockResolvedValueOnce({ workflow_id: 'WF-WORKER-ALERT-8', status: 'Running' });
    renderPage();
    await screen.findByRole('option', { name: /RM-STEEL-001/i });
    fireEvent.change(screen.getByLabelText(/Requested quantity/i), { target: { value: '1500' } });
    fireEvent.click(screen.getByRole('button', { name: /Submit and start AI workflow/i }));
    expect(await screen.findByText(/AI service unavailable/)).toBeInTheDocument();
    fireEvent.click(await screen.findByRole('button', { name: /Start or retry AI for saved request/i }));
    expect(await screen.findByText('WF-WORKER-ALERT-8')).toBeInTheDocument();
    expect(inventoryService.createAlert).toHaveBeenCalledTimes(1);
    expect(inventoryService.triggerWorkflow).toHaveBeenCalledTimes(2);
    expect(inventoryService.triggerWorkflow.mock.calls[0]).toEqual(inventoryService.triggerWorkflow.mock.calls[1]);
  });

  it('uses the existing request quantity instead of creating another alert', async () => {
    inventoryService.getAlerts.mockResolvedValue([{ id: 9, sku: criticalMaterial.skuCode, quantityRequested: 800, status: 'Pending' }]);
    inventoryService.triggerWorkflow.mockResolvedValue({ workflow_id: 'WF-WORKER-ALERT-9', status: 'Running' });
    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: /Start or retry AI for saved request/i }));
    await waitFor(() => expect(inventoryService.triggerWorkflow).toHaveBeenCalledWith(
      expect.any(String), criticalMaterial.skuCode, 800, 'WF-WORKER-ALERT-9'));
    expect(inventoryService.createAlert).not.toHaveBeenCalled();
  });

  it('shows a retryable error when the API data cannot be loaded', async () => {
    inventoryService.getStockLevels.mockRejectedValueOnce(new Error('API unavailable'));
    renderPage();

    expect(await screen.findByRole('alert')).toHaveTextContent(/Unable to load stock levels/i);
    fireEvent.click(screen.getByRole('button', { name: /Try again/i }));

    await waitFor(() => expect(inventoryService.getStockLevels).toHaveBeenCalledTimes(2));
    expect(await screen.findByRole('option', { name: /RM-STEEL-001/i })).toBeInTheDocument();
  });

  it('allows worker to dismiss an active alert to edit the requested quantity', async () => {
    vi.spyOn(window, 'confirm').mockReturnValue(true);
    inventoryService.getAlerts
      .mockResolvedValueOnce([{ id: 9, sku: criticalMaterial.skuCode, quantityRequested: 800, status: 'Pending' }])
      .mockResolvedValueOnce([]);
    inventoryService.updateAlertStatus.mockResolvedValue(true);

    renderPage();
    const dismissBtn = await screen.findByRole('button', { name: /Dismiss \/ Clear to edit/i });
    expect(dismissBtn).toBeInTheDocument();
    fireEvent.click(dismissBtn);

    await waitFor(() => expect(inventoryService.updateAlertStatus).toHaveBeenCalledWith(9, 'Dismissed'));
    expect(await screen.findByRole('button', { name: /Submit and start AI workflow/i })).toBeInTheDocument();
  });
});
