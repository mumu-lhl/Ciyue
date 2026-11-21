<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { marked } from 'marked';
  import { createAiStream } from '../utils/messaging';

  let {
    mode,
    text,
    serverUrl,
  }: {
    mode: 'explain' | 'translate';
    text: string;
    serverUrl: string;
  } = $props();

  let content = $state('');
  let streaming = $state(false);
  let errorMsg = $state('');
  let copied = $state(false);

  let cancelStream: (() => void) | null = null;

  let renderedMarkdown = $derived.by(() => {
    if (!content) return '';
    return marked.parse(content) as string;
  });

  function startStream() {
    if (!text.trim()) return;

    if (cancelStream) {
      cancelStream();
      cancelStream = null;
    }

    content = '';
    errorMsg = '';
    streaming = true;

    cancelStream = createAiStream(
      {
        mode,
        text,
        serverUrl,
      },
      (chunk) => {
        content += chunk;
      },
      (err) => {
        errorMsg = err;
        streaming = false;
      },
      () => {
        streaming = false;
      },
    );
  }

  async function copyContent() {
    if (!content) return;
    try {
      await navigator.clipboard.writeText(content);
      copied = true;
      setTimeout(() => {
        copied = false;
      }, 2000);
    } catch (_) {}
  }

  onMount(() => {
    startStream();
  });

  onDestroy(() => {
    if (cancelStream) {
      cancelStream();
    }
  });

  $effect(() => {
    const _t = text;
    const _m = mode;
    startStream();
  });
</script>

<div class="ciyue-ai-panel">
  <div class="ai-toolbar">
    <span class="ai-tag">
      {mode === 'translate' ? '🌐 AI 翻译' : '🤖 AI 深度解析'}
    </span>
    <div class="ai-actions">
      {#if content && !streaming}
        <button
          class="ai-action-btn"
          onclick={copyContent}
          title={copied ? '已复制' : '复制内容'}
        >
          {copied ? '✓ 已复制' : '📋 复制'}
        </button>
      {/if}
      {#if !streaming}
        <button
          class="ai-action-btn"
          onclick={startStream}
          title="重新生成"
        >
          🔄 重试
        </button>
      {/if}
    </div>
  </div>

  {#if errorMsg}
    <div class="ai-error-state">
      <span class="error-icon">⚠️</span>
      <div class="error-text">{errorMsg}</div>
      <div class="error-hint">请在词悦桌面端「设置」->「AI 模型服务」中配置 API Key。</div>
    </div>
  {:else}
    <div class="ai-content-box">
      {#if content}
        <div class="markdown-body">
          <!-- eslint-disable-next-line svelte/no-at-html-tags -->
          {@html renderedMarkdown}
        </div>
      {/if}
      {#if streaming && !content}
        <div class="ai-loading">
          <span class="pulse-dot"></span>
          <span>正在连接 AI 模型解析中...</span>
        </div>
      {/if}
      {#if streaming && content}
        <div class="ai-streaming-cursor"></div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .ciyue-ai-panel {
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .ai-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    border-bottom: 1px solid var(--border);
    padding-bottom: 8px;
  }
  .ai-tag {
    font-size: 12px;
    font-weight: 600;
    color: var(--primary);
    background: var(--surface);
    padding: 2px 8px;
    border-radius: 12px;
  }
  .ai-actions {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .ai-action-btn {
    background: none;
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 2px 8px;
    font-size: 11px;
    color: var(--text-muted);
    cursor: pointer;
    transition: all 0.15s ease;
  }
  .ai-action-btn:hover {
    background: var(--surface);
    color: var(--text);
    border-color: var(--primary);
  }
  .ai-error-state {
    padding: 20px 14px;
    text-align: center;
    background: var(--surface);
    border-radius: 10px;
    border: 1px dashed var(--danger);
  }
  .error-icon {
    font-size: 24px;
    margin-bottom: 6px;
    display: block;
  }
  .error-text {
    font-size: 13px;
    color: var(--danger);
    font-weight: 600;
    margin-bottom: 4px;
  }
  .error-hint {
    font-size: 12px;
    color: var(--text-muted);
  }
  .ai-content-box {
    position: relative;
    line-height: 1.6;
    font-size: 13.5px;
    max-height: 380px;
    overflow-y: auto;
    padding-right: 4px;
  }
  :global(.markdown-body h1),
  :global(.markdown-body h2),
  :global(.markdown-body h3) {
    margin: 10px 0 6px 0;
    color: var(--primary);
    font-size: 14.5px;
  }
  :global(.markdown-body p) {
    margin: 6px 0;
  }
  :global(.markdown-body ul),
  :global(.markdown-body ol) {
    padding-left: 20px;
    margin: 6px 0;
  }
  :global(.markdown-body li) {
    margin-bottom: 3px;
  }
  :global(.markdown-body code) {
    background: var(--surface-variant);
    padding: 2px 5px;
    border-radius: 4px;
    font-size: 12px;
    font-family: monospace;
  }
  :global(.markdown-body pre) {
    background: var(--surface);
    padding: 10px;
    border-radius: 8px;
    overflow-x: auto;
    border: 1px solid var(--border);
  }
  :global(.markdown-body blockquote) {
    margin: 6px 0;
    padding-left: 10px;
    border-left: 3px solid var(--primary);
    color: var(--text-muted);
  }
  .ai-loading {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    padding: 30px 10px;
    color: var(--text-muted);
    font-size: 13px;
  }
  .pulse-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: var(--primary);
    animation: pulse 1s infinite alternate;
  }
  @keyframes pulse {
    0% { transform: scale(0.8); opacity: 0.5; }
    100% { transform: scale(1.3); opacity: 1; }
  }
  .ai-streaming-cursor {
    display: inline-block;
    width: 6px;
    height: 14px;
    background: var(--primary);
    margin-left: 2px;
    vertical-align: middle;
    animation: blink 0.8s infinite;
  }
  @keyframes blink {
    0%, 100% { opacity: 1; }
    50% { opacity: 0; }
  }
</style>
