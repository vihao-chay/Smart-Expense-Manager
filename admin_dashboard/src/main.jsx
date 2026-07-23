import React from 'react';
import { createRoot } from 'react-dom/client';

import App from './App.jsx';
import './styles.css';

const rootElement = document.getElementById('root');

if (!rootElement) {
  throw new Error('Không tìm thấy phần tử root để khởi tạo Admin Dashboard.');
}

createRoot(rootElement).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
