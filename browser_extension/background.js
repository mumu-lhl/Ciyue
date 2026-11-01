chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "ciyue-search-selection",
    title: "在词悦中查询 \"%s\"",
    contexts: ["selection"]
  });
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId === "ciyue-search-selection" && info.selectionText) {
    if (tab && tab.id) {
      chrome.tabs.sendMessage(tab.id, {
        type: "CIYUE_LOOKUP",
        word: info.selectionText.trim()
      });
    }
  }
});
