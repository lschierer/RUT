// frontend/src/components/MathRunner.ts
export default class MathRunner extends HTMLElement {
  connectedCallback() {
    const btn = document.createElement("button");
    btn.textContent = "Run Math";

    btn.onclick = async () => {
      const res = await fetch("http://localhost:3000/math", {
        method: "POST",
        body: JSON.stringify({ values: [1, 2, 3, 4] }),
        headers: { "Content-Type": "application/json" },
      });

      const data = await res.json();
      alert(`Result: ${data.result}`);
    };

    this.appendChild(btn);
  }
}

customElements.define("math-runner", MathRunner);
