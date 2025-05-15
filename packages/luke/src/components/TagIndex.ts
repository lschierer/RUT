import debugFunction from "../lib/debug";
const DEBUG = debugFunction("src/components/TagIndex");

import { DateTime } from "luxon";

export default class TagIndex extends HTMLElement {
  private _tagName: string = "";
  private _limit: number = 0;
  connectedCallback() {
    if (DEBUG) {
      console.log(`TagIndex connectedCallback start`);
    }
    const pages: object[] = new Array<object>();
    const pagesWithTag = new Array<object>();

    for (const attr of this.attributes) {
      if (!attr.name.toLowerCase().localeCompare("tagname")) {
        this._tagName = attr.value;

        if (this._tagName && this._tagName.length > 0) {
          if (DEBUG) {
            console.log(`found tagName ${this._tagName}`);
          }
          pages.forEach((page) => {
            if (
              "data" in page &&
              page.data &&
              "tags" in (page.data as object) &&
              "tags" in (page.data as object)
            ) {
              const tags = (page.data as object)[
                "tags" as keyof typeof page.data
              ] as string | Array<string>;
              if (
                (Array.isArray(tags) && tags.includes(this._tagName)) ||
                this._tagName === tags
              ) {
                pagesWithTag.push(page);
              }
            }
          });
        }
      }
      if (!attr.name.toLowerCase().localeCompare("limit")) {
        this._limit = +attr.value;
      }
    }

    if (pagesWithTag.length > 0) {
      pagesWithTag.sort((a, b) => {
        let ad: DateTime | null = null;
        let bd: DateTime | null = null;
        if ("data" in a && "date" in (a.data as object)) {
          ad = DateTime.fromJSDate(
            (a.data as object)["date" as keyof typeof a.data],
          );
        }
        if ("data" in b && "date" in (b.data as object)) {
          bd = DateTime.fromJSDate(
            (b.data as object)["date" as keyof typeof b.data],
          );
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
        }
        let at = "";
        let bt = "";

        if ("data" in a && "title" in (a.data as object)) {
          at = (a.data as object)["title" as keyof typeof a.data];
        } else {
          at = Object.values(a)[0] as string;
        }

        if ("data" in b && "title" in (b.data as object)) {
          bt = (b.data as object)["title" as keyof typeof b.data];
        } else {
          at = Object.values(a)[0] as string;
        }
        return at.localeCompare(bt);
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
                  <a href="${page["route" as keyof typeof page] as string}">${page["title" as keyof typeof page] as string}</a>
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
