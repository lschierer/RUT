import { type Compilation, type Route, Page } from "../lib/greenwoodPages.ts";

export default class Test extends HTMLElement {
  constructor(request: Request, compilation) {
    super();
    console.log(JSON.stringify(compilation));
  }

  connectedCallback() {
    this.innerHTML = `
      <span>Test Page</span>
    `;
  }
}

async function getFrontmatter(
  compilation: Compilation,
  route: Route,
  label: string,
  id: string,
) {
  const page: Page | undefined = compilation.graph.find(
    (p) => !p.id.localeCompare(id),
  );
  return {
    id,
    label,
    route,
    title: page ? (page.title ? page.title : label) : label,
    data: {
      author: "Luke Schierer",
      published: Date.now(),
      date: Date.now(),
    },
  };
}

export { getFrontmatter };
