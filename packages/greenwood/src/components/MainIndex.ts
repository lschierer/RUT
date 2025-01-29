import users from "../lib/users.ts";
export default class MainIndex extends HTMLElement {
  connectedCallback() {
    this.innerHTML = `
      <div>
        <h1>Schierer Home Pages</h1>
        <ul>
          ${users
            .map(
              (user) => `
                <li><a href="/${user}/">${user.slice(0, 1).toUpperCase()}${user.slice(1)}</a></li>
              `,
            )
            .join("\n")}
        </ul>
      </div>
    `;
  }
}
customElements.define("main-index", MainIndex);
