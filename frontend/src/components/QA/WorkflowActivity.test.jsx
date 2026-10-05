import React from 'react';
import { cleanup, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import WorkflowActivity from './WorkflowActivity';
import dashboardService from '../../services/dashboardService';
import agentWorkflowService from '../../services/agentWorkflowService';

vi.mock('../../services/dashboardService', () => ({ default: { getAiValidationHistory: vi.fn() } }));
vi.mock('../../services/agentWorkflowService', () => ({ default: { getWorkflows: vi.fn() } }));
beforeEach(() => vi.resetAllMocks());
afterEach(cleanup);
const renderPanel = (quality = false) => render(<MemoryRouter><WorkflowActivity quality={quality} /></MemoryRouter>);

it('shows a failed replenishment that has no purchase order', async () => {
  agentWorkflowService.getWorkflows.mockResolvedValue([{ workflowId: 'WF-WORKER', status: 'Failed',
    objective: 'Replenish ink', validationResults: { isValid: false, rejectionReason: 'No eligible supplier quote' },
    details: { material_id: 'BP-INK-001', required_quantity: 2000, unit: 'KG' } }]);
  renderPanel();
  expect(await screen.findByText('WF-WORKER')).toBeInTheDocument();
  expect(screen.getByText(/BP-INK-001 · Quantity: 2000 KG/)).toBeInTheDocument();
  expect(screen.getByText('Not reached')).toBeInTheDocument();
  expect(screen.getByText('No eligible supplier quote')).toBeInTheDocument();
  expect(screen.queryByRole('link', { name: /Review purchase order/ })).not.toBeInTheDocument();
});

it('shows QA pass and fail results with product context and exact inspection links', async () => {
  dashboardService.getAiValidationHistory.mockResolvedValue([
    { workflowId: 'WF-PASS', workflowStatus: 'WaitingForApproval', materialId: 'BP-INK-001', materialName: 'Ink', quantity: 2000, unit: 'KG', validationExecuted: true, isValid: true },
    { workflowId: 'WF-FAIL', workflowStatus: 'Failed', materialId: 'BP-FILM-001', quantity: 500, validationExecuted: true, isValid: false, rejectionReason: 'Inventory quarantined' },
  ]);
  renderPanel(true);
  expect(await screen.findByText('WF-PASS')).toBeInTheDocument();
  expect(screen.getByText(/Ink \(BP-INK-001\) · Quantity: 2000 KG/)).toBeInTheDocument();
  expect(screen.getByText('Passed')).toBeInTheDocument();
  expect(screen.getByText('Failed', { selector: 'strong' })).toBeInTheDocument();
  expect(screen.getAllByRole('link', { name: 'Inspect validation' })[0]).toHaveAttribute('href', '/quality/ai-validation?workflowId=WF-PASS');
  expect(agentWorkflowService.getWorkflows).not.toHaveBeenCalled();
});

it('links a validated workflow to the actual purchase order', async () => {
  agentWorkflowService.getWorkflows.mockResolvedValue([{ workflowId: 'WF-PO', status: 'WaitingForApproval', purchaseOrderId: 12,
    validationResults: { isValid: true, supplierValidation: 'PASSED' }, details: { material_id: 'FILM', draft_po: { quantity: 750 } } }]);
  renderPanel();
  expect(await screen.findByRole('link', { name: 'Review purchase order' })).toHaveAttribute('href', '/purchase-orders/12');
  expect(screen.getByText('Passed')).toBeInTheDocument();
});
