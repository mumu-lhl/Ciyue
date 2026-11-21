import { defineConfig } from "wxt";
import tailwindcss from "@tailwindcss/vite";
import fs from "node:fs";
import path from "node:path";

export default defineConfig({
  srcDir: "src",
  modules: ["@wxt-dev/module-svelte"],
  vite: () => ({
    build: {
      rollupOptions: {
        onwarn(warning, defaultHandler) {
          if (warning.code === "SOURCEMAP_BROKEN") return;
          defaultHandler(warning);
        },
      },
    },
    plugins: [
      tailwindcss(),
      {
        name: "sync-darkreader-asset",
        buildStart() {
          const src = path.resolve(
            import.meta.dirname,
            "../../assets/third_party/darkreader/darkreader.js",
          );
          const destDir = path.resolve(import.meta.dirname, "public/assets");
          const dest = path.resolve(destDir, "darkreader.js");
          if (!fs.existsSync(destDir)) {
            fs.mkdirSync(destDir, { recursive: true });
          }
          if (fs.existsSync(src)) {
            fs.copyFileSync(src, dest);
          }
        },
      },
    ],
  }),
  manifest: {
    name: "词悦 (Ciyue) 查词助手",
    description:
      "词悦桌面端配套浏览器扩展，提供网页划词/双击即时查词、AI 深度解析与翻译、离线词典渲染及生词本一键收藏。",
    version: "1.1.0",
    icons: {
      16: "icons/icon16.png",
      48: "icons/icon48.png",
      128: "icons/icon128.png",
    },
    action: {
      default_title: "词悦查词",
      default_popup: "popup.html",
      default_icon: {
        16: "icons/icon16.png",
        48: "icons/icon48.png",
        128: "icons/icon128.png",
      },
    },
    permissions: ["storage", "contextMenus"],
    host_permissions: ["http://127.0.0.1:*/*", "http://localhost:*/*"],
    commands: {
      "lookup-selection": {
        suggested_key: {
          default: "Alt+Q",
          mac: "Alt+Q",
        },
        description: "在词悦中查询选中的文字",
      },
    },
    web_accessible_resources: [
      {
        resources: ["icons/*", "assets/*"],
        matches: ["<all_urls>"],
      },
    ],
  },
});
