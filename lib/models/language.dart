/// Codes accepted by the app's functional language pickers, with names used
/// when a language is passed into an AI prompt.
const languageMap = {
  "auto": "Auto Detect",
  "en": "English",
  "zh": "简体中文",
  "zh_HK": "繁體中文",
  "zh_TW": "正體中文",
  "ja": "Japanese",
  "ko": "Korean",
  "fr": "French",
  "de": "Deutsch",
  "es": "Español",
  "ru": "Русский",
  "hi": "Hindi",
  "bn": "Bengali",
  "ca": "Catalan",
  "nb": "Bokmål",
  "sc": "Sardinian",
  "ta": "Tamil",
  "fa": "فارسی",
  "bg": "Bulgarian",
  "vi": "Tiếng Việt",
};

/// Exact aliases for the languages in [languageMap]. Each language covers
/// Simplified Chinese, Traditional Chinese, English, Japanese, and its own
/// endonym. Unknown names still fall back to auto rather than being guessed.
const _groupNameAliases = {
  // auto
  "自动": "auto",
  "自動": "auto",
  "自动检测": "auto",
  "自動偵測": "auto",
  "auto detect": "auto",
  // en
  "english": "en",
  "英语": "en",
  "英語": "en",
  "英文": "en",
  "英": "en",
  // zh
  "chinese": "zh",
  "mandarin": "zh",
  "simplified chinese": "zh",
  "chinese (simplified)": "zh",
  "中文": "zh",
  "漢語": "zh",
  "汉语": "zh",
  "汉语普通话": "zh",
  "普通话": "zh",
  "普通話": "zh",
  "简体": "zh",
  "簡體": "zh",
  "简体中文": "zh",
  "中国語": "zh",
  "簡体字中国語": "zh",
  "中": "zh",
  // zh_HK
  "traditional chinese": "zh_HK",
  "chinese (traditional)": "zh_HK",
  "繁体中文": "zh_HK",
  "繁體中文": "zh_HK",
  "繁体": "zh_HK",
  "繁體": "zh_HK",
  "香港繁体": "zh_HK",
  "香港繁體": "zh_HK",
  "繁体字中国語": "zh_HK",
  "香港繁体字": "zh_HK",
  // zh_TW
  "taiwan traditional": "zh_TW",
  "chinese (taiwan)": "zh_TW",
  "正体中文": "zh_TW",
  "正體中文": "zh_TW",
  "台湾繁体": "zh_TW",
  "台灣繁體": "zh_TW",
  "臺灣繁體": "zh_TW",
  "正体字中国語": "zh_TW",
  "台湾繁体字": "zh_TW",
  // ja
  "japanese": "ja",
  "日语": "ja",
  "日語": "ja",
  "日文": "ja",
  "日": "ja",
  "日本語": "ja",
  // ko
  "korean": "ko",
  "韩语": "ko",
  "韓語": "ko",
  "韩文": "ko",
  "韓文": "ko",
  "朝鲜语": "ko",
  "朝鮮語": "ko",
  "韩": "ko",
  "韓": "ko",
  "韓国語": "ko",
  "한국어": "ko",
  "조선말": "ko",
  // fr
  "french": "fr",
  "法语": "fr",
  "法語": "fr",
  "法文": "fr",
  "法": "fr",
  "フランス語": "fr",
  "français": "fr",
  // de
  "german": "de",
  "德语": "de",
  "德語": "de",
  "德文": "de",
  "德": "de",
  "ドイツ語": "de",
  "deutsch": "de",
  // es
  "spanish": "es",
  "castilian": "es",
  "西班牙语": "es",
  "西班牙語": "es",
  "西班牙文": "es",
  "西语": "es",
  "西語": "es",
  "スペイン語": "es",
  "español": "es",
  "castellano": "es",
  // ru
  "russian": "ru",
  "俄语": "ru",
  "俄語": "ru",
  "俄文": "ru",
  "俄": "ru",
  "ロシア語": "ru",
  "русский": "ru",
  // hi
  "hindi": "hi",
  "印地语": "hi",
  "印地語": "hi",
  "印度语": "hi",
  "印度語": "hi",
  "ヒンディー語": "hi",
  "ヒンディ語": "hi",
  "हिन्दी": "hi",
  "हिंदी": "hi",
  // bn
  "bengali": "bn",
  "bangla": "bn",
  "孟加拉语": "bn",
  "孟加拉語": "bn",
  "孟加拉文": "bn",
  "ベンガル語": "bn",
  "বাংলা": "bn",
  // ca
  "catalan": "ca",
  "加泰罗尼亚语": "ca",
  "加泰羅尼亞語": "ca",
  "加泰兰语": "ca",
  "加泰蘭語": "ca",
  "カタルーニャ語": "ca",
  "català": "ca",
  // nb
  "norwegian": "nb",
  "norwegian bokmål": "nb",
  "bokmål": "nb",
  "挪威语": "nb",
  "挪威語": "nb",
  "挪威文": "nb",
  "书面挪威语": "nb",
  "書面挪威語": "nb",
  "ノルウェー語": "nb",
  "ノルウェー語ブークモール": "nb",
  "norsk": "nb",
  // sc
  "sardinian": "sc",
  "撒丁语": "sc",
  "撒丁語": "sc",
  "萨丁语": "sc",
  "薩丁語": "sc",
  "サルデーニャ語": "sc",
  "sardu": "sc",
  // ta
  "tamil": "ta",
  "泰米尔语": "ta",
  "泰米爾語": "ta",
  "泰米尔文": "ta",
  "泰米爾文": "ta",
  "タミル語": "ta",
  "தமிழ்": "ta",
  // fa
  "persian": "fa",
  "farsi": "fa",
  "波斯语": "fa",
  "波斯語": "fa",
  "波斯文": "fa",
  "伊朗语": "fa",
  "伊朗語": "fa",
  "ペルシャ語": "fa",
  "ペルシア語": "fa",
  // bg
  "bulgarian": "bg",
  "保加利亚语": "bg",
  "保加利亞語": "bg",
  "保加利亚文": "bg",
  "保加利亞文": "bg",
  "ブルガリア語": "bg",
  "български": "bg",
  // vi
  "vietnamese": "vi",
  "越南语": "vi",
  "越南語": "vi",
  "越南文": "vi",
  "ベトナム語": "vi",
  "tiếng việt": "vi",
};

/// Maps a dictionary group name to a language code using exact names only.
/// Returns null for the default group, unknown names, and "auto".
String? languageCodeFromGroupName(String name) {
  final normalized = name.trim().toLowerCase();
  if (normalized.isEmpty || normalized == "auto") return null;

  for (final entry in languageMap.entries) {
    if (entry.key.toLowerCase() == normalized ||
        entry.value.trim().toLowerCase() == normalized) {
      return entry.key == "auto" ? null : entry.key;
    }
  }
  return _groupNameAliases[normalized];
}
