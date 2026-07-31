const { app, BrowserWindow, session } = require("electron");
const fs = require("fs");
const path = require("path");

const KIOSK_URL =
  "https://api.vixisuite-staging.thefamousgroup.com/go/i/EGfoK5oc26htkfnW";

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
      nodeIntegration: false,
      contextIsolation: true,
    },
  });

  win.setMenuBarVisibility(false);
  win.loadURL(KIOSK_URL);

  // Escape exits fullscreen (handy for development)
  win.webContents.on("before-input-event", (_event, input) => {
    if (input.type === "keyDown" && input.key === "Escape") {
      win.setFullScreen(false);
    }
  });
}

app.whenReady().then(() => {
  const printsDir = ensurePrintsDir();

  // Auto-save downloads to Desktop/Dreams/Prints — no Save As dialog
  session.defaultSession.on("will-download", (_event, item) => {
    const filename = item.getFilename() || `dream-${Date.now()}.png`;
    const savePath = uniqueSavePath(printsDir, filename);
    item.setSavePath(savePath);

    item.once("done", (_e, state) => {
      if (state === "completed") {
        console.log(`Saved: ${savePath}`);
      } else {
        console.error(`Download failed (${state}): ${filename}`);
      }
    });
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
