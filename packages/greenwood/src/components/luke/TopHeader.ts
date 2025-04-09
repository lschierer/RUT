import debugFunction from "../lib/debug.ts";
const DEBUG = debugFunction(new URL(import.meta.url).pathname);
if (DEBUG) {
  console.log(`DEBUG enabled for ${new URL(import.meta.url).pathname}`);
}
import "./ThemeSelector.ts";

import { TopLevelSections } from "../lib/topLevelSections.ts";
import "./SiteTitle.ts";
export default class TopHeader extends HTMLElement {
  connectedCallback() {
    this.innerHTML = `

      <div class="header">
          <site-title ></site-title>
        <div class="nav">
          ${TopLevelSections.options
            .sort()
            .map((section) => {
              return `
              <div class="navItem">
                <a
                  href=${"/" + section.replaceAll(" ", "") + "/"}
                  class="spectrum-Link spectrum-Link--primary"
                >
                  <span class="">${section.replaceAll("_", " ")}</span>
                </a>
              </div>
            `;
            })
            .join(" ")}
        </div>
        <div class=" right-group">
          <div class=" social-icons">
            <SocialIcons {...Astro.props} ></SocialIcons>
          </div>
          <theme-select></theme-select>
        </div>
      </div>
    `;
  }
}
customElements.define("top-header", TopHeader);
