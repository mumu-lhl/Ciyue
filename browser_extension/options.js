(() => {
  const serverUrlInput = document.getElementById("server-url");
  const enableSelectionCheckbox = document.getElementById("enable-selection");
  const testBtn = document.getElementById("test-btn");
  const testStatus = document.getElementById("test-status");
  const saveBtn = document.getElementById("save-btn");

  chrome.storage.sync.get(["serverUrl", "enableSelection"], (data) => {
    if (data.serverUrl) serverUrlInput.value = data.serverUrl;
    if (data.enableSelection !== undefined) enableSelectionCheckbox.checked = data.enableSelection;
  });

  testBtn.addEventListener("click", async () => {
    testStatus.textContent = "正在测试连接...";
    testStatus.style.color = "inherit";
    const url = serverUrlInput.value.trim().replace(/\/+$/, "");

    try {
      const res = await fetch(`${url}/api/status`);
      if (res.ok) {
        const data = await res.json();
        testStatus.textContent = `✅ 连接成功！已加载 ${data.dictionariesCount || 0} 本词典。`;
        testStatus.style.color = "#4CAF50";
      } else {
        throw new Error(`HTTP ${res.status}`);
      }
    } catch (e) {
      testStatus.textContent = `❌ 连接失败：${e.message || "无法访问"}。请确认词悦已开启 Web 服务。`;
      testStatus.style.color = "#F44336";
    }
  });

  saveBtn.addEventListener("click", () => {
    const serverUrl = serverUrlInput.value.trim().replace(/\/+$/, "");
    const enableSelection = enableSelectionCheckbox.checked;

    chrome.storage.sync.set({ serverUrl, enableSelection }, () => {
      alert("设置已保存！");
    });
  });
})();
