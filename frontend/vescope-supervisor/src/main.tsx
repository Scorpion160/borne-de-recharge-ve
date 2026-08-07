import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import ThemeToggle from './ThemeToggle';
import { startHubClient } from './hubClient';
import './styles.css';
import './theme.css';

startHubClient();

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
    <ThemeToggle />
  </React.StrictMode>,
);
