import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import ThemeToggle from './ThemeToggle';
import './styles.css';
import './theme.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
    <ThemeToggle />
  </React.StrictMode>,
);
