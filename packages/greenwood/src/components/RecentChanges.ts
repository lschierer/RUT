import commits from "../lib/commitHistory.ts";

export default class RecentChanges extends HTMLElement {
  connectedCallback() {
    if (commits && Array.isArray(commits) && commits.length > 0) {
      this.innerHTML = `
        <dl class="RecentChanges">
          ${commits
            .map(
              (commit) => `
            <dt>${commit.id}</dt>
            <dl>${commit.message.map((m) => m).join("<br/>\n")}</dl>

          `,
            )
            .join("\n")}
        </dl>
      `;
    }
  }
}
customElements.define("recent-changes", RecentChanges);
