import React from 'react';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, expect, it, vi } from 'vitest';
import AgentTab from './AgentTab';

afterEach(cleanup);
const props = { rawMaterials: [], stockLevels: [], triggeringAi: false, aiWorkflowResult: null };

it('uses the actual first material on first trigger and after catalogue changes', () => {
  const onTriggerAi = vi.fn();
  const { rerender } = render(<AgentTab {...props} rawMaterials={[{ skuCode: 'BP-FILM-001', name: 'Film' }]} onTriggerAi={onTriggerAi} />);
  fireEvent.click(screen.getByRole('button', { name: /Run Auto Replenishment/ }));
  expect(onTriggerAi).toHaveBeenLastCalledWith('BP-FILM-001', 2000);
  rerender(<AgentTab {...props} rawMaterials={[{ skuCode: 'BOT-RESIN-001', name: 'Resin' }]} onTriggerAi={onTriggerAi} />);
  fireEvent.click(screen.getByRole('button', { name: /Run Auto Replenishment/ }));
  expect(onTriggerAi).toHaveBeenLastCalledWith('BOT-RESIN-001', 2000);
});

it('does not invent a material when the catalogue is empty', () => {
  const onTriggerAi = vi.fn();
  render(<AgentTab {...props} onTriggerAi={onTriggerAi} />);
  expect(screen.getByRole('button', { name: /Run Auto Replenishment/ })).toBeDisabled();
  expect(screen.getByRole('option')).toHaveTextContent('No materials available');
});
