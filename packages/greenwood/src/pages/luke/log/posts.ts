import {
  type Compilation,
  type Route,
  Page,
} from "../../../lib/greenwoodPages.ts";

async function getBody(compilation: Compilation, route: Route) {
  const pages = compilation.graph
    .filter((page: Page) => {
      console.log(`page.route is ${page.route}`);
      if (
        page.route.startsWith("/luke/log/blog/") ||
        page.route.startsWith("/luke/log/sidebar") ||
        page.route.startsWith("/luke/log/archives")
      ) {
        return false;
      }
      if (!page.route.localeCompare("/luke/log/")) {
        return false;
      }
      if (!page.route.localeCompare(route.route)) {
        return false;
      }
      if (!page.route.startsWith("/luke/log/")) {
        return false;
      }
      return true;
    })
    .sort((a, b) => {
      const at = a.title ? a.title : a.label;
      const bt = b.title ? b.title : b.label;
      return at.toLowerCase().localeCompare(bt.toLowerCase());
    });
  return `
      <div>
        Here is a full list of posts and pages.
        <ul>
          ${pages
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

export { getFrontmatter, getBody };
