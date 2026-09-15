import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../../context/useAuth';

const links = [
  { label: 'Dashboard', to: '/quality' },
  { label: 'Defect Reports', to: '/quality/defects' },
  { label: 'Quarantine Management', to: '/quality/quarantine' },
  { label: 'Quarantine History', to: '/quality/quarantine/history' }
];

export default function QANavigation() {
  const navigate = useNavigate();
  const { logout } = useAuth();

  const handleLogout = () => {
    logout();
    navigate('/login', { replace: true });
  };

  return (
    <nav className="flex flex-wrap items-center gap-2 border-b border-slate-800 pb-4 mb-8" aria-label="Quality Assurance navigation">
      {links.map((link) => (
        <NavLink
          key={link.to}
          to={link.to}
          end={link.to === '/quality' || link.to === '/quality/quarantine'}
          className={({ isActive }) => `px-3 py-2 rounded-lg text-sm ${isActive ? 'bg-emerald-500 text-slate-950 font-semibold' : 'text-slate-300 hover:bg-slate-800'}`}
        >
          {link.label}
        </NavLink>
      ))}
      <button onClick={handleLogout} className="px-3 py-2 rounded-lg text-sm text-rose-300 border border-rose-500/50 hover:bg-rose-500/10">Logout</button>
    </nav>
  );
}
