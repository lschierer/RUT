import { getContent } from "@greenwood/cli/src/data/client.js";

import { Page, sortPages } from "../lib/greenwoodPages.ts";

import debugFunction from "../lib/debug.ts";
const DEBUG = debugFunction("src/components/TagIndex.ts");

import { DateTime } from "luxon";

export default class TagIndex extends HTMLElement {
  private _tagName: string = "";
  private _limit: number = 0;
  async connectedCallback() {
    if (DEBUG) {
      console.log(`TagIndex connectedCallback start`);
    }
    const pages: Page[] = await getContent();
    const pagesWithTag = new Array<Page>();

    for (const attr of this.attributes) {
      if (!attr.name.toLowerCase().localeCompare("tagname")) {
        this._tagName = attr.value;

        if (this._tagName && this._tagName.length > 0) {
          if (DEBUG) {
            console.log(`found tagName ${this._tagName}`);
          }
          pages.forEach((page) => {
            if (
              page.data &&
              page.data.tags &&
              page.data.tags.includes(this._tagName)
            ) {
              pagesWithTag.push(page);
            }
          });
        }
      }
      if (!attr.name.toLowerCase().localeCompare("limit")) {
        this._limit = +(attr.value ?? 0);
      }
    }

    if (pagesWithTag.length > 0) {
      pagesWithTag.sort((a, b) => {
        let ad: DateTime | null = null;
        let bd: DateTime | null = null;
        if (a.data?.date) {
          ad = DateTime.fromJSDate(a.data.date);
        }
        if (b.data?.date) {
          bd = DateTime.fromJSDate(b.data.date);
        }
        if (ad) {
          if (bd) {
            if (ad.startOf("day") == bd.startOf("day")) {
              return 0;
            } else if (ad.startOf("day") < bd.startOf("day")) {
              return 1;
            } else {
              return -1;
            }
          } else {
            return -1;
          }
        } else if (bd) {
          return 1;
        } else return sortPages(a, b);
      });
      const display = this._limit
        ? pagesWithTag.slice(0, this._limit)
        : pagesWithTag;
      this.innerHTML = `
        <div class="tagMap ${this._tagName}">
          <h4 class="tagMap">${this._tagName}</h4>
          <ul class="tagMap">
            ${display
              .map((page) => {
                return `
                <li>
                  <a href="${page.route}">${page.title ? page.title : page.label}</a>
                </li>
              `;
              })
              .join("\n")}
          </ul>
        </div>
      `;
    } else {
    }
  }
}
customElements.define("tag-index", TagIndex);
