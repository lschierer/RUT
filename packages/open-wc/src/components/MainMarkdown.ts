import { debugEnabled, logger } from "../lib/CentralDebugging.js";

const DEBUGFLAG = debugEnabled(new URL(import.meta.url).pathname);

export default class MainMarkdown extends HTMLElement {
  private _filename = "";
  private _text = "";
  protected getAttributes = () => {
    for (const attr of this.attributes) {
      if (!attr.name.toLowerCase().localeCompare("filename")) {
        this._filename = attr.value;
      }
    }
  };

  protected readMarkdownFile = () => {
    if (this._filename.length) {
      const fileUrl = new URL(this._filename, import.meta.url);
      if (DEBUGFLAG) {
        logger.debug(`fileUrl is ${fileUrl}`);
      }
      const data = "";
      if (typeof data === "string") {
        this._text = data;
      } else {
        if (DEBUGFLAG) {
          logger.debug(`data is ${typeof data}`);
        }
      }
    }
  };

  connectedCallback() {
    this.getAttributes();
    this.readMarkdownFile();
    return this._text;
  }
}
customElements.define("main-markdown", MainMarkdown);
