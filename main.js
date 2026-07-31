const { app, BrowserWindow, ipcMain, session } = require("electron");
const fs = require("fs");
const path = require("path");

const KIOSK_URL =
  "https://api.vixisuite-staging.thefamousgroup.com/go/i/EGfoK5oc26htkfnW";

/** @type {Map<string, string>} */
const pendingFilenames = new Map();

function getPrintsDir() {
  return path.join(app.getPath("desktop"), "Dreams", "Prints");
}

function ensurePrintsDir() {
  const printsDir = getPrintsDir();
  fs.mkdirSync(printsDir, { recursive: true });
  return printsDir;
}

function uniqueSavePath(dir, filename) {
  const ext = path.extname(filename);
  const base = path.basename(filename, ext) || "dream";
  let candidate = path.join(dir, `${base}${ext}`);
  let n = 1;

  while (fs.existsSync(candidate)) {
    candidate = path.join(dir, `${base}-${n}${ext}`);
    n += 1;
  }

  return candidate;
}

function createWindow() {
  const win = new BrowserWindow({
    fullscreen: true,
    autoHideMenuBar: true,
    backgroundColor: "#000000",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  win.setMenuBarVisibility(false);
  win.loadURL(KIOSK_URL);

  // Bridge page events → electronAPI.triggerDownload
  win.webContents.on("dom-ready", () => {
    win.webContents.executeJavaScript(`
      (() => {
        if (window.__dreamDownloadBridgeInstalled) return;
        window.__dreamDownloadBridgeInstalled = true;

        function handleDownloadRequest(detail) {
          if (!detail || !detail.url || !window.electronAPI?.triggerDownload) return;
          const filename = detail.filename || ('dream-' + Date.now() + '.png');
          window.electronAPI.triggerDownload(detail.url, filename);
        }

        // CustomEvent: window.dispatchEvent(new CustomEvent('download-file', { detail: { url, filename } }))
        window.addEventListener('download-file', (event) => {
          handleDownloadRequest(event.detail || {});
        });

        // postMessage: window.postMessage({ type: 'download-file', url, filename }, '*')
        window.addEventListener('message', (event) => {
          const data = event.data;
          if (!data || data.type !== 'download-file') return;
          handleDownloadRequest(data);
        });

        // Intercept <a download> clicks so the page's normal save path uses IPC
        document.addEventListener('click', (event) => {
          const anchor = event.target?.closest?.('a[download]');
          if (!anchor || !anchor.href) return;
          event.preventDefault();
          event.stopPropagation();
          handleDownloadRequest({
            url: anchor.href,
            filename: anchor.download || undefined,
          });
        }, true);
      })();
    `).catch((err) => {
      console.error("Failed to install download bridge:", err);
    });
  });

  // Escape exits fullscreen (handy for development)
  win.webContents.on("before-input-event", (_event, input) => {
    if (input.type === "keyDown" && input.key === "Escape") {
      win.setFullScreen(false);
    }
  });

  return win;
}

app.whenReady().then(() => {
  const printsDir = ensurePrintsDir();

  // Configure save path whenever Electron starts a download (incl. downloadURL)
  session.defaultSession.on("will-download", (_event, item, webContents) => {
    const url = item.getURL();
    const filename =
      pendingFilenames.get(url) ||
      item.getFilename() ||
      `dream-${Date.now()}.png`;
    pendingFilenames.delete(url);

    const savePath = uniqueSavePath(printsDir, filename);
    item.setSavePath(savePath);

    item.on("updated", (_updateEvent, state) => {
      if (state === "interrupted") {
        console.log("Download interrupted:", filename);
      } else if (state === "progressing" && !item.isPaused()) {
        console.log(
          `Downloading ${filename}: ${item.getReceivedBytes()} / ${item.getTotalBytes()}`
        );
      }
    });

    item.once("done", (_doneEvent, state) => {
      const win = BrowserWindow.fromWebContents(webContents);
      if (state === "completed") {
        console.log("Download successfully saved to:", savePath);
        win?.webContents.send("download-status", {
          status: "success",
          path: savePath,
        });
      } else {
        console.error(`Download failed: ${state}`);
        win?.webContents.send("download-status", {
          status: "failed",
          reason: state,
        });
      }
    });
  });

  // Handle download IPC event from preload / page bridge
  ipcMain.on("download-file", (event, { url, filename } = {}) => {
    if (!url) {
      console.error("download-file missing url");
      return;
    }

    const win = BrowserWindow.fromWebContents(event.sender);
    if (!win) return;

    const safeName = filename || `dream-${Date.now()}.png`;
    pendingFilenames.set(url, safeName);

    // Trigger Electron's native download manager
    win.webContents.downloadURL(url);
  });

  createWindow();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});
