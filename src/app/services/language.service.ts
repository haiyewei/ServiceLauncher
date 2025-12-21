import { Injectable, inject } from "@angular/core";
import { TranslateService } from "@ngx-translate/core";

const SUPPORTED_LANGS = ["zh", "en", "ja", "ko"];
const STORAGE_KEY = "lang";

@Injectable({ providedIn: "root" })
export class LanguageService {
  private translate = inject(TranslateService);

  constructor() {
    this.translate.setDefaultLang("en");
    const savedLang = localStorage.getItem(STORAGE_KEY);

    if (savedLang && SUPPORTED_LANGS.includes(savedLang)) {
      // 使用已保存的语言
      this.translate.use(savedLang);
    } else {
      // 首次启动，检测用户语言
      const detectedLang = this.detectUserLanguage();
      this.translate.use(detectedLang);
      localStorage.setItem(STORAGE_KEY, detectedLang);
    }
  }

  /** 检测用户系统语言 */
  private detectUserLanguage(): string {
    const browserLang =
      navigator.language || (navigator as any).userLanguage || "";
    const langCode = browserLang.split("-")[0].toLowerCase();

    // 检查是否在支持的语言列表中
    if (SUPPORTED_LANGS.includes(langCode)) {
      return langCode;
    }

    // 特殊处理：zh-TW, zh-HK 等也归为 zh
    if (browserLang.toLowerCase().startsWith("zh")) {
      return "zh";
    }

    // 默认返回英语
    return "en";
  }

  setLanguage(lang: string) {
    this.translate.use(lang);
    localStorage.setItem(STORAGE_KEY, lang);
  }

  getCurrentLang() {
    return this.translate.currentLang || "en";
  }
}
