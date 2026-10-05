import { useCallback, useEffect, useRef, useState } from 'react';
import { useLocation } from 'react-router-dom';

export default function useMobileNavigation() {
  const { pathname } = useLocation();
  const [menu, setMenu] = useState({ open: false, pathname });
  if (menu.pathname !== pathname) setMenu({ open: false, pathname });
  const mobileMenuOpen = menu.open && menu.pathname === pathname;
  const setMobileMenuOpen = useCallback((value) => {
    setMenu((previous) => ({ pathname, open: typeof value === 'function' ? value(previous.open) : value }));
  }, [pathname]);
  const sidebarRef = useRef(null);
  useEffect(() => {
    if (!mobileMenuOpen) return;
    const previousFocus = document.activeElement;
    const previousOverflow = document.body.style.overflow;
    const desktop = window.matchMedia('(min-width: 1024px)');
    const close = () => setMobileMenuOpen(false);
    if (desktop.matches) { close(); return; }
    document.body.style.overflow = 'hidden';
    const focusable = () => [...(sidebarRef.current?.querySelectorAll('a[href], button:not([disabled])') || [])]
      .filter((element) => element.getClientRects().length > 0);
    focusable()[0]?.focus();
    const handleKey = (event) => {
      if (event.key === 'Escape') close();
      if (event.key !== 'Tab') return;
      const elements = focusable();
      const first = elements[0];
      const last = elements.at(-1);
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus(); }
      else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus(); }
    };
    document.addEventListener('keydown', handleKey);
    desktop.addEventListener('change', close);
    return () => {
      document.body.style.overflow = previousOverflow;
      document.removeEventListener('keydown', handleKey);
      desktop.removeEventListener('change', close);
      previousFocus?.focus();
    };
  }, [mobileMenuOpen, setMobileMenuOpen]);
  return { mobileMenuOpen, setMobileMenuOpen, sidebarRef };
}
