const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("electronAPI", {
  triggerDownload: (url, filename) => {
    ipcRenderer.send("download-file", { url, filename });
  },
  onDownloadStatus: (callback) => {
    const handler = (_event, data) => callback(data);
    ipcRenderer.on("download-status", handler);
    return () => ipcRenderer.removeListener("download-status", handler);
  },
});
