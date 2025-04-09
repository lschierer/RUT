import tagNames from "../lib/tags.ts";

import "./TagIndex.ts";

export default class SideBar extends HTMLElement {
  connectedCallback() {
    tagNames.sort((a, b) => {
      const av = Object.values(a)[0];
      const bv = Object.values(b)[0];
      if (av == bv) {
        return 0;
      } else if (av < bv) {
        return 1;
      } else {
        return -1;
      }
    });
    this.innerHTML = `
      <div class="SideBar">
        <div class="TagMapContainer">
          ${tagNames
            .map((tagObject) => {
              const k = Object.keys(tagObject)[0];
              return `
              <tag-index tagName="${k}" limit="10"></tag-index>
            `;
            })
            .join("\n")}
        </div>
      </div>
    `;
  }
}
customElements.define("side-bar", SideBar);
