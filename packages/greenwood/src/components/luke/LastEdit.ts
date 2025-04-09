export default class LastEdit extends HTMLElement {
  private _date: string = "";

  connectedCallback() {
    if (this.innerText.length > 0) {
      if (this.innerText.localeCompare("${globalThis.page.data.date}")) {
        if (this.innerText[0] == '"') {
          this._date = this.innerText.slice(1, -1);
        } else {
          this._date = this.innerText;
        }
        console.log(`date now ${this._date}`);
      }
    }
    this.innerText = "";
    if (this._date.length > 0) {
      this.innerHTML = `
        <span>Last Edit: ${this._date}</span>
      `;
    } else {
      this.innerHTML = `
        <!-- no date available -->
      `;
    }
  }
}
customElements.define("last-edit", LastEdit);
