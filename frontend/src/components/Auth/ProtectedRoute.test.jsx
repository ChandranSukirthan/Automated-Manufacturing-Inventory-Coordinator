import React from 'react';
import { render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import ProtectedRoute from './ProtectedRoute';
import { useAuth } from '../../context/useAuth';

vi.mock('../../context/useAuth', () => ({ useAuth: vi.fn() }));

const renderProtectedRoute = () => render(
  <MemoryRouter initialEntries={['/worker/replenishment']}>
    <Routes>
      <Route
        path="/worker/replenishment"
        element={(
          <ProtectedRoute allowedRoles={[0, 'FloorWorker']}>
            <p>Replenishment workspace</p>
          </ProtectedRoute>
        )}
      />
      <Route path="/login" element={<p>Login page</p>} />
    </Routes>
  </MemoryRouter>,
);

describe('ProtectedRoute for Floor Worker pages', () => {
  beforeEach(() => {
    vi.mocked(useAuth).mockReturnValue({ loading: false, user: { role: 0 } });
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it('allows a Floor Worker to open the replenishment workspace', () => {
    renderProtectedRoute();
    expect(screen.getByText('Replenishment workspace')).toBeInTheDocument();
  });

  it('blocks a user without the Floor Worker role', () => {
    vi.mocked(useAuth).mockReturnValue({ loading: false, user: { role: 'QualityInspector' } });
    renderProtectedRoute();
    expect(screen.getByText(/Restricted Access/i)).toBeInTheDocument();
  });
});
