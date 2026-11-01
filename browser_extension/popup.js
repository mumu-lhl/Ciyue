(() => {
  let serverUrl = "http://127.0.0.1:47117";

  const input = document.getElementById("query-input");
  const searchBtn = document.getElementById("search-btn");
  const suggestionsBox = document.getElementById("suggestions");
  const contentArea = document.getElementById("content-area");
  const statusDot = document.getElementById("status-dot");

  chrome.storage.sync.get(["serverUrl"], (data) => {
    if (data.serverUrl) serverUrl = data.serverUrl.replace(/\/+$/, "");
    checkServerStatus();
  });

  async function checkServerStatus() {
    try {
      const res = await fetch(`${serverUrl}/api/status`);
      if (res.ok) {
        statusDot.classList.remove("offline");
        statusDot.title = "已连接到词悦桌面端";
      } else {
        throw new Error();
      }
    } catch (_) {
      statusDot.classList.add("offline");
      statusDot.title = "未连接到词悦（请确认已在词悦设置中开启 Web 服务）";
    }
  }

  let debounce = null;
  input.addEventListener("input", () => {
    const val = input.value.trim();
    if (!val) {
      suggestionsBox.style.display = "none";
      return;
    }
    clearTimeout(debounce);
    debounce = setTimeout(() => fetchSuggestions(val), 200);
  });

  input.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      suggestionsBox.style.display = "none";
      const q = input.value.trim();
      if (q) doLookup(q);
    }
  });

  searchBtn.addEventListener("click", () => {
    const q = input.value.trim();
    if (q) doLookup(q);
  });

  document.addEventListener("click", (e) => {
    if (!e.target.closest(".search-box")) {
      suggestionsBox.style.display = "none";
    }
  });

  async function fetchSuggestions(q) {
    try {
      const res = await fetch(`${serverUrl}/api/suggest?q=${encodeURIComponent(q)}`);
      const data = await res.json();
      const list = (data.dictionarySuggestions || []).concat(data.spellingSuggestions || []);
      const unique = [...new Set(list)].slice(0, 8);

      if (unique.length === 0) {
        suggestionsBox.style.display = "none";
        return;
      }

      suggestionsBox.innerHTML = unique.map(item => `<div class="suggestion-item">${escapeHtml(item)}</div>`).join("");
      suggestionsBox.style.display = "block";

      suggestionsBox.querySelectorAll(".suggestion-item").forEach(el => {
        el.addEventListener("click", () => {
          input.value = el.textContent;
          suggestionsBox.style.display = "none";
          doLookup(el.textContent);
        });
      });
    } catch (_) {}
  }

  async function doLookup(word) {
    contentArea.innerHTML = `<div class="loading">正在查询 “${escapeHtml(word)}”...</div>`;
    suggestionsBox.style.display = "none";

    try {
      const res = await fetch(`${serverUrl}/api/lookup?word=${encodeURIComponent(word)}`);
      const data = await res.json();

      if (!data.results || data.results.length === 0) {
        contentArea.innerHTML = `<div class="empty">未在词典中找到 “${escapeHtml(word)}”</div>`;
        return;
      }

      let html = `
        <div style="display:flex; justify-content:space-between; align-items:center; margin-top:8px;">
          <h2 style="font-size:18px;">${escapeHtml(data.word)}</h2>
          <button id="star-btn" style="background:none; border:none; cursor:pointer; font-size:18px; color:${data.stared ? '#E8B931' : '#79747E'};">
            ${data.stared ? '★' : '☆'}
          </button>
        </div>
      `;

      data.results.forEach((item, index) => {
        html += `
          <div class="dict-header">
            <span>${escapeHtml(item.dictTitle || "词典")}</span>
          </div>
          <iframe class="result-frame" id="frame-${index}" sandbox="allow-same-origin allow-scripts"></iframe>
        `;
      });

      contentArea.innerHTML = html;

      const starBtn = document.getElementById("star-btn");
      if (starBtn) {
        starBtn.addEventListener("click", async () => {
          const isStared = starBtn.textContent === "★";
          try {
            if (isStared) {
              await fetch(`${serverUrl}/api/wordbook?word=${encodeURIComponent(data.word)}`, { method: "DELETE" });
              starBtn.textContent = "☆";
              starBtn.style.color = "#79747E";
            } else {
              await fetch(`${serverUrl}/api/wordbook?word=${encodeURIComponent(data.word)}`, { method: "POST" });
              starBtn.textContent = "★";
              starBtn.style.color = "#E8B931";
            }
          } catch (_) {}
        });
      }

      data.results.forEach((item, index) => {
        const frame = document.getElementById(`frame-${index}`);
        if (!frame) return;
        const frameDoc = frame.contentDocument || frame.contentWindow.document;
        const baseHref = `${serverUrl}${item.resourceBase}`;

        frameDoc.open();
        frameDoc.write(`
          <!DOCTYPE html>
          <html>
          <head>
            <base href="${baseHref}">
            <meta charset="utf-8">
            <style>
              body { font-family: sans-serif; padding: 10px; margin: 0; line-height: 1.45; font-size: 13px; color: #1f1f1f; }
              a { color: #1a73e8; text-decoration: none; cursor: pointer; }
            </style>
          </head>
          <body>
            ${item.content}
            <script>
              document.addEventListener('click', (e) => {
                const a = e.target.closest('a');
                if (!a) return;
                const href = a.getAttribute('href');
                if (!href) return;
                if (href.startsWith('sound://')) {
                  e.preventDefault();
                  new Audio('${baseHref}' + href.replace('sound://', '')).play();
                } else if (href.startsWith('entry://')) {
                  e.preventDefault();
                  window.parent.postMessage({ type: 'POPUP_LOOKUP', word: href.replace('entry://', '') }, '*');
                }
              });
            <\/script>
          </body>
          </html>
        `);
        frameDoc.close();
      });
    } catch (e) {
      contentArea.innerHTML = `<div class="empty">查询失败: ${escapeHtml(e.message)}</div>`;
    }
  }

  window.addEventListener("message", (e) => {
    if (e.data && e.data.type === "POPUP_LOOKUP" && e.data.word) {
      input.value = e.data.word;
      doLookup(e.data.word);
    }
  });

  function escapeHtml(str) {
    if (!str) return "";
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }
})();
