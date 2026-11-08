/* ==================================================================
   native.js — phone features
   Inside the Flutter app (lib/main.dart) the screens talk to Android through the
   channel "GridNavNative". In a normal browser the same functions fall back to
   the browser's own versions, so the web version keeps working too.
   ================================================================== */
(function (root) {
  'use strict';
  const isFlutter = () => !!(root.GridNavNative && typeof root.GridNavNative.postMessage === 'function');

  // --- request/answer over the channel -------------------------------------------------
  let seq = 0; const pending = {};
  root.__gnReply = (id, result, error) => {
    const p = pending[id]; if (!p) return; delete pending[id];
    if (error) p.reject(new Error(error)); else p.resolve(result);
  };
  function call(cmd, args = {}) {
    return new Promise((resolve, reject) => {
      const id = 'c' + (++seq); pending[id] = { resolve, reject };
      root.GridNavNative.postMessage(JSON.stringify({ id, cmd, args }));
    });
  }

  function download(filename, text, mime) {
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([text], { type: mime }));
    a.download = filename; document.body.appendChild(a); a.click();
    setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
  }

  const Native = {
    isFlutter,
    isApp: isFlutter,

    /** Print a full HTML page. Returns true when the phone handled it. */
    async print(html, name, landscape) {
      if (!isFlutter()) return false;
      await call('print', { html, name, landscape: !!landscape });
      return true;
    },

    /** Share a file (WhatsApp, email, Drive…). Returns 'shared' | 'cancelled' | 'downloaded'. */
    async shareFile(filename, text, mime, title) {
      if (isFlutter()) return call('share', { filename, text, mime, title });
      try {
        const file = new File([text], filename, { type: mime });
        if (navigator.canShare && navigator.canShare({ files: [file] })) { await navigator.share({ files: [file], title: title || filename }); return 'shared'; }
      } catch (e) { if (e && e.name === 'AbortError') return 'cancelled'; }
      download(filename, text, mime); return 'downloaded';
    },

    /** Save a file where the user chooses. Returns the place, or 'cancelled'. */
    async saveFile(filename, text, mime) {
      if (isFlutter()) return call('save', { filename, text, mime });
      download(filename, text, mime); return 'Downloads/' + filename;
    },

    /** Choose a file; returns { name, text } or null. */
    async pickFile(accept) {
      if (isFlutter()) return call('pick', {});
      return new Promise(resolve => {
        const inp = document.createElement('input'); inp.type = 'file'; if (accept) inp.accept = accept;
        inp.onchange = async () => { const f = inp.files[0]; resolve(f ? { name: f.name, text: await f.text() } : null); };
        inp.click();
      });
    },

    /** GPS position { lat, lon, acc }. */
    gps() {
      if (isFlutter()) return call('gps', {});
      return new Promise((resolve, reject) => {
        if (!navigator.geolocation) return reject(new Error('This device has no GPS access.'));
        navigator.geolocation.getCurrentPosition(
          p => resolve({ lat: p.coords.latitude, lon: p.coords.longitude, acc: p.coords.accuracy }),
          e => reject(new Error(e.code === 1 ? 'Location permission was refused. Allow it in the browser settings.' : 'Could not get a GPS fix. Try outside, away from buildings.')),
          { enableHighAccuracy: true, timeout: 20000, maximumAge: 0 });
      });
    },

    async copy(text) {
      if (isFlutter()) return call('copy', { text });
      await navigator.clipboard.writeText(text);
    }
  };
  root.Native = Native;
})(window);
