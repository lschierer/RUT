import { hmrPlugin, presets } from "@open-wc/dev-server-hmr";
import { fromRollup } from "@web/dev-server-rollup";
import rollupReplace from "@rollup/plugin-replace";
import { importMapsPlugin } from "@web/dev-server-import-maps";
import { esbuildPlugin } from "@web/dev-server-esbuild";
import { fileURLToPath } from "node:url";

const replace = fromRollup(rollupReplace);

/** Use Hot Module replacement by adding --hmr to the start command */
const hmr = process.argv.includes("--hmr");

export default /** @type {import('@web/dev-server').DevServerConfig} */ ({
  watch: !hmr,
  /** Resolve bare module imports */
  nodeResolve: {
    exportConditions: ["browser", "development"],
  },

  /** Compile JS for older browsers. Requires @web/dev-server-esbuild plugin */
  // esbuildTarget: 'auto'

  /** Set appIndex to enable SPA routing */
  //appIndex: "./index.html",

  /** rootDir for MPA routing */
  appIndex: "",
  rootDir: "./",

  middleware: [
    function rewriteUrls(context, next) {
      // Handle root path
      if (context.url === "/") {
        context.url = "/src/pages/home/index.html";
      }
      // Handle clean URLs like /about/ -> /src/pages/about/index.html
      else if (context.url.endsWith("/") && !context.url.includes(".")) {
        const path = context.url.slice(1, -1); // Remove leading / and trailing /
        if (path) {
          context.url = `/src/pages/${path}/index.html`;
        }
      }
      return next();
    },
  ],

  plugins: [
    importMapsPlugin({
      inject: {
        importMap: {
          imports: {
            // Map production paths to development paths
            "/assets/scripts/": "/out-tsc/src/pages/",
            "@lib/": "/out-tsc/src/lib/",
            "@components/": "/out-tsc/src/components/",
            "@pages/": "/out-tsc/src/pages/",
          },
        },
      },
    }),
    replace({
      // setting "include" is important for performance
      include: ["src/random-unfinished-thoughts.ts"],
      preventAssignment: true,
      "process.env.NODE_ENV": '"development"',
    }),
    {
      name: "debug-initializer",
      transform(context) {
        // Add debug initialization to HTML files
        if (context.response.is("html")) {
          return context.body.replace(
            "</head>",
            '<script type="module" src="/out-tsc/src/debug-init.js"></script></head>',
          );
        }
        return undefined;
      },
    },
  ],

  // See documentation for all available options
});
