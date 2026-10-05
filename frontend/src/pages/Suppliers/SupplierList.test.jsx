import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import SupplierList from './SupplierList';
import supplierService from '../../services/supplierService';

vi.mock('../../context/useAuth', () => ({ useAuth: () => ({ user: { role: 'SupplyChainManager', fullName: 'Manager' }, logout: vi.fn() }) }));
vi.mock('../../services/supplierService', () => ({ default: { getPage: vi.fn() } }));
afterEach(() => { cleanup(); vi.clearAllMocks(); });

describe('supplier server paging contract', () => {
  it('uses server totals and requests the next page', async () => {
    supplierService.getPage.mockResolvedValue({ items: [{ id: 1, supplierCode: 'SUP1', name: 'Vendor A', contactEmail: 'vendor@example.test', contactPhone: '', address: '', isActive: true }], totalCount: 16, page: 1, pageSize: 8 });
    render(<MemoryRouter><SupplierList /></MemoryRouter>);
    await screen.findByText('Vendor A');
    expect(screen.getByText(/of 16 suppliers/)).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Next' }));
    await waitFor(() => expect(supplierService.getPage).toHaveBeenCalledWith(expect.objectContaining({ page: 2, pageSize: 8 }), expect.any(AbortSignal)));
  });
});
