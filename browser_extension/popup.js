(() => {
  let serverUrl = "http://127.0.0.1:47117";

  const input = document.getElementById("query-input");
  const searchBtn = document.getElementById("search-btn");
  const suggestionsBox = document.getElementById("suggestions");
  const contentArea = document.getElementById("content-area");
  const aiArea = document.getElementById("ai-area");
  const statusDot = document.getElementById("status-dot");
  const groupSelect = document.getElementById("group-select");
  const navTabs = document.getElementById("nav-tabs");
  const tabDicts = document.getElementById("tab-dicts");
  const tabAi = document.getElementById("tab-ai");

  let currentLookupData = null;
  let aiRequestedForWord = null;

  function isDarkTheme() {
    return window.matchMedia("(prefers-color-scheme: dark)").matches;
  }

  chrome.storage.sync.get(["serverUrl"], (data) => {
    if (data.serverUrl) serverUrl = data.serverUrl.replace(/\/+$/, "");
    checkServerStatus();
    loadGroups();
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

  async function loadGroups() {
    try {
      const res = await fetch(`${serverUrl}/api/groups`);
      const groups = await res.json();
      groupSelect.innerHTML = groups.map(g =>
        `<option value="${g.id}" ${g.isCurrent ? 'selected' : ''}>${escapeHtml(g.name)}</option>`
      ).join('');
    } catch (_) {}
  }

  groupSelect.addEventListener("change", async () => {
    try {
      await fetch(`${serverUrl}/api/groups/switch?id=${groupSelect.value}`, { method: "POST" });
      const q = input.value.trim();
      if (q) doLookup(q);
    } catch (_) {}
  });

  tabDicts.addEventListener("click", () => {
    tabDicts.classList.add("active");
    tabAi.classList.remove("active");
    contentArea.style.display = "block";
    aiArea.style.display = "none";
  });

  tabAi.addEventListener("click", () => {
    tabAi.classList.add("active");
    tabDicts.classList.remove("active");
    contentArea.style.display = "none";
    aiArea.style.display = "block";

    if (currentLookupData && currentLookupData.word && aiRequestedForWord !== currentLookupData.word) {
      aiRequestedForWord = currentLookupData.word;
      streamAiExplain(currentLookupData.word, aiArea);
    }
  });

  let debounce = null;
  input.addEventListener("input", () => {
    const val = input.value.trim();
    if (!val) {
      suggestionsBox.style.display = "none";
      return;
    }
    clearTimeout(debounce);
    debounce = setTimeout(() => fetchSuggestions(val), 180);
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
    navTabs.style.display = "none";
    aiArea.style.display = "none";
    tabDicts.classList.add("active");
    tabAi.classList.remove("active");
    contentArea.style.display = "block";
    aiRequestedForWord = null;

    try {
      const res = await fetch(`${serverUrl}/api/lookup?word=${encodeURIComponent(word)}`);
      const data = await res.json();
      currentLookupData = data;

      if (!data.results || data.results.length === 0) {
        contentArea.innerHTML = `<div class="empty">未在当前分组词典中找到 “${escapeHtml(word)}”</div>`;
        return;
      }

      navTabs.style.display = "flex";

      let html = `
        <div style="display:flex; justify-content:space-between; align-items:center; margin:8px 0;">
          <h2 style="font-size:18px; color:var(--primary);">${escapeHtml(data.word)}</h2>
          <button id="star-btn" style="background:none; border:none; cursor:pointer; font-size:18px; color:${data.stared ? '#E8B931' : '#79747E'};">
            ${data.stared ? '★' : '☆'}
          </button>
        </div>
      `;

      data.results.forEach((item, index) => {
        html += `
          <div class="dict-card" id="card-${index}">
            <div class="dict-header" onclick="document.getElementById('card-${index}').classList.toggle('collapsed')">
              <div>
                <span class="dict-chevron">▼</span>
                <span>${escapeHtml(item.dictTitle || "词典")}</span>
              </div>
              <span style="font-size:11px; opacity:0.8;">${escapeHtml(item.headword || "")}</span>
            </div>
            <iframe class="result-frame" id="frame-${index}" sandbox="allow-same-origin allow-scripts"></iframe>
          </div>
        `;
      });

      contentArea.innerHTML = html;

      const starBtn = document.getElementById("star-btn");
      if (starBtn) {
        starBtn.addEventListener("click", async () => {
          const isStared = starBtn.textContent.trim() === "★";
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
            <script src="${serverUrl}/assets/darkreader.js"><\/script>
          </head>
          <body>
            ${item.content}
            <script>
              if (window.DarkReader && ${isDarkTheme()}) {
                window.DarkReader.setFetchMethod(window.fetch);
                window.DarkReader.enable({
                  brightness: 100, contrast: 100, sepia: 0,
                  darkSchemeBackgroundColor: "#1e1e24", darkSchemeTextColor: "#e6e0e9"
                });
              }

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

  async function streamAiExplain(word, targetEl) {
    targetEl.textContent = "🤖 正在请求 AI 深度解析...";

    try {
      const res = await fetch(`${serverUrl}/api/ai/explain?word=${encodeURIComponent(word)}&stream=true`);
      if (!res.ok) {
        const err = await res.json();
        targetEl.innerHTML = `<span style="color:#d32f2f;">${escapeHtml(err.error || "AI 提供商未配置")}</span>`;
        return;
      }

      targetEl.textContent = "";
      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\n\n");
        buffer = lines.pop();

        for (const line of lines) {
          if (line.startsWith("data: ")) {
            const payload = line.substring(6);
            if (payload === "[DONE]") break;
            try {
              const parsed = JSON.parse(payload);
              if (parsed.chunk) targetEl.textContent += parsed.chunk;
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      targetEl.textContent = "请求失败: " + e.message;
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
