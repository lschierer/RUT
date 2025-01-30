export default class FrontMatterTags extends HTMLElement {
  connectedCallback() {
    if (this.innerText.length > 0) {
      if (this.innerText.localeCompare("${globalThis.page.data.tags}")) {
        const tags = JSON.parse(this.innerText);
        if (tags) {
          if (Array.isArray(tags)) {
            this.innerHTML = `
              <span class="tags">Tags: </span>
              <ul class="tags">
                ${tags
                  .map(
                    (tag) => `
                  <li>${tag}</li>
                `,
                  )
                  .join("\n")}
              </ul>
            `;
          } else {
            this.innerHTML = `<span class="tags">Tags: ${tags}</span>`;
          }
        }
      }
      this.innerText = "";
    }
  }
}
customElements.define("page-tags", FrontMatterTags);
