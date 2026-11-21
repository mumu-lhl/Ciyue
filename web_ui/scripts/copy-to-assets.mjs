import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const srcHtml = path.resolve(__dirname, "../dist/index.html");
const destDir = path.resolve(__dirname, "../../assets/web");
const destHtml = path.resolve(destDir, "index.html");

if (fs.existsSync(srcHtml)) {
  if (!fs.existsSync(destDir)) {
    fs.mkdirSync(destDir, { recursive: true });
  }
  fs.copyFileSync(srcHtml, destHtml);
  console.log(`[copy-to-assets] Synced ${srcHtml} -> ${destHtml}`);
} else {
  console.error(`[copy-to-assets] Source file not found: ${srcHtml}`);
  process.exit(1);
}
