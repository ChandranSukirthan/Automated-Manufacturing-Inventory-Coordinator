import React from 'react';
import { afterEach, expect, it, vi } from 'vitest';
import { cleanup, render, screen } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import PurchaseOrderCreate from './PurchaseOrderCreate';
import procurementService from '../../services/procurementService';
import purchaseOrderService from '../../services/purchaseOrderService';

vi.mock('../../components/Layout/AppLayout', () => ({ default: ({ children }) => <div>{children}</div> }));
vi.mock('../../services/supplierService', () => ({ default: { getSuppliers: vi.fn().mockResolvedValue([]) } }));
vi.mock('../../services/rawMaterialService', () => ({ default: { getRawMaterials: vi.fn().mockResolvedValue([]) } }));
vi.mock('../../services/procurementService', () => ({ default: { getRequest: vi.fn() } }));
vi.mock('../../services/purchaseOrderService', () => ({ default: { createPurchaseOrder: vi.fn() } }));
afterEach(() => { cleanup(); vi.clearAllMocks(); });

it('opens an existing linked order instead of offering another creation', async () => {
  procurementService.getRequest.mockResolvedValue({ id: 4, generatedPurchaseOrderId: 26 });
  render(<MemoryRouter initialEntries={['/purchase-orders/create?procurementId=4&candidateId=8']}>
    <Routes>
      <Route path="/purchase-orders/create" element={<PurchaseOrderCreate />} />
      <Route path="/purchase-orders/26" element={<div>Existing order 26</div>} />
    </Routes>
  </MemoryRouter>);
  expect(await screen.findByText('Existing order 26')).toBeInTheDocument();
  expect(procurementService.getRequest).toHaveBeenCalledWith(4);
  expect(purchaseOrderService.createPurchaseOrder).not.toHaveBeenCalled();
});
