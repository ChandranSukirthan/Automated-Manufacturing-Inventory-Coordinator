import React from 'react';
import { Outlet } from 'react-router-dom';
import { useAuth } from '../../context/useAuth';
import { normalizeRole } from '../../utils/roles';
import SCMLayout from './SCMLayout';
import AdminLayout from './AdminLayout';
import QALayout from './QALayout';
import WorkerLayout from './WorkerLayout';

export default function RoleLayout({ children, ...props }) {
  const { user } = useAuth();
  const role = normalizeRole(user?.role);
  const Layout = {
    ITAdmin: AdminLayout, QualityInspector: QALayout, FloorWorker: WorkerLayout,
    SupplyChainManager: SCMLayout,
  }[role] || WorkerLayout;
  return <Layout {...props}>{children ?? <Outlet />}</Layout>;
}
