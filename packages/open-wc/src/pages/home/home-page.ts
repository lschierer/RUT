import { LitElement, html, css } from "lit";
import { customElement } from "lit/decorators.js";

@customElement("home-page")
export class HomePage extends LitElement {
  static styles = css`
    :host {
      display: block;
      padding: 25px;
    }
  `;

  render() {
    return html`
      <h1>Home Page</h1>
      <p>Welcome to the home page!</p>
      <nav>
        <a href="/">Home</a>
        <a href="/about/">About</a>
      </nav>
    `;
  }
}
