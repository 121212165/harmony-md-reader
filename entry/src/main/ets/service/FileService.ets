/**
 * FileService.ets
 * 文件读取服务 —— 负责从 URI 读取文件内容、检测文件类型、组装文件元信息。
 *
 * 依赖：
 *   - @ohos.file.fs (HarmonyOS 文件系统 API)
 *   - @ohos.util (TextEncoder / TextDecoder)
 *   - ../parser/ASTNode (FileInfo, HtmlMeta 类型定义)
 */

import fs from '@ohos.file.fs';
import util from '@ohos.util';
import { FileInfo } from '../parser/ASTNode';

/** Markdown 文件扩展名集合 */
const MARKDOWN_EXTENSIONS: Set<string> = new Set(['.md', '.markdown']);

/** HTML 文件扩展名集合 */
const HTML_EXTENSIONS: Set<string> = new Set(['.html', '.htm']);

/** 默认阅读速度：字/分钟 */
const READING_SPEED_WPM: number = 300;

/** 文件大小单位阈值 */
const KB_THRESHOLD: number = 1024;
const MB_THRESHOLD: number = 1024 * 1024;

/**
 * 文件读取服务
 *
 * 提供文件类型检测、字数统计、阅读时间估算、文件大小格式化等能力。
 * 实际文件 I/O 通过 HarmonyOS @ohos.file.fs 完成。
 */
export class FileService {

  /**
   * 根据文件名扩展名判断文件类型。
   *
   * @param fileName - 文件名（如 "readme.md"）
   * @returns 'markdown' | 'html' | 'unknown'
   */
  detectFileType(fileName: string): 'markdown' | 'html' | 'unknown' {
    const dotIndex: number = fileName.lastIndexOf('.');
    if (dotIndex === -1) {
      return 'unknown';
    }
    const ext: string = fileName.substring(dotIndex).toLowerCase();
    if (MARKDOWN_EXTENSIONS.has(ext)) {
      return 'markdown';
    }
    if (HTML_EXTENSIONS.has(ext)) {
      return 'html';
    }
    return 'unknown';
  }

  /**
   * 统计文本字数。
   *
   * 规则：
   *   - 每个 CJK（中日韩）字符算 1 个字
   *   - 连续英文字母/数字视为一个单词，算 1 个字
   *   - 纯空白和标点不计入
   *
   * @param text - 待统计的文本
   * @returns 字数
   */
  calculateWordCount(text: string): number {
    if (!text || text.length === 0) {
      return 0;
    }

    let count: number = 0;

    // 统计 CJK 字符数（Unicode 基本 CJK 区 + 扩展 A）
    const cjkPattern: RegExp = /[\u4e00-\u9fff\u3400-\u4dbf\uf900-\ufaff]/g;
    const cjkMatches: RegExpMatchArray | null = text.match(cjkPattern);
    if (cjkMatches) {
      count += cjkMatches.length;
    }

    // 统计英文单词数（连续字母/数字为一个单词）
    const wordPattern: RegExp = /[a-zA-Z0-9]+/g;
    const wordMatches: RegExpMatchArray | null = text.match(wordPattern);
    if (wordMatches) {
      count += wordMatches.length;
    }

    return count;
  }

  /**
   * 根据字数估算阅读时间（分钟）。
   *
   * 按 300 字/分钟计算，最少返回 1 分钟。
   *
   * @param wordCount - 字数
   * @returns 预计阅读分钟数
   */
  calculateReadingTime(wordCount: number): number {
    if (wordCount <= 0) {
      return 1;
    }
    return Math.max(1, Math.ceil(wordCount / READING_SPEED_WPM));
  }

  /**
   * 组装完整的文件信息对象。
   *
   * @param fileName - 文件名
   * @param content  - 文件文本内容
   * @param source   - 文件来源（如 URI 或路径）
   * @returns FileInfo 对象
   */
  buildFileInfo(fileName: string, content: string, source: string): FileInfo {
    const fileType: 'markdown' | 'html' | 'unknown' = this.detectFileType(fileName);
    const wordCount: number = this.calculateWordCount(content);
    const readingTime: number = this.calculateReadingTime(wordCount);
    // 使用 util.TextEncoder 计算 UTF-8 字节长度
    const encoder: util.TextEncoder = new util.TextEncoder();
    const encoded: Uint8Array = encoder.encodeInto(content);
    const fileSize: number = encoded.byteLength;

    const info: FileInfo = {
      fileName: fileName,
      fileType: fileType,
      fileSize: fileSize,
      wordCount: wordCount,
      readingTime: readingTime,
      source: source,
    };

    return info;
  }

  /**
   * 从 URI 路径中提取文件名。
   *
   * 支持以下格式：
   *   - file:///data/storage/readme.md  → readme.md
   *   - /data/storage/readme.md          → readme.md
   *   - readme.md                        → readme.md
   *
   * @param uri - 文件 URI 或路径
   * @returns 文件名
   */
  extractFileName(uri: string): string {
    if (!uri || uri.length === 0) {
      return '';
    }
    // 取最后一个 '/' 之后的部分
    const lastSlash: number = uri.lastIndexOf('/');
    if (lastSlash === -1) {
      return uri;
    }
    return uri.substring(lastSlash + 1);
  }

  /**
   * 格式化文件大小为人类可读字符串。
   *
   * @param bytes - 字节数
   * @returns 格式化后的字符串，如 "1.5 MB"
   */
  formatFileSize(bytes: number): string {
    if (bytes < 0) {
      return '0 B';
    }
    if (bytes < KB_THRESHOLD) {
      return `${bytes} B`;
    }
    if (bytes < MB_THRESHOLD) {
      const kb: number = bytes / KB_THRESHOLD;
      return `${kb.toFixed(1)} KB`;
    }
    const mb: number = bytes / MB_THRESHOLD;
    return `${mb.toFixed(1)} MB`;
  }

  /**
   * 读取指定 URI 的文件内容（异步）。
   *
   * 使用 HarmonyOS @ohos.file.fs 模块。
   * 注意：实际调用时需要传入有效的文件 URI（如 file://...）。
   *
   * @param uri - 文件的 URI 字符串
   * @returns 文件文本内容；读取失败时返回空字符串
   */
  async readFile(uri: string): Promise<string> {
    try {
      // 获取文件大小
      const stat: fs.Stat = fs.statSync(uri);
      const size: number = stat.size;

      if (size === 0) {
        return '';
      }

      // 打开文件获取 fd
      const file: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const fd: number = file.fd;

      // 分配缓冲区并读取
      const buf: ArrayBuffer = new ArrayBuffer(size);
      fs.readSync(fd, buf);
      fs.closeSync(fd);

      // 将 ArrayBuffer 解码为 UTF-8 字符串
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      const uint8Array: Uint8Array = new Uint8Array(buf);
      const result: string = decoder.decodeWithStream(uint8Array);
      return result;
    } catch (err) {
      console.error(`[FileService] Failed to read file: ${uri}`, JSON.stringify(err));
      return '';
    }
  }
}
