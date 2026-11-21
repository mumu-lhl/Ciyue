import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import tailwindcss from "@tailwindcss/vite";
import { viteSingleFile } from "vite-plugin-singlefile";

export default defineConfig({
  plugins: [tailwindcss(), svelte(), viteSingleFile()],
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: "http://127.0.0.1:47117",
        changeOrigin: true,
      },
      "/assets": {
        target: "http://127.0.0.1:47117",
        changeOrigin: true,
      },
    },
  },
  build: {
    target: "esnext",
    assetsInlineLimit: 100000000,
    chunkSizeWarningLimit: 100000000,
    cssCodeSplit: false,
    rollupOptions: {
      onwarn(warning, defaultHandler) {
        if (warning.code === "SOURCEMAP_BROKEN") return;
        defaultHandler(warning);
      },
      output: {
        inlineDynamicImports: true,
      },
    },
  },
});
