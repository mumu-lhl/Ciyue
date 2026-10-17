import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Ciyue",
  description: "A mdict dictionary with Android/Windows/Linux/macOS support",
  base: '/Ciyue/',
  lastUpdated: true,

  locales: {
    root: {
      label: 'English',
      lang: 'en-US',
      title: "Ciyue",
      description: "A mdict dictionary with Android/Windows/Linux/macOS support",
      themeConfig: {
        nav: [
          { text: 'Home', link: '/' },
          { text: 'Guide', link: '/guide/' },
          { text: 'FAQ', link: '/guide/faq' }
        ],
        sidebar: [
          {
            text: 'Guide',
            items: [
              { text: 'Overview', link: '/guide/' },
              { text: 'Getting Started', link: '/guide/getting-started' },
              { text: 'Cloud Sync', link: '/guide/cloud-sync' },
              { text: 'FAQ', link: '/guide/faq' },
            ]
          }
        ],
        editLink: {
          pattern: 'https://github.com/mumu-lhl/Ciyue/edit/main/docs/:path',
          text: 'Edit this page on GitHub'
        },
      }
    },
    zh: {
      label: '简体中文',
      lang: 'zh-CN',
      link: '/zh/',
      title: "词悦",
      description: "支持 Android/Windows/Linux/macOS 的 mdict 词典",
      themeConfig: {
        nav: [
          { text: '首页', link: '/zh/' },
          { text: '指南', link: '/zh/guide/' },
          { text: '常见问题', link: '/zh/guide/faq' }
        ],
        sidebar: [
          {
            text: '指南',
            items: [
              { text: '总览', link: '/zh/guide/' },
              { text: '快速上手', link: '/zh/guide/getting-started' },
              { text: '云同步', link: '/zh/guide/cloud-sync' },
              { text: '常见问题', link: '/zh/guide/faq' },
            ]
          }
        ],
        editLink: {
          pattern: 'https://github.com/mumu-lhl/Ciyue/edit/main/docs/:path',
          text: '在 GitHub 上编辑此页'
        },
        lastUpdated: {
          text: '最后更新于'
        },
        docFooter: {
          prev: '上一页',
          next: '下一页'
        },
        search: {
          provider: 'local',
          options: {
            locales: {
              zh: {
                translations: {
                  button: {
                    buttonText: '搜索文档',
                    buttonAriaLabel: '搜索文档'
                  },
                  modal: {
                    noResultsText: '无法找到相关结果',
                    resetButtonTitle: '清除查询条件',
                    footer: {
                      selectText: '选择',
                      navigateText: '切换'
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  },

  themeConfig: {
    logo: 'https://raw.githubusercontent.com/mumu-lhl/Ciyue/main/assets/icon.png',

    search: {
      provider: 'local'
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/mumu-lhl/Ciyue' },
      { icon: 'discord', link: 'https://discord.gg/BazBZuvKZG' }
    ],

    footer: {
      message: 'Released under the <a href="https://github.com/mumu-lhl/Ciyue/blob/main/LICENSE">MIT License</a>.',
      copyright: 'Copyright © 2024-present mumu-lhl'
    }
  }
})
