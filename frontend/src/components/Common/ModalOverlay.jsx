import React from 'react';
import { createPortal } from 'react-dom';

export default function ModalOverlay({ children, className = '', ...props }) {
  return createPortal(
    <div {...props} className={`role-modal-overlay ${className.replace(/\bz-50\b/g, 'z-[100]')}`}>
      {children}
    </div>, document.body,
  );
}
