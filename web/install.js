(function () {
  let deferredPrompt = null;

  window.addEventListener('beforeinstallprompt', (e) => {
    // Stop Chrome from auto-showing the mini-infobar
    e.preventDefault();
    deferredPrompt = e;
    showInstallButton();
  });

  window.addEventListener('appinstalled', () => {
    hideInstallButton();
    deferredPrompt = null;
    console.log('PWA installed');
  });

  function showInstallButton() {
    if (document.getElementById('pwa-install-btn')) return;

    const btn = document.createElement('button');
    btn.id = 'pwa-install-btn';
    btn.textContent = 'Install app';
    Object.assign(btn.style, {
      position: 'fixed',
      right: '16px',
      bottom: '16px',
      padding: '10px 14px',
      borderRadius: '999px',
      border: 'none',
      fontWeight: '600',
      boxShadow: '0 6px 18px rgba(0,0,0,0.15)',
      cursor: 'pointer',
      zIndex: 99999,
      background: '#6B5AED',
      color: 'white'
    });
    btn.onclick = async () => {
      if (!deferredPrompt) return;
      btn.disabled = true;
      deferredPrompt.prompt();
      const { outcome } = await deferredPrompt.userChoice;
      console.log('install outcome', outcome);
      deferredPrompt = null;
      hideInstallButton();
    };
    document.body.appendChild(btn);
  }

  function hideInstallButton() {
    const btn = document.getElementById('pwa-install-btn');
    if (btn && btn.parentNode) btn.parentNode.removeChild(btn);
  }
})();
