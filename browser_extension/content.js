(() => {
  let settings = {
    serverUrl: "http://127.0.0.1:47117",
    enableSelection: true,
    shortcutKey: "Alt+q"
  };

  chrome.storage.sync.get(["serverUrl", "enableSelection", "shortcutKey"], (data) => {
    if (data.serverUrl) settings.serverUrl = data.serverUrl.replace(/\/+$/, "");
    if (data.enableSelection !== undefined) settings.enableSelection = data.enableSelection;
    if (data.shortcutKey) settings.shortcutKey = data.shortcutKey;
  });

  chrome.storage.onChanged.addListener((changes) => {
    if (changes.serverUrl) settings.serverUrl = changes.serverUrl.newValue.replace(/\/+$/, "");
    if (changes.enableSelection !== undefined) settings.enableSelection = changes.enableSelection.newValue;
    if (changes.shortcutKey) settings.shortcutKey = changes.shortcutKey.newValue;
  });

  let hostEl = null;
  let shadowRoot = null;
  let triggerIcon = null;
  let popupCard = null;
  let currentSelectionWord = "";
  let currentWord = "";

  function isDarkTheme() {
    return window.matchMedia("(prefers-color-scheme: dark)").matches;
  }

  function ensureShadowDOM() {
    if (hostEl) return;
    hostEl = document.createElement("div");
    hostEl.id = "ciyue-extension-host";
    hostEl.style.position = "absolute";
    hostEl.style.top = "0";
    hostEl.style.left = "0";
    hostEl.style.zIndex = "2147483647";
    document.documentElement.appendChild(hostEl);

    shadowRoot = hostEl.attachShadow({ mode: "open" });

    const style = document.createElement("style");
    style.textContent = `
      * { box-sizing: border-box; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
      
      .ciyue-trigger-icon {
        position: absolute;
        width: 28px;
        height: 28px;
        border-radius: 8px;
        background: #6750A4;
        box-shadow: 0 2px 10px rgba(0,0,0,0.28);
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
        font-size: 14px;
        font-weight: bold;
        z-index: 1000;
        transition: transform 0.15s;
        user-select: none;
      }
      .ciyue-trigger-icon:hover { transform: scale(1.12); background: #533E85; }

      .ciyue-popup {
        position: absolute;
        width: 440px;
        max-width: calc(100vw - 32px);
        max-height: 560px;
        background: #FFFFFF;
        color: #1D1B20;
        border-radius: 16px;
        box-shadow: 0 8px 30px rgba(0,0,0,0.24);
        border: 1px solid rgba(0,0,0,0.12);
        display: flex;
        flex-direction: column;
        overflow: hidden;
        z-index: 1001;
        font-size: 14px;
      }

      @media (prefers-color-scheme: dark) {
        .ciyue-popup {
          background: #211F26;
          color: #E6E0E9;
          border-color: rgba(255,255,255,0.14);
        }
      }

      .ciyue-header {
        padding: 10px 14px;
        background: #F3EDF7;
        display: flex;
        align-items: center;
        justify-content: space-between;
        cursor: move;
        user-select: none;
        border-bottom: 1px solid rgba(0,0,0,0.08);
      }
      @media (prefers-color-scheme: dark) {
        .ciyue-header {
          background: #2B2930;
          border-color: rgba(255,255,255,0.08);
        }
      }

      .ciyue-title-area {
        display: flex;
        align-items: center;
        gap: 8px;
        font-size: 16px;
        font-weight: 700;
        color: #6750A4;
      }
      @media (prefers-color-scheme: dark) {
        .ciyue-title-area { color: #D0BCFF; }
      }

      .ciyue-header-actions {
        display: flex;
        align-items: center;
        gap: 6px;
      }

      .ciyue-btn {
        background: none;
        border: none;
        cursor: pointer;
        padding: 4px 8px;
        border-radius: 8px;
        font-size: 13px;
        color: inherit;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      .ciyue-btn:hover { background: rgba(128,128,128,0.15); }
      .ciyue-star-btn { font-size: 16px; color: #79747E; }
      .ciyue-star-btn.active { color: #E8B931; }

      .ciyue-nav-tabs {
        display: flex;
        background: rgba(0,0,0,0.03);
        border-bottom: 1px solid rgba(0,0,0,0.08);
        overflow-x: auto;
      }
      .ciyue-tab {
        padding: 8px 14px;
        cursor: pointer;
        font-size: 13px;
        font-weight: 500;
        white-space: nowrap;
        border-bottom: 2px solid transparent;
        color: #49454F;
      }
      @media (prefers-color-scheme: dark) {
        .ciyue-tab { color: #CAC4D0; }
      }
      .ciyue-tab.active {
        color: #6750A4;
        border-bottom-color: #6750A4;
        font-weight: 600;
      }
      @media (prefers-color-scheme: dark) {
        .ciyue-tab.active {
          color: #D0BCFF;
          border-bottom-color: #D0BCFF;
        }
      }

      .ciyue-content-body {
        flex: 1;
        overflow-y: auto;
        min-height: 180px;
        max-height: 440px;
        position: relative;
      }

      /* Collapsible Dictionary Card */
      .ciyue-dict-item {
        border-bottom: 1px solid rgba(0,0,0,0.08);
      }
      @media (prefers-color-scheme: dark) {
        .ciyue-dict-item { border-color: rgba(255,255,255,0.08); }
      }
      .ciyue-dict-item-header {
        padding: 8px 14px;
        background: rgba(0,0,0,0.02);
        cursor: pointer;
        user-select: none;
        display: flex;
        align-items: center;
        justify-content: space-between;
        font-size: 13px;
        font-weight: 600;
      }
      .ciyue-dict-item-header:hover {
        background: rgba(103, 80, 164, 0.08);
      }
      .ciyue-dict-title {
        display: flex;
        align-items: center;
        gap: 6px;
      }
      .ciyue-chevron {
        font-size: 10px;
        transition: transform 0.2s;
        color: #6750A4;
      }
      @media (prefers-color-scheme: dark) {
        .ciyue-chevron { color: #D0BCFF; }
      }
      .ciyue-dict-item.collapsed .ciyue-chevron {
        transform: rotate(-90deg);
      }
      .ciyue-dict-item.collapsed .ciyue-frame-wrapper {
        display: none;
      }

      .ciyue-frame {
        width: 100%;
        min-height: 160px;
        height: 280px;
        border: none;
        display: block;
        background: #FFFFFF;
      }

      /* AI Box */
      .ciyue-ai-view {
        padding: 14px;
        line-height: 1.6;
        font-size: 13px;
        white-space: pre-wrap;
        display: none;
      }
      .ciyue-ai-view h2, .ciyue-ai-view h3 {
        margin: 8px 0 4px 0;
        color: #6750A4;
        font-size: 14px;
      }
      @media (prefers-color-scheme: dark) {
        .ciyue-ai-view h2, .ciyue-ai-view h3 { color: #D0BCFF; }
      }

      .ciyue-loading, .ciyue-empty {
        padding: 40px 20px;
        text-align: center;
        color: #79747E;
      }
    `;
    shadowRoot.appendChild(style);

    triggerIcon = document.createElement("div");
    triggerIcon.className = "ciyue-trigger-icon";
    triggerIcon.textContent = "悦";
    triggerIcon.title = "词悦查词";
    triggerIcon.style.display = "none";
    shadowRoot.appendChild(triggerIcon);

    triggerIcon.addEventListener("mousedown", (e) => e.stopPropagation());
    triggerIcon.addEventListener("click", (e) => {
      e.stopPropagation();
      const word = currentSelectionWord;
      hideTriggerIcon();
      showPopup(word, lastMouseX, lastMouseY);
    });

    popupCard = document.createElement("div");
    popupCard.className = "ciyue-popup";
    popupCard.style.display = "none";
    shadowRoot.appendChild(popupCard);

    makeDraggable(popupCard);
  }

  let lastMouseX = 0;
  let lastMouseY = 0;

  document.addEventListener("mouseup", (e) => {
    if (!settings.enableSelection) return;
    if (popupCard && popupCard.contains(e.target)) return;

    lastMouseX = e.pageX;
    lastMouseY = e.pageY;

    setTimeout(() => {
      const selection = window.getSelection();
      const text = selection ? selection.toString().trim() : "";

      if (text && text.length >= 1 && text.length <= 50 && !/\n/.test(text)) {
        currentSelectionWord = text;
        showTriggerIcon(e.pageX + 8, e.pageY + 10);
      } else {
        hideTriggerIcon();
      }
    }, 10);
  });

  document.addEventListener("mousedown", (e) => {
    if (hostEl && e.composedPath().includes(hostEl)) return;
    hideTriggerIcon();
    if (popupCard) popupCard.style.display = "none";
  });

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      hideTriggerIcon();
      if (popupCard) popupCard.style.display = "none";
      return;
    }

    if (e.altKey && (e.key === "q" || e.key === "Q")) {
      const selection = window.getSelection();
      const text = selection ? selection.toString().trim() : "";
      if (text) {
        showPopup(text, lastMouseX || window.innerWidth / 2, lastMouseY || window.innerHeight / 3);
      }
    }
  });

  chrome.runtime.onMessage.addListener((msg) => {
    if (msg.type === "CIYUE_LOOKUP" && msg.word) {
      showPopup(msg.word, window.innerWidth / 2 - 200, 100);
    }
  });

  function showTriggerIcon(x, y) {
    ensureShadowDOM();
    triggerIcon.style.left = `${x}px`;
    triggerIcon.style.top = `${y}px`;
    triggerIcon.style.display = "flex";
  }

  function hideTriggerIcon() {
    if (triggerIcon) triggerIcon.style.display = "none";
  }

  async function showPopup(word, x, y) {
    ensureShadowDOM();
    currentWord = word;

    const popupWidth = 440;
    let posX = Math.max(16, Math.min(x, window.innerWidth - popupWidth - 24));
    let posY = y + 15;
    if (posY + 420 > window.innerHeight + window.scrollY) {
      posY = Math.max(10, y - 430);
    }

    popupCard.style.left = `${posX}px`;
    popupCard.style.top = `${posY}px`;
    popupCard.style.display = "flex";

    popupCard.innerHTML = `
      <div class="ciyue-header">
        <div class="ciyue-title-area">
          <span>📖 ${escapeHtml(word)}</span>
        </div>
        <div class="ciyue-header-actions">
          <button class="ciyue-btn ciyue-star-btn" id="star-btn" title="生词本">☆</button>
          <button class="ciyue-btn" id="close-btn" title="关闭">✕</button>
        </div>
      </div>
      <div class="ciyue-loading">正在查询词悦词典...</div>
    `;

    popupCard.querySelector("#close-btn").addEventListener("click", () => {
      popupCard.style.display = "none";
    });

    try {
      const res = await fetch(`${settings.serverUrl}/api/lookup?word=${encodeURIComponent(word)}`);
      const data = await res.json();
      renderLookupResult(data);
    } catch (_) {
      popupCard.innerHTML = `
        <div class="ciyue-header">
          <div class="ciyue-title-area"><span>📖 词悦</span></div>
          <button class="ciyue-btn" id="close-btn">✕</button>
        </div>
        <div class="ciyue-empty">
          <p>无法连接到词悦桌面端服务</p>
          <p style="font-size:12px; margin-top:6px; color:#938F99;">请确保词悦已打开并已开启「Web 与 API 服务」</p>
        </div>
      `;
      popupCard.querySelector("#close-btn").addEventListener("click", () => {
        popupCard.style.display = "none";
      });
    }
  }

  function renderLookupResult(data) {
    popupCard.innerHTML = `
      <div class="ciyue-header">
        <div class="ciyue-title-area">
          <span>📖 ${escapeHtml(data.word)}</span>
        </div>
        <div class="ciyue-header-actions">
          <button class="ciyue-btn ciyue-star-btn ${data.stared ? 'active' : ''}" id="star-btn" title="生词本">
            ${data.stared ? '★' : '☆'}
          </button>
          <button class="ciyue-btn" id="close-btn" title="关闭">✕</button>
        </div>
      </div>
      <div class="ciyue-nav-tabs">
        <div class="ciyue-tab active" id="tab-dicts">📚 本地词典 (${(data.results || []).length})</div>
        <div class="ciyue-tab" id="tab-ai">🤖 AI 深度释义</div>
      </div>
      <div class="ciyue-content-body">
        <div id="dicts-container"></div>
        <div class="ciyue-ai-view" id="ai-container"></div>
      </div>
    `;

    popupCard.querySelector("#close-btn").addEventListener("click", () => {
      popupCard.style.display = "none";
    });

    const starBtn = popupCard.querySelector("#star-btn");
    starBtn.addEventListener("click", async () => {
      const isStared = starBtn.classList.contains("active");
      try {
        if (isStared) {
          await fetch(`${settings.serverUrl}/api/wordbook?word=${encodeURIComponent(data.word)}`, { method: "DELETE" });
          starBtn.classList.remove("active");
          starBtn.textContent = "☆";
        } else {
          await fetch(`${settings.serverUrl}/api/wordbook?word=${encodeURIComponent(data.word)}`, { method: "POST" });
          starBtn.classList.add("active");
          starBtn.textContent = "★";
        }
      } catch (_) {}
    });

    const tabDicts = popupCard.querySelector("#tab-dicts");
    const tabAi = popupCard.querySelector("#tab-ai");
    const dictsContainer = popupCard.querySelector("#dicts-container");
    const aiContainer = popupCard.querySelector("#ai-container");

    let aiRequested = false;
    tabDicts.addEventListener("click", () => {
      tabDicts.classList.add("active");
      tabAi.classList.remove("active");
      dictsContainer.style.display = "block";
      aiContainer.style.display = "none";
    });

    tabAi.addEventListener("click", () => {
      tabAi.classList.add("active");
      tabDicts.classList.remove("active");
      dictsContainer.style.display = "none";
      aiContainer.style.display = "block";

      if (!aiRequested) {
        aiRequested = true;
        streamAiExplain(data.word, aiContainer);
      }
    });

    if (!data.results || data.results.length === 0) {
      dictsContainer.innerHTML = `<div class="ciyue-empty">未在当前词典中查到条目</div>`;
      return;
    }

    // Render collapsible dictionary list
    data.results.forEach((item, index) => {
      const itemEl = document.createElement("div");
      itemEl.className = "ciyue-dict-item";
      itemEl.id = `dict-item-${index}`;

      itemEl.innerHTML = `
        <div class="ciyue-dict-item-header">
          <div class="ciyue-dict-title">
            <span class="ciyue-chevron">▼</span>
            <span>${escapeHtml(item.dictTitle || "词典")}</span>
          </div>
          <span style="font-size:11px; opacity:0.8;">${escapeHtml(item.headword || "")}</span>
        </div>
        <div class="ciyue-frame-wrapper">
          <iframe class="ciyue-frame" id="frame-${index}" sandbox="allow-same-origin allow-scripts"></iframe>
        </div>
      `;

      itemEl.querySelector(".ciyue-dict-item-header").addEventListener("click", () => {
        itemEl.classList.toggle("collapsed");
      });

      dictsContainer.appendChild(itemEl);

      setTimeout(() => {
        const frame = itemEl.querySelector(`#frame-${index}`);
        if (!frame) return;
        const frameDoc = frame.contentDocument || frame.contentWindow.document;
        const baseHref = `${settings.serverUrl}${item.resourceBase}`;

        frameDoc.open();
        frameDoc.write(`
          <!DOCTYPE html>
          <html>
          <head>
            <base href="${baseHref}">
            <meta charset="utf-8">
            <style>
              body { font-family: sans-serif; padding: 12px; margin: 0; line-height: 1.45; font-size: 13px; color: #1f1f1f; }
              a { color: #1a73e8; text-decoration: none; cursor: pointer; }
              a:hover { text-decoration: underline; }
            </style>
            <script src="${settings.serverUrl}/assets/darkreader.js"><\/script>
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
                  window.parent.postMessage({ type: 'CIYUE_SUB_LOOKUP', word: href.replace('entry://', '') }, '*');
                }
              });
            <\/script>
          </body>
          </html>
        `);
        frameDoc.close();

        frame.onload = () => {
          try {
            const h = frameDoc.body.scrollHeight;
            if (h > 100) frame.style.height = Math.min(Math.max(h + 20, 160), 380) + 'px';
          } catch (_) {}
        };
      }, 0);
    });
  }

  async function streamAiExplain(word, targetEl) {
    targetEl.textContent = "🤖 正在请求 AI 深度解析...";

    try {
      const res = await fetch(`${settings.serverUrl}/api/ai/explain?word=${encodeURIComponent(word)}&stream=true`);
      if (!res.ok) {
        const err = await res.json();
        targetEl.innerHTML = `<span style="color:#d32f2f;">${escapeHtml(err.error || "AI 提供商未在词悦中配置")}</span>`;
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
    if (e.data && e.data.type === "CIYUE_SUB_LOOKUP" && e.data.word) {
      if (popupCard) {
        showPopup(e.data.word, parseInt(popupCard.style.left) || 100, parseInt(popupCard.style.top) || 100);
      }
    }
  });

  function makeDraggable(el) {
    let isDragging = false;
    let startX = 0, startY = 0, origLeft = 0, origTop = 0;

    el.addEventListener("mousedown", (e) => {
      const header = e.target.closest(".ciyue-header");
      if (!header || e.target.closest("button")) return;
      isDragging = true;
      startX = e.clientX;
      startY = e.clientY;
      origLeft = parseInt(el.style.left) || 0;
      origTop = parseInt(el.style.top) || 0;
      e.preventDefault();
    });

    document.addEventListener("mousemove", (e) => {
      if (!isDragging) return;
      el.style.left = `${origLeft + (e.clientX - startX)}px`;
      el.style.top = `${origTop + (e.clientY - startY)}px`;
    });

    document.addEventListener("mouseup", () => {
      isDragging = false;
    });
  }

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
