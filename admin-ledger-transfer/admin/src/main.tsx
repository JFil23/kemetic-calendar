import React from "react";
import ReactDOM from "react-dom/client";

import { App } from "./app/App";
import "./styles/global.css";

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    void navigator.serviceWorker.register("/sw.js").catch(() => {
      // Shell caching is optional; auth and data still work without it.
    });
  });
}
