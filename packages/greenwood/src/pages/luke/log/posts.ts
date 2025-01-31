import {
  type Compilation,
  type Route,
  Page,
  sortPages,
} from "../../../lib/greenwoodPages.ts";

import { getContent } from "@greenwood/cli/src/data/client.js";

export default class MyPage extends HTMLElement {
  private pages: Page[] = new Array<Page>();

  constructor() {
    super();
  }

  async connectedCallback() {
    this.pages = (await getContent())
      .filter((page: Page) => {
        if (
          page.route.startsWith("/luke/log/blog/") ||
          page.route.startsWith("/luke/log/sidebar") ||
          page.route.startsWith("/luke/log/archives")
        ) {
          return false;
        }
        if (!page.route.startsWith("/luke/log/")) {
          return false;
        }
        if (!page.route.localeCompare("/luke/log/")) {
          return false;
        }
        return true;
      })
      .sort((a, b) => sortPages(a, b));
    this.innerHTML = `
      <div>
        Here is a full list of posts and pages.
        <ul>
          ${this.pages
            .map((p) => {
              return `
              <li>
                <a href="${p.route}"> ${p.title ? p.title : p.label} </a>
              </li>
            `;
            })
            .join("\n")}
        </ul>
      </div>
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
    layout: "rut",
    data: {
      author: "Luke Schierer",
      published: Date.now(),
      date: Date.now(),
    },
  };
}

export { getFrontmatter };
