import React from 'react';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { useAuth } from '../../context/useAuth';
import purchaseOrderService from '../../services/purchaseOrderService';
import RoleLayout from './RoleLayout';
import ModalOverlay from '../Common/ModalOverlay';
import RoleHomeRedirect from '../Auth/RoleHomeRedirect';

vi.mock('../../context/useAuth', () => ({ useAuth: vi.fn() }));
vi.mock('../../services/adminService', () => ({ default: { getAgentWorkflows: vi.fn().mockResolvedValue([]) } }));
vi.mock('../../services/purchaseOrderService', () => ({ default: { getPurchaseOrders: vi.fn().mockResolvedValue([]) } }));
vi.mock('../Notifications/StockAlertNotifications', () => ({ default: () => <span>Stock notifications</span> }));

function renderSharedPage(role, path = '/ai-approvals') {
  vi.mocked(useAuth).mockReturnValue({ user: { role, fullName: 'Current User' }, logout: vi.fn() });
  return render(<MemoryRouter initialEntries={[path]}>
    <RoleLayout title="Shared page"><p>Page content</p></RoleLayout>
  </MemoryRouter>);
}

describe('Role navigation on shared pages', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    window.matchMedia = vi.fn().mockReturnValue({ matches: false, addEventListener: vi.fn(), removeEventListener: vi.fn() });
  });
  afterEach(cleanup);

  it.each([
    ['3', '/admin', 'Admin dashboard'],
    ['SupplyChainManager', '/dashboard/manager', 'SCM dashboard'],
  ])('redirects the legacy dashboard to the correct home for %s', (role, home, label) => {
    vi.mocked(useAuth).mockReturnValue({ user: { role }, logout: vi.fn() });
    render(<MemoryRouter initialEntries={['/dashboard/admin']}><Routes>
      <Route path="/dashboard/admin" element={<RoleHomeRedirect />} />
      <Route path={home} element={<p>{label}</p>} />
    </Routes></MemoryRouter>);
    expect(screen.getByText(label)).toBeInTheDocument();
  });

  it('keeps Admin navigation on payment approvals without mounting the SCM shell', async () => {
    renderSharedPage('3');
    expect(screen.getByRole('link', { name: /Admin Hub/i })).toHaveAttribute('href', '/admin');
    expect(screen.queryByText('Supply Chain Manager')).not.toBeInTheDocument();
    expect(purchaseOrderService.getPurchaseOrders).not.toHaveBeenCalled();
    expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1);
    await waitFor(() => expect(screen.getByText('Page content')).toBeInTheDocument());
  });

  it('keeps the Worker navigation on replenishment and renders the user name once', () => {
    renderSharedPage(0, '/worker/replenishment');
    expect(screen.getByRole('navigation', { name: 'Floor Worker navigation' })).toBeInTheDocument();
    expect(screen.getAllByText('Current User')).toHaveLength(1);
    expect(screen.queryByRole('link', { name: /Admin Hub/i })).not.toBeInTheDocument();
  });

  it('uses the canonical SCM dashboard destination', async () => {
    renderSharedPage('SupplyChainManager', '/profile');
    expect(screen.getByRole('link', { name: 'Dashboard' })).toHaveAttribute('href', '/dashboard/manager');
    expect(screen.getByRole('link', { name: 'My Profile' })).toHaveAttribute('href', '/profile');
    await waitFor(() => expect(purchaseOrderService.getPurchaseOrders).toHaveBeenCalled());
  });

  it('renders nested QA page content through the role layout outlet', () => {
    vi.mocked(useAuth).mockReturnValue({ user: { role: 'QualityInspector' }, logout: vi.fn() });
    render(<MemoryRouter initialEntries={['/quality/defects']}><Routes>
      <Route element={<RoleLayout />}><Route path="/quality/defects" element={<p>Defect workspace</p>} /></Route>
    </Routes></MemoryRouter>);
    expect(screen.getByText('Defect workspace')).toBeInTheDocument();
    expect(screen.getByRole('complementary', { name: 'Quality Control Sidebar' })).toBeInTheDocument();
    expect(screen.getAllByRole('heading', { level: 1 })).toHaveLength(1);
  });

  it('keeps the Machines menu highlighted on a machine detail page', async () => {
    renderSharedPage('ITAdmin', '/machines/42');
    expect(screen.getByRole('link', { name: 'Machines' }).className).toContain('bg-gradient');
    await waitFor(() => expect(screen.getByText('Page content')).toBeInTheDocument());
  });

  it('locks background scrolling while the mobile drawer is open and closes with Escape', async () => {
    renderSharedPage('ITAdmin');
    fireEvent.click(screen.getByRole('button', { name: 'Open menu' }));
    expect(document.body.style.overflow).toBe('hidden');
    fireEvent.keyDown(document, { key: 'Escape' });
    expect(document.body.style.overflow).toBe('');
    await waitFor(() => expect(screen.getByText('Page content')).toBeInTheDocument());
  });

  it('renders dialogs above the shell outside header stacking contexts', () => {
    const { container } = render(<header><ModalOverlay className="fixed inset-0 z-50"><p>Dialog content</p></ModalOverlay></header>);
    const overlay = screen.getByText('Dialog content').parentElement;
    expect(overlay.parentElement).toBe(document.body);
    expect(overlay.className).toContain('z-[100]');
    expect(container.querySelector('header')).toBeEmptyDOMElement();
  });
});
