<script lang="ts">
  import { onMount } from 'svelte';
  import { getSettings, saveSettings } from '../../utils/settings';
  import { CiyueApiClient } from '../../api/client';
  import type { ExtensionSettings } from '../../api/types';

  let form = $state<ExtensionSettings>({
    serverUrl: 'http://127.0.0.1:47117',
    enableSelection: true,
    enableDoubleClick: false,
    requireModifierKey: 'none',
    excludeEditable: true,
    blacklistUrls: [],
  });

  let blacklistText = $state('');
  let testing = $state(false);
  let testResult = $state<{ status: 'success' | 'error'; message: string } | null>(null);
  let savedToast = $state(false);

  onMount(async () => {
    const current = await getSettings();
    form = { ...current };
    blacklistText = (form.blacklistUrls || []).join('\n');
  });

  async function testConnection() {
    testing = true;
    testResult = null;

    try {
      const client = new CiyueApiClient(form.serverUrl);
      const status = await client.getStatus();
      testResult = {
        status: 'success',
        message: `✅ 连接成功！已连接到词悦桌面端，当前分组已加载 ${status.dictionariesCount || 0} 本词典。`,
      };
    } catch (err: any) {
      testResult = {
        status: 'error',
        message: `❌ 连接失败：${err.message || '无法访问'}。请确认词悦桌面端已打开并开启服务。`,
      };
    } finally {
      testing = false;
    }
  }

  async function save() {
    form.blacklistUrls = blacklistText
      .split('\n')
      .map((s) => s.trim())
      .filter(Boolean);

    await saveSettings(form);

    savedToast = true;
    setTimeout(() => {
      savedToast = false;
    }, 2500);
  }
</script>

<div class="options-page">
  <div class="container">
    <header class="header">
      <h1>📖 词悦查词助手 - 扩展设置</h1>
      <p class="subtitle">配置浏览器与词悦桌面端的连接方式及划词交互行为</p>
    </header>

    <!-- Section: Server Connection -->
    <section class="card">
      <h2 class="card-title">🔌 桌面端连接</h2>
      <div class="form-group">
        <label for="server-url">服务地址 (Server URL)</label>
        <div class="hint">词悦桌面端「设置」->「Web 与 API 服务」所监听的完整地址</div>
        <div class="input-row">
          <input
            id="server-url"
            type="text"
            bind:value={form.serverUrl}
            placeholder="http://127.0.0.1:47117"
          />
          <button
            class="btn secondary"
            disabled={testing}
            onclick={testConnection}
          >
            {testing ? '测试中...' : '测试连接'}
          </button>
        </div>
        {#if testResult}
          <div class="test-feedback {testResult.status}">
            {testResult.message}
          </div>
        {/if}
      </div>
    </section>

    <!-- Section: Interaction -->
    <section class="card">
      <h2 class="card-title">🖱️ 查词触发方式</h2>

      <div class="checkbox-row">
        <label class="switch-label">
          <input type="checkbox" bind:checked={form.enableSelection} />
          <span class="label-text">划词后显示「悦」字浮标</span>
        </label>
        <div class="hint indent">选中文字后在鼠标旁弹出快捷浮标，点击展开查词卡片。</div>
      </div>

      <div class="checkbox-row">
        <label class="switch-label">
          <input type="checkbox" bind:checked={form.enableDoubleClick} />
          <span class="label-text">双击单词直接查词</span>
        </label>
        <div class="hint indent">双击页面单词时无需点击浮标，直接呼出查词卡片。</div>
      </div>

      <div class="form-group" style="margin-top: 8px;">
        <label for="modifier-key">划词修饰键要求</label>
        <div class="hint">可设置仅在按住某个按键时划词才触发，防止日常浏览误触。</div>
        <select id="modifier-key" bind:value={form.requireModifierKey} class="select-box">
          <option value="none">无需按键（默认任何划词均触发）</option>
          <option value="alt">按住 Alt 键划词</option>
          <option value="ctrl">按住 Ctrl (或 Cmd) 键划词</option>
          <option value="shift">按住 Shift 键划词</option>
        </select>
      </div>

      <div class="checkbox-row" style="margin-top: 8px;">
        <label class="switch-label">
          <input type="checkbox" bind:checked={form.excludeEditable} />
          <span class="label-text">在输入框与文本编辑区内禁用</span>
        </label>
        <div class="hint indent">在网页输入框 (input)、多行文本域 (textarea) 或富文本编辑器内划词时不弹浮标。</div>
      </div>
    </section>

    <!-- Section: Blacklist -->
    <section class="card">
      <h2 class="card-title">🚫 网址黑名单</h2>
      <div class="form-group">
        <label for="blacklist">不启用查词的网站域名列表</label>
        <div class="hint">每行一个域名（例如：github.com 或 mail.google.com），在这些网站上将完全不注入查词功能。</div>
        <textarea
          id="blacklist"
          rows="4"
          bind:value={blacklistText}
          placeholder="example.com&#10;internal.company.net"
        ></textarea>
      </div>
    </section>

    <!-- Save Button -->
    <div class="footer-actions">
      {#if savedToast}
        <span class="save-toast">✓ 设置已保存！</span>
      {/if}
      <button class="btn primary" onclick={save}>保存设置</button>
    </div>
  </div>
</div>

<style>
  .options-page {
    background: var(--bg);
    color: var(--text);
    min-height: 100vh;
    padding: 40px 20px;
    display: flex;
    justify-content: center;
    font-size: 14px;
  }
  .container {
    width: 100%;
    max-width: 620px;
    display: flex;
    flex-direction: column;
    gap: 24px;
  }
  .header h1 {
    font-size: 20px;
    font-weight: 700;
    color: var(--primary);
    margin-bottom: 4px;
  }
  .subtitle {
    font-size: 13px;
    color: var(--text-muted);
  }
  .card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 16px;
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 16px;
  }
  .card-title {
    font-size: 15px;
    font-weight: 700;
    color: var(--text);
  }
  .form-group {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  label {
    font-weight: 600;
    font-size: 13.5px;
  }
  .hint {
    font-size: 12px;
    color: var(--text-muted);
    line-height: 1.4;
  }
  .hint.indent {
    padding-left: 24px;
  }
  .input-row {
    display: flex;
    gap: 10px;
  }
  input[type="text"],
  select,
  textarea {
    flex: 1;
    padding: 9px 12px;
    border-radius: 10px;
    border: 1px solid var(--border);
    background: var(--bg);
    color: inherit;
    font-size: 13.5px;
    outline: none;
    transition: border-color 0.15s ease;
  }
  input[type="text"]:focus,
  select:focus,
  textarea:focus {
    border-color: var(--primary);
  }
  .select-box {
    cursor: pointer;
  }
  textarea {
    resize: vertical;
    line-height: 1.5;
    font-family: monospace;
  }
  .checkbox-row {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .switch-label {
    display: flex;
    align-items: center;
    gap: 8px;
    cursor: pointer;
  }
  .switch-label input[type="checkbox"] {
    width: 16px;
    height: 16px;
    accent-color: var(--primary);
    cursor: pointer;
  }
  .label-text {
    font-weight: 600;
    font-size: 13.5px;
  }
  .btn {
    padding: 8px 18px;
    border-radius: 20px;
    border: none;
    cursor: pointer;
    font-weight: 600;
    font-size: 13.5px;
    transition: opacity 0.15s ease, background 0.15s ease;
  }
  .btn.primary {
    background: var(--primary);
    color: #ffffff;
  }
  .btn.primary:hover {
    background: var(--primary-hover);
  }
  .btn.secondary {
    background: var(--surface-variant);
    color: var(--text);
    border: 1px solid var(--border);
  }
  .btn.secondary:hover {
    background: rgba(128, 128, 128, 0.2);
  }
  .test-feedback {
    font-size: 12.5px;
    padding: 8px 12px;
    border-radius: 8px;
    margin-top: 4px;
  }
  .test-feedback.success {
    background: rgba(76, 175, 80, 0.15);
    color: var(--success);
  }
  .test-feedback.error {
    background: rgba(244, 67, 54, 0.15);
    color: var(--danger);
  }
  .footer-actions {
    display: flex;
    justify-content: flex-end;
    align-items: center;
    gap: 12px;
    padding-bottom: 20px;
  }
  .save-toast {
    color: var(--success);
    font-weight: 600;
    font-size: 13px;
    animation: fadeIn 0.2s ease;
  }
  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(4px); }
    to { opacity: 1; transform: translateY(0); }
  }
</style>
