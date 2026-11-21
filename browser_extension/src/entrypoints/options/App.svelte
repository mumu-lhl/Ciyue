<script lang="ts">
  import { onMount } from 'svelte';
  import BookOpen from 'lucide-svelte/icons/book-open';
  import Server from 'lucide-svelte/icons/server';
  import MousePointerClick from 'lucide-svelte/icons/mouse-pointer-click';
  import ShieldAlert from 'lucide-svelte/icons/shield-alert';
  import CircleCheck from 'lucide-svelte/icons/circle-check';
  import CircleAlert from 'lucide-svelte/icons/circle-alert';
  import LoaderCircle from 'lucide-svelte/icons/loader-circle';
  import Save from 'lucide-svelte/icons/save';
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
        message: `连接成功！已连接到词悦桌面端，当前分组已加载 ${status.dictionariesCount || 0} 本词典。`,
      };
    } catch (err: any) {
      testResult = {
        status: 'error',
        message: `连接失败：${err.message || '无法访问'}。请确认词悦桌面端已打开并开启服务。`,
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

<div class="min-h-screen bg-zinc-50 dark:bg-zinc-950 text-zinc-900 dark:text-zinc-100 py-10 px-4 font-sans antialiased flex justify-center">
  <div class="w-full max-w-2xl flex flex-col gap-6">
    <!-- Header -->
    <header class="flex items-center gap-3 pb-2">
      <div class="w-10 h-10 rounded-xl bg-violet-600/10 dark:bg-violet-400/10 flex items-center justify-center text-violet-600 dark:text-violet-400 shrink-0">
        <BookOpen class="w-5 h-5" />
      </div>
      <div>
        <h1 class="text-lg font-bold text-zinc-900 dark:text-zinc-100 tracking-tight">
          词悦查词助手 · 扩展设置
        </h1>
        <p class="text-xs text-zinc-500 dark:text-zinc-400">
          配置浏览器拓展与词悦桌面端的连接方式及划词交互行为
        </p>
      </div>
    </header>

    <!-- Card 1: Desktop Connection -->
    <section class="bg-white dark:bg-zinc-900 border border-zinc-200/90 dark:border-zinc-800 rounded-2xl p-6 shadow-xs flex flex-col gap-4">
      <div class="flex items-center gap-2 text-sm font-bold text-zinc-900 dark:text-zinc-100">
        <Server class="w-4 h-4 text-violet-600 dark:text-violet-400" />
        <h2>桌面端服务连接</h2>
      </div>

      <div class="flex flex-col gap-2">
        <label for="server-url" class="text-xs font-semibold text-zinc-700 dark:text-zinc-300">
          服务地址 (Server URL)
        </label>
        <p class="text-[11px] text-zinc-400">
          词悦桌面端「设置」->「Web 与 API 服务」所监听的完整地址
        </p>
        <div class="flex gap-2">
          <input
            id="server-url"
            type="text"
            bind:value={form.serverUrl}
            placeholder="http://127.0.0.1:47117"
            class="flex-1 px-3.5 py-2 rounded-xl border border-zinc-200 dark:border-zinc-750 bg-zinc-50/70 dark:bg-zinc-800/60 text-xs text-zinc-900 dark:text-zinc-100 outline-none focus:border-violet-500 focus:ring-2 focus:ring-violet-500/15 transition-all"
          />
          <button
            class="px-4 py-2 rounded-xl bg-zinc-100 hover:bg-zinc-200/80 dark:bg-zinc-800 dark:hover:bg-zinc-700 text-zinc-700 dark:text-zinc-200 text-xs font-semibold border border-zinc-200 dark:border-zinc-700 transition-all cursor-pointer flex items-center gap-1.5 shrink-0 disabled:opacity-60"
            disabled={testing}
            onclick={testConnection}
          >
            {#if testing}
              <LoaderCircle class="w-3.5 h-3.5 animate-spin" />
              <span>测试中...</span>
            {:else}
              <span>测试连接</span>
            {/if}
          </button>
        </div>

        {#if testResult}
          <div
            class="mt-2 p-3 rounded-xl flex items-start gap-2 text-xs {testResult.status === 'success'
              ? 'bg-emerald-50 dark:bg-emerald-950/30 text-emerald-700 dark:text-emerald-300 border border-emerald-200/60 dark:border-emerald-800/60'
              : 'bg-rose-50 dark:bg-rose-950/30 text-rose-700 dark:text-rose-300 border border-rose-200/60 dark:border-rose-800/60'}"
          >
            {#if testResult.status === 'success'}
              <CircleCheck class="w-4 h-4 shrink-0 mt-0.5 text-emerald-500" />
            {:else}
              <CircleAlert class="w-4 h-4 shrink-0 mt-0.5 text-rose-500" />
            {/if}
            <span>{testResult.message}</span>
          </div>
        {/if}
      </div>
    </section>

    <!-- Card 2: Trigger Interaction -->
    <section class="bg-white dark:bg-zinc-900 border border-zinc-200/90 dark:border-zinc-800 rounded-2xl p-6 shadow-xs flex flex-col gap-5">
      <div class="flex items-center gap-2 text-sm font-bold text-zinc-900 dark:text-zinc-100">
        <MousePointerClick class="w-4 h-4 text-violet-600 dark:text-violet-400" />
        <h2>划词查词交互</h2>
      </div>

      <div class="flex flex-col gap-4 divide-y divide-zinc-100 dark:divide-zinc-800">
        <div class="flex items-start justify-between gap-4 pt-1">
          <div>
            <span class="text-xs font-semibold text-zinc-800 dark:text-zinc-200 block">
              划词后显示「悦」字浮标
            </span>
            <span class="text-[11px] text-zinc-400">
              选中网页文本后在鼠标旁弹出快捷浮标，点击展开查词卡片。
            </span>
          </div>
          <input
            type="checkbox"
            bind:checked={form.enableSelection}
            class="w-4 h-4 rounded text-violet-600 accent-violet-600 cursor-pointer shrink-0 mt-1"
          />
        </div>

        <div class="flex items-start justify-between gap-4 pt-4">
          <div>
            <span class="text-xs font-semibold text-zinc-800 dark:text-zinc-200 block">
              双击单词直接查词
            </span>
            <span class="text-[11px] text-zinc-400">
              双击页面单词时无需点击浮标，直接呼出查词卡片。
            </span>
          </div>
          <input
            type="checkbox"
            bind:checked={form.enableDoubleClick}
            class="w-4 h-4 rounded text-violet-600 accent-violet-600 cursor-pointer shrink-0 mt-1"
          />
        </div>

        <div class="flex flex-col gap-2 pt-4">
          <label for="modifier-key" class="text-xs font-semibold text-zinc-800 dark:text-zinc-200">
            划词修饰键要求
          </label>
          <span class="text-[11px] text-zinc-400">
            设置仅在按住某个按键时划词才触发，防止日常浏览误触。
          </span>
          <select
            id="modifier-key"
            bind:value={form.requireModifierKey}
            class="px-3 py-2 rounded-xl border border-zinc-200 dark:border-zinc-750 bg-zinc-50/70 dark:bg-zinc-800/60 text-xs text-zinc-800 dark:text-zinc-200 outline-none cursor-pointer max-w-sm"
          >
            <option value="none">无需按键（默认任何划词均触发）</option>
            <option value="alt">按住 Alt 键划词</option>
            <option value="ctrl">按住 Ctrl (或 Cmd) 键划词</option>
            <option value="shift">按住 Shift 键划词</option>
          </select>
        </div>

        <div class="flex items-start justify-between gap-4 pt-4">
          <div>
            <span class="text-xs font-semibold text-zinc-800 dark:text-zinc-200 block">
              在输入框与文本编辑区内禁用
            </span>
            <span class="text-[11px] text-zinc-400">
              在网页输入框 (input)、多行文本域 (textarea) 或富文本编辑器内划词时不弹浮标。
            </span>
          </div>
          <input
            type="checkbox"
            bind:checked={form.excludeEditable}
            class="w-4 h-4 rounded text-violet-600 accent-violet-600 cursor-pointer shrink-0 mt-1"
          />
        </div>
      </div>
    </section>

    <!-- Card 3: Blacklist -->
    <section class="bg-white dark:bg-zinc-900 border border-zinc-200/90 dark:border-zinc-800 rounded-2xl p-6 shadow-xs flex flex-col gap-4">
      <div class="flex items-center gap-2 text-sm font-bold text-zinc-900 dark:text-zinc-100">
        <ShieldAlert class="w-4 h-4 text-violet-600 dark:text-violet-400" />
        <h2>网址黑名单</h2>
      </div>

      <div class="flex flex-col gap-2">
        <label for="blacklist" class="text-xs font-semibold text-zinc-700 dark:text-zinc-300">
          不启用查词的网站域名列表
        </label>
        <span class="text-[11px] text-zinc-400">
          每行一个域名（例如：<code>github.com</code> 或 <code>mail.google.com</code>），在这些网站上将完全不注入查词功能。
        </span>
        <textarea
          id="blacklist"
          rows="4"
          bind:value={blacklistText}
          placeholder="example.com&#10;internal.company.net"
          class="w-full p-3 rounded-xl border border-zinc-200 dark:border-zinc-750 bg-zinc-50/70 dark:bg-zinc-800/60 font-mono text-xs text-zinc-800 dark:text-zinc-200 outline-none focus:border-violet-500 focus:ring-2 focus:ring-violet-500/15 transition-all resize-y"
        ></textarea>
      </div>
    </section>

    <!-- Footer Actions -->
    <div class="flex items-center justify-end gap-3 pb-8">
      {#if savedToast}
        <div class="flex items-center gap-1.5 text-xs text-emerald-600 dark:text-emerald-400 font-semibold animate-fade-in">
          <CircleCheck class="w-4 h-4" />
          <span>设置已保存！</span>
        </div>
      {/if}

      <button
        class="px-5 py-2.5 rounded-xl bg-violet-600 hover:bg-violet-700 active:scale-95 text-white text-xs font-semibold shadow-xs shadow-violet-500/20 cursor-pointer transition-all flex items-center gap-1.5"
        onclick={save}
      >
        <Save class="w-4 h-4" />
        <span>保存设置</span>
      </button>
    </div>
  </div>
</div>
