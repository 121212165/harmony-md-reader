/**
 * Highlighter.ets
 * 代码语法高亮器 —— 将代码文本 + 语言标识转换为带颜色标记的 token 序列。
 *
 * 颜色方案参考 One Dark 主题：
 *   - 注释   → #5C6370
 *   - 字符串 → #98C379
 *   - 数字   → #D19A66
 *   - 关键字 → #C678DD
 *   - 默认   → #ABB2BF
 *
 * 采用统一正则扫描 + 语言关键字查找表的架构，
 * HTML / CSS / JSON 因语法特殊性使用专用 tokenizer。
 */

// ============================================================
// 导出接口
// ============================================================

/** 单个高亮 token */
export interface HighlightToken {
  /** token 文本内容 */
  text: string;
  /** 颜色值，如 '#C678DD' */
  color: string;
}

// ============================================================
// 颜色常量（One Dark 主题）
// ============================================================

/** 注释颜色 */
const COLOR_COMMENT: string = '#5C6370';
/** 字符串颜色 */
const COLOR_STRING: string = '#98C379';
/** 数字颜色 */
const COLOR_NUMBER: string = '#D19A66';
/** 关键字颜色 */
const COLOR_KEYWORD: string = '#C678DD';
/** 默认文本颜色 */
const COLOR_DEFAULT: string = '#ABB2BF';
/** JSON 键名颜色 */
const COLOR_JSON_KEY: string = '#E06C75';

// ============================================================
// 语言关键字表
// ============================================================

/** JavaScript / TypeScript */
const JS_TS_KEYWORDS: Set<string> = new Set([
  'const', 'let', 'var', 'function', 'return', 'if', 'else',
  'for', 'while', 'class', 'import', 'export', 'from',
  'async', 'await', 'new', 'this', 'true', 'false',
  'null', 'undefined', 'switch', 'case', 'break', 'continue',
  'default', 'do', 'try', 'catch', 'finally', 'throw',
  'typeof', 'instanceof', 'in', 'of', 'yield', 'extends',
  'super', 'static', 'get', 'set', 'delete', 'void',
  // TypeScript 额外关键字
  'type', 'interface', 'enum', 'implements', 'abstract',
  'declare', 'module', 'namespace', 'readonly', 'as',
  'is', 'keyof', 'infer', 'never', 'unknown', 'any',
]);

/** ArkTS 装饰器与关键字 */
const ARKTS_KEYWORDS: Set<string> = new Set([
  '@Entry', '@Component', '@State', '@Prop', '@Link',
  '@Provide', '@Consume', '@Watch', '@Track', '@Builder',
  '@Styles', '@Extend', '@ObjectLink', '@Observed',
  'struct', 'build', 'aboutToAppear', 'aboutToDisappear',
  // 从 JS/TS 继承
  'const', 'let', 'var', 'function', 'return', 'if', 'else',
  'for', 'while', 'class', 'import', 'export', 'from',
  'async', 'await', 'new', 'this', 'true', 'false',
  'null', 'undefined', 'extends', 'implements', 'interface',
  'type', 'enum', 'abstract', 'static', 'void',
  'switch', 'case', 'break', 'continue', 'default',
  'try', 'catch', 'finally', 'throw',
]);

/** Python */
const PYTHON_KEYWORDS: Set<string> = new Set([
  'def', 'class', 'import', 'from', 'return', 'if', 'elif',
  'else', 'for', 'while', 'in', 'not', 'and', 'or',
  'True', 'False', 'None', 'self', 'print', 'with', 'as',
  'try', 'except', 'finally', 'raise', 'lambda', 'pass',
  'break', 'continue', 'yield', 'global', 'nonlocal',
  'assert', 'del', 'is', 'len', 'range', 'async', 'await',
]);

/** Java */
const JAVA_KEYWORDS: Set<string> = new Set([
  'public', 'private', 'protected', 'class', 'interface',
  'extends', 'implements', 'return', 'if', 'else', 'for',
  'while', 'new', 'this', 'static', 'void', 'int', 'String',
  'boolean', 'long', 'double', 'float', 'char', 'byte',
  'short', 'final', 'abstract', 'package', 'import',
  'try', 'catch', 'finally', 'throw', 'throws', 'super',
  'switch', 'case', 'break', 'continue', 'default',
  'null', 'true', 'false', 'instanceof', 'enum',
  'synchronized', 'volatile', 'transient', 'native',
]);

/** Go */
const GO_KEYWORDS: Set<string> = new Set([
  'func', 'package', 'import', 'var', 'const', 'type',
  'struct', 'interface', 'return', 'if', 'else', 'for',
  'range', 'defer', 'go', 'chan', 'map', 'switch', 'case',
  'break', 'continue', 'default', 'select', 'fallthrough',
  'goto', 'true', 'false', 'nil', 'iota',
  'string', 'int', 'bool', 'float64', 'float32',
  'error', 'make', 'len', 'append',
]);

/** Rust */
const RUST_KEYWORDS: Set<string> = new Set([
  'fn', 'let', 'mut', 'pub', 'struct', 'enum', 'impl',
  'trait', 'use', 'mod', 'return', 'if', 'else', 'for',
  'while', 'loop', 'match', 'self', 'Self', 'super',
  'crate', 'as', 'in', 'ref', 'true', 'false',
  'const', 'static', 'type', 'where', 'move', 'async',
  'await', 'unsafe', 'extern', 'dyn', 'Box', 'Vec',
  'String', 'Option', 'Result', 'Some', 'None', 'Ok', 'Err',
]);

/** Shell / Bash */
const SHELL_KEYWORDS: Set<string> = new Set([
  'if', 'then', 'else', 'elif', 'fi', 'for', 'while', 'do',
  'done', 'case', 'esac', 'function', 'return', 'in',
  'echo', 'exit', 'export', 'source', 'alias', 'unalias',
  'cd', 'pwd', 'ls', 'cat', 'grep', 'sed', 'awk', 'find',
  'chmod', 'chown', 'mkdir', 'rm', 'cp', 'mv', 'curl',
  'wget', 'tar', 'git', 'npm', 'pip', 'sudo',
  'true', 'false',
]);

/** CSS 常用属性名（作为关键字高亮） */
const CSS_KEYWORDS: Set<string> = new Set([
  // 布局
  'display', 'position', 'top', 'right', 'bottom', 'left',
  'float', 'clear', 'z-index', 'overflow', 'visibility',
  'flex', 'flex-direction', 'flex-wrap', 'justify-content',
  'align-items', 'align-self', 'align-content',
  'grid-template-columns', 'grid-template-rows', 'gap',
  // 盒模型
  'width', 'height', 'max-width', 'max-height',
  'min-width', 'min-height',
  'margin', 'margin-top', 'margin-right', 'margin-bottom', 'margin-left',
  'padding', 'padding-top', 'padding-right', 'padding-bottom', 'padding-left',
  'border', 'border-radius', 'border-color', 'border-style', 'border-width',
  'box-sizing', 'box-shadow', 'outline',
  // 文本
  'font-size', 'font-weight', 'font-family', 'font-style',
  'line-height', 'text-align', 'text-decoration', 'text-transform',
  'color', 'letter-spacing', 'word-spacing', 'white-space',
  // 背景
  'background', 'background-color', 'background-image',
  'background-size', 'background-position', 'background-repeat',
  // 其他
  'opacity', 'transition', 'transform', 'animation',
  'cursor', 'content', 'pointer-events',
  'object-fit', 'resize', 'filter', 'backdrop-filter',
  // 常用值关键字
  'none', 'auto', 'inherit', 'initial', 'unset',
  'block', 'inline', 'inline-block', 'flex', 'grid',
  'absolute', 'relative', 'fixed', 'sticky', 'static',
  'center', 'normal', 'bold', 'italic',
  'solid', 'dashed', 'dotted', 'transparent',
  'important',
]);

// ============================================================
// 辅助函数
// ============================================================

/** 创建 token */
function makeToken(text: string, color: string): HighlightToken {
  const t: HighlightToken = { text: text, color: color };
  return t;
}

/** 合并相邻同色 token，减少渲染节点数 */
function mergeTokens(tokens: HighlightToken[]): HighlightToken[] {
  if (tokens.length === 0) {
    return tokens;
  }
  const merged: HighlightToken[] = [];
  let current: HighlightToken = { text: tokens[0].text, color: tokens[0].color };

  for (let i = 1; i < tokens.length; i++) {
    if (tokens[i].color === current.color) {
      current.text += tokens[i].text;
    } else {
      if (current.text.length > 0) {
        merged.push(current);
      }
      current = { text: tokens[i].text, color: tokens[i].color };
    }
  }

  if (current.text.length > 0) {
    merged.push(current);
  }
  return merged;
}

/** 判断字符是否为标识符字符（字母、数字、下划线、$、@） */
function isIdentChar(c: string): boolean {
  return /[a-zA-Z0-9_$@]/.test(c);
}

// ============================================================
// 高亮器主类
// ============================================================

/**
 * 代码语法高亮器
 *
 * 将代码字符串按行拆分为 HighlightToken 序列。
 * 支持 JavaScript/TypeScript、ArkTS、Python、Java、Go、Rust、
 * CSS、HTML、JSON、Shell 等语言。
 */
export class Highlighter {

  /** 块注释是否延续到下一行 */
  private blockCommentActive: boolean = false;

  /** 反引号字符串是否延续到下一行 */
  private backtickActive: boolean = false;

  /**
   * 主方法：对代码进行语法高亮。
   *
   * @param code     - 代码文本
   * @param language - 语言标识（如 'javascript'、'python'）
   * @returns 二维数组：外层 = 行，内层 = 该行的 token 序列
   */
  highlight(code: string, language: string): HighlightToken[][] {
    if (!code || code.length === 0) {
      return [];
    }

    const lang: string = language.toLowerCase().trim();
    const keywords: Set<string> = this.getKeywords(lang);

    // 重置跨行状态
    this.blockCommentActive = false;
    this.backtickActive = false;

    const lines: string[] = code.split('\n');
    const result: HighlightToken[][] = [];

    for (let i = 0; i < lines.length; i++) {
      let tokens: HighlightToken[];

      if (lang === 'html' || lang === 'xml') {
        tokens = this.tokenizeHtml(lines[i]);
      } else if (lang === 'css' || lang === 'scss' || lang === 'less') {
        tokens = this.tokenizeCss(lines[i]);
      } else if (lang === 'json') {
        tokens = this.tokenizeJson(lines[i]);
      } else {
        tokens = this.tokenizeGeneric(lines[i], keywords);
      }

      result.push(mergeTokens(tokens));
    }

    return result;
  }

  // ==========================================================
  // 关键字表查找
  // ==========================================================

  /**
   * 根据语言标识获取关键字集合。
   * 未识别的语言返回空集合（不做高亮）。
   */
  private getKeywords(lang: string): Set<string> {
    switch (lang) {
      case 'javascript':
      case 'js':
      case 'typescript':
      case 'ts':
      case 'jsx':
      case 'tsx':
        return JS_TS_KEYWORDS;

      case 'arkts':
        return ARKTS_KEYWORDS;

      case 'python':
      case 'py':
        return PYTHON_KEYWORDS;

      case 'java':
      case 'kotlin':
        return JAVA_KEYWORDS;

      case 'go':
      case 'golang':
        return GO_KEYWORDS;

      case 'rust':
      case 'rs':
        return RUST_KEYWORDS;

      case 'shell':
      case 'bash':
      case 'sh':
      case 'zsh':
        return SHELL_KEYWORDS;

      case 'c':
      case 'cpp':
      case 'c++':
      case 'csharp':
      case 'c#':
        // C 系列复用 Java 关键字（高度重合）
        return JAVA_KEYWORDS;

      default:
        return new Set<string>();
    }
  }

  // ==========================================================
  // 通用 tokenizer（适用于大部分 C-like 语言）
  // ==========================================================

  /**
   * 通用逐行 tokenizer。
   *
   * 处理优先级：
   *   1. 块注释（跨行 /* ... *&#47;）
   *   2. 行注释（//）
   *   3. 反引号字符串（跨行 `...`）
   *   4. 单/双引号字符串
   *   5. 数字
   *   6. 标识符（查关键字表）
   *   7. 其他字符
   *
   * @param line     - 当前行文本
   * @param keywords - 语言关键字集合（空集合 = 不做关键字高亮）
   * @returns 当前行的 token 数组
   */
  private tokenizeGeneric(line: string, keywords: Set<string>): HighlightToken[] {
    const tokens: HighlightToken[] = [];
    const len: number = line.length;
    let pos: number = 0;

    // 如果上一行有未关闭的块注释，继续消费
    if (this.blockCommentActive) {
      const endIdx: number = line.indexOf('*/');
      if (endIdx >= 0) {
        tokens.push(makeToken(line.substring(0, endIdx + 2), COLOR_COMMENT));
        pos = endIdx + 2;
        this.blockCommentActive = false;
      } else {
        tokens.push(makeToken(line, COLOR_COMMENT));
        return tokens;
      }
    }

    // 如果上一行有未关闭的反引号字符串，继续消费
    if (this.backtickActive) {
      let bp: number = pos;
      while (bp < len) {
        if (line[bp] === '\\' && bp + 1 < len) {
          bp += 2;
          continue;
        }
        if (line[bp] === '`') {
          tokens.push(makeToken(line.substring(pos, bp + 1), COLOR_STRING));
          pos = bp + 1;
          this.backtickActive = false;
          break;
        }
        bp++;
      }
      if (this.backtickActive) {
        tokens.push(makeToken(line.substring(pos), COLOR_STRING));
        return tokens;
      }
    }

    // 主扫描循环
    while (pos < len) {
      const ch: string = line[pos];

      // ---- 行注释 // ----
      if (ch === '/' && pos + 1 < len && line[pos + 1] === '/') {
        tokens.push(makeToken(line.substring(pos), COLOR_COMMENT));
        pos = len;
        continue;
      }

      // ---- 块注释起始 /* ----
      if (ch === '/' && pos + 1 < len && line[pos + 1] === '*') {
        const endIdx: number = line.indexOf('*/', pos + 2);
        if (endIdx >= 0) {
          tokens.push(makeToken(line.substring(pos, endIdx + 2), COLOR_COMMENT));
          pos = endIdx + 2;
        } else {
          tokens.push(makeToken(line.substring(pos), COLOR_COMMENT));
          this.blockCommentActive = true;
          pos = len;
        }
        continue;
      }

      // ---- Shell/Python 行注释 # ----
      if (ch === '#' && this.isHashCommentLang(keywords)) {
        tokens.push(makeToken(line.substring(pos), COLOR_COMMENT));
        pos = len;
        continue;
      }

      // ---- 双引号字符串 ----
      if (ch === '"') {
        let sp: number = pos + 1;
        while (sp < len) {
          if (line[sp] === '\\' && sp + 1 < len) {
            sp += 2;
            continue;
          }
          if (line[sp] === '"') {
            sp++;
            break;
          }
          sp++;
        }
        tokens.push(makeToken(line.substring(pos, sp), COLOR_STRING));
        pos = sp;
        continue;
      }

      // ---- 单引号字符串 ----
      if (ch === '\'') {
        let sp: number = pos + 1;
        while (sp < len) {
          if (line[sp] === '\\' && sp + 1 < len) {
            sp += 2;
            continue;
          }
          if (line[sp] === '\'') {
            sp++;
            break;
          }
          sp++;
        }
        tokens.push(makeToken(line.substring(pos, sp), COLOR_STRING));
        pos = sp;
        continue;
      }

      // ---- 反引号字符串（可跨行）----
      if (ch === '`') {
        let sp: number = pos + 1;
        let closed: boolean = false;
        while (sp < len) {
          if (line[sp] === '\\' && sp + 1 < len) {
            sp += 2;
            continue;
          }
          if (line[sp] === '`') {
            sp++;
            closed = true;
            break;
          }
          sp++;
        }
        if (closed) {
          tokens.push(makeToken(line.substring(pos, sp), COLOR_STRING));
          pos = sp;
        } else {
          tokens.push(makeToken(line.substring(pos), COLOR_STRING));
          this.backtickActive = true;
          pos = len;
        }
        continue;
      }

      // ---- 数字 ----
      if (this.isDigit(ch) || (ch === '.' && pos + 1 < len && this.isDigit(line[pos + 1]))) {
        let np: number = pos;
        // 十六进制 0x / 八进制 0o / 二进制 0b
        if (ch === '0' && np + 1 < len) {
          const prefix: string = line[np + 1].toLowerCase();
          if (prefix === 'x' || prefix === 'o' || prefix === 'b') {
            np += 2;
            while (np < len && /[0-9a-fA-F_]/.test(line[np])) {
              np++;
            }
            tokens.push(makeToken(line.substring(pos, np), COLOR_NUMBER));
            pos = np;
            continue;
          }
        }
        // 整数部分
        while (np < len && (this.isDigit(line[np]) || line[np] === '_')) {
          np++;
        }
        // 小数部分
        if (np < len && line[np] === '.' && np + 1 < len && this.isDigit(line[np + 1])) {
          np++;
          while (np < len && (this.isDigit(line[np]) || line[np] === '_')) {
            np++;
          }
        }
        // 指数部分
        if (np < len && (line[np] === 'e' || line[np] === 'E')) {
          np++;
          if (np < len && (line[np] === '+' || line[np] === '-')) {
            np++;
          }
          while (np < len && this.isDigit(line[np])) {
            np++;
          }
        }
        // 后缀（n, f, L 等）
        if (np < len && /[nfFlLuU]/.test(line[np])) {
          np++;
        }
        tokens.push(makeToken(line.substring(pos, np), COLOR_NUMBER));
        pos = np;
        continue;
      }

      // ---- 标识符 / 关键字 ----
      if (this.isIdentStart(ch)) {
        let wp: number = pos;
        while (wp < len && isIdentChar(line[wp])) {
          wp++;
        }
        const word: string = line.substring(pos, wp);
        if (keywords.has(word)) {
          tokens.push(makeToken(word, COLOR_KEYWORD));
        } else {
          tokens.push(makeToken(word, COLOR_DEFAULT));
        }
        pos = wp;
        continue;
      }

      // ---- 其他字符（运算符、标点、空白）----
      tokens.push(makeToken(ch, COLOR_DEFAULT));
      pos++;
    }

    return tokens;
  }

  /**
   * 判断当前语言是否使用 # 作为行注释。
   * Python、Shell、Ruby 等使用 # 注释。
   */
  private isHashCommentLang(keywords: Set<string>): boolean {
    // 通过检查关键字集合中是否包含 Python/Shell 特征关键字来判断
    return keywords.has('elif') || keywords.has('self') ||
           keywords.has('fi') || keywords.has('esac') ||
           keywords.has('echo');
  }

  // ==========================================================
  // HTML 专用 tokenizer
  // ==========================================================

  /**
   * HTML 逐行 tokenizer。
   *
   * 识别：
   *   - 注释 <!-- ... -->
   *   - 标签名（<div>, </span> 等）
   *   - 属性值（引号内字符串）
   *   - 普通文本
   */
  private tokenizeHtml(line: string): HighlightToken[] {
    const tokens: HighlightToken[] = [];
    const len: number = line.length;
    let pos: number = 0;

    while (pos < len) {
      // ---- HTML 注释 <!-- --> ----
      if (line.substring(pos, pos + 4) === '<!--') {
        const endIdx: number = line.indexOf('-->', pos + 4);
        if (endIdx >= 0) {
          tokens.push(makeToken(line.substring(pos, endIdx + 3), COLOR_COMMENT));
          pos = endIdx + 3;
        } else {
          tokens.push(makeToken(line.substring(pos), COLOR_COMMENT));
          pos = len;
        }
        continue;
      }

      // ---- 标签开始 < 或 </ ----
      if (line[pos] === '<' && pos + 1 < len &&
          (this.isLetter(line[pos + 1]) || line[pos + 1] === '/')) {
        // 开始标签 '<' 或 '</'
        let tp: number = pos;
        if (line[pos + 1] === '/') {
          tp = pos + 2;
          tokens.push(makeToken('</', COLOR_DEFAULT));
        } else {
          tp = pos + 1;
          tokens.push(makeToken('<', COLOR_DEFAULT));
        }

        // 标签名
        const nameStart: number = tp;
        while (tp < len && (this.isLetterOrDigit(line[tp]) || line[tp] === '-')) {
          tp++;
        }
        if (tp > nameStart) {
          tokens.push(makeToken(line.substring(nameStart, tp), COLOR_KEYWORD));
        }

        // 属性和空白
        while (tp < len && line[tp] !== '>') {
          if (this.isWhitespace(line[tp])) {
            let wsEnd: number = tp;
            while (wsEnd < len && this.isWhitespace(line[wsEnd])) {
              wsEnd++;
            }
            tokens.push(makeToken(line.substring(tp, wsEnd), COLOR_DEFAULT));
            tp = wsEnd;
            continue;
          }

          // 带引号的属性值
          if (line[tp] === '"' || line[tp] === '\'') {
            const quote: string = line[tp];
            let qe: number = tp + 1;
            while (qe < len && line[qe] !== quote) {
              qe++;
            }
            if (qe < len) {
              qe++;
            }
            tokens.push(makeToken(line.substring(tp, qe), COLOR_STRING));
            tp = qe;
            continue;
          }

          // = 号
          if (line[tp] === '=') {
            tokens.push(makeToken('=', COLOR_DEFAULT));
            tp++;
            continue;
          }

          // 属性名或其他字符
          let ae: number = tp;
          while (ae < len && line[ae] !== '>' && line[ae] !== '=' &&
                 !this.isWhitespace(line[ae]) && line[ae] !== '"' && line[ae] !== '\'') {
            ae++;
          }
          if (ae > tp) {
            tokens.push(makeToken(line.substring(tp, ae), COLOR_DEFAULT));
            tp = ae;
          } else {
            tokens.push(makeToken(line[tp], COLOR_DEFAULT));
            tp++;
          }
        }

        // 标签结束 '>' 或 '/>'
        if (tp < len && line[tp] === '>') {
          tokens.push(makeToken('>', COLOR_DEFAULT));
          tp++;
        } else if (tp + 1 < len && line[tp] === '/' && line[tp + 1] === '>') {
          tokens.push(makeToken('/>', COLOR_DEFAULT));
          tp += 2;
        }
        pos = tp;
        continue;
      }

      // ---- 普通文本 ----
      let te: number = pos + 1;
      while (te < len && line[te] !== '<') {
        te++;
      }
      tokens.push(makeToken(line.substring(pos, te), COLOR_DEFAULT));
      pos = te;
    }

    return mergeTokens(tokens);
  }

  // ==========================================================
  // CSS 专用 tokenizer
  // ==========================================================

  /**
   * CSS 逐行 tokenizer。
   *
   * 识别：
   *   - 注释 /* ... *&#47;
   *   - 字符串（引号内）
   *   - 数字（含单位）
   *   - 已知 CSS 属性名 / 值关键字
   *   - 选择器、括号等其他内容
   */
  private tokenizeCss(line: string): HighlightToken[] {
    const tokens: HighlightToken[] = [];
    const len: number = line.length;
    let pos: number = 0;

    // 处理跨行块注释
    if (this.blockCommentActive) {
      const endIdx: number = line.indexOf('*/');
      if (endIdx >= 0) {
        tokens.push(makeToken(line.substring(0, endIdx + 2), COLOR_COMMENT));
        pos = endIdx + 2;
        this.blockCommentActive = false;
      } else {
        tokens.push(makeToken(line, COLOR_COMMENT));
        return tokens;
      }
    }

    while (pos < len) {
      const ch: string = line[pos];

      // ---- 块注释 ----
      if (ch === '/' && pos + 1 < len && line[pos + 1] === '*') {
        const endIdx: number = line.indexOf('*/', pos + 2);
        if (endIdx >= 0) {
          tokens.push(makeToken(line.substring(pos, endIdx + 2), COLOR_COMMENT));
          pos = endIdx + 2;
        } else {
          tokens.push(makeToken(line.substring(pos), COLOR_COMMENT));
          this.blockCommentActive = true;
          pos = len;
        }
        continue;
      }

      // ---- 字符串 ----
      if (ch === '"' || ch === '\'') {
        const quote: string = ch;
        let se: number = pos + 1;
        while (se < len) {
          if (line[se] === '\\' && se + 1 < len) {
            se += 2;
            continue;
          }
          if (line[se] === quote) {
            se++;
            break;
          }
          se++;
        }
        tokens.push(makeToken(line.substring(pos, se), COLOR_STRING));
        pos = se;
        continue;
      }

      // ---- 数字（含 CSS 单位如 px, em, %, rem 等）----
      if (this.isDigit(ch) || (ch === '.' && pos + 1 < len && this.isDigit(line[pos + 1]))) {
        let np: number = pos;
        while (np < len && (this.isDigit(line[np]) || line[np] === '.')) {
          np++;
        }
        // CSS 单位
        while (np < len && /[a-zA-Z%]/.test(line[np])) {
          np++;
        }
        tokens.push(makeToken(line.substring(pos, np), COLOR_NUMBER));
        pos = np;
        continue;
      }

      // ---- 标识符（CSS 属性名 / 值关键字）----
      if (this.isLetter(ch) || ch === '-') {
        let wp: number = pos;
        while (wp < len && (this.isLetterOrDigit(line[wp]) || line[wp] === '-')) {
          wp++;
        }
        const word: string = line.substring(pos, wp);
        if (CSS_KEYWORDS.has(word)) {
          tokens.push(makeToken(word, COLOR_KEYWORD));
        } else {
          tokens.push(makeToken(word, COLOR_DEFAULT));
        }
        pos = wp;
        continue;
      }

      // ---- 其他 ----
      tokens.push(makeToken(ch, COLOR_DEFAULT));
      pos++;
    }

    return mergeTokens(tokens);
  }

  // ==========================================================
  // JSON 专用 tokenizer
  // ==========================================================

  /**
   * JSON 逐行 tokenizer。
   *
   * 识别：
   *   - 对象键（字符串后紧跟冒号）→ #E06C75
   *   - 普通字符串 → #98C379
   *   - 数字 → #D19A66
   *   - true / false / null → #C678DD
   */
  private tokenizeJson(line: string): HighlightToken[] {
    const tokens: HighlightToken[] = [];
    const len: number = line.length;
    let pos: number = 0;

    while (pos < len) {
      const ch: string = line[pos];

      // ---- 字符串 ----
      if (ch === '"') {
        let se: number = pos + 1;
        while (se < len) {
          if (line[se] === '\\' && se + 1 < len) {
            se += 2;
            continue;
          }
          if (line[se] === '"') {
            se++;
            break;
          }
          se++;
        }
        const str: string = line.substring(pos, se);

        // 向后查找冒号以判断是否为键名
        let afterPos: number = se;
        while (afterPos < len && this.isWhitespace(line[afterPos])) {
          afterPos++;
        }
        if (afterPos < len && line[afterPos] === ':') {
          // 这是一个 JSON 键
          tokens.push(makeToken(str, COLOR_JSON_KEY));
        } else {
          tokens.push(makeToken(str, COLOR_STRING));
        }
        pos = se;
        continue;
      }

      // ---- 数字 ----
      if (this.isDigit(ch) || ch === '-' || (ch === '.' && pos + 1 < len && this.isDigit(line[pos + 1]))) {
        let np: number = pos;
        if (line[np] === '-') {
          np++;
        }
        while (np < len && this.isDigit(line[np])) {
          np++;
        }
        if (np < len && line[np] === '.') {
          np++;
          while (np < len && this.isDigit(line[np])) {
            np++;
          }
        }
        if (np < len && (line[np] === 'e' || line[np] === 'E')) {
          np++;
          if (np < len && (line[np] === '+' || line[np] === '-')) {
            np++;
          }
          while (np < len && this.isDigit(line[np])) {
            np++;
          }
        }
        if (np > pos) {
          tokens.push(makeToken(line.substring(pos, np), COLOR_NUMBER));
          pos = np;
        } else {
          tokens.push(makeToken(ch, COLOR_DEFAULT));
          pos++;
        }
        continue;
      }

      // ---- 标识符（true / false / null）----
      if (this.isLetter(ch)) {
        let wp: number = pos;
        while (wp < len && this.isLetter(line[wp])) {
          wp++;
        }
        const word: string = line.substring(pos, wp);
        if (word === 'true' || word === 'false' || word === 'null') {
          tokens.push(makeToken(word, COLOR_KEYWORD));
        } else {
          tokens.push(makeToken(word, COLOR_DEFAULT));
        }
        pos = wp;
        continue;
      }

      // ---- 其他（括号、逗号、冒号等）----
      tokens.push(makeToken(ch, COLOR_DEFAULT));
      pos++;
    }

    return mergeTokens(tokens);
  }

  // ==========================================================
  // 字符判断辅助方法
  // ==========================================================

  private isDigit(c: string): boolean {
    return c >= '0' && c <= '9';
  }

  private isLetter(c: string): boolean {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c === '_';
  }

  private isLetterOrDigit(c: string): boolean {
    return this.isLetter(c) || this.isDigit(c);
  }

  private isIdentStart(c: string): boolean {
    return this.isLetter(c) || c === '@' || c === '$';
  }

  private isWhitespace(c: string): boolean {
    return c === ' ' || c === '\t' || c === '\r' || c === '\n';
  }
}
