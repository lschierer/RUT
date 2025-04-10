import { glob } from "glob";
import nodeResolve from "@rollup/plugin-node-resolve";
import replace from "@rollup/plugin-replace";
import { rollupPluginHTML as html } from "@web/rollup-plugin-html";
import alias from "@rollup/plugin-alias";
import serve from "rollup-plugin-serve";
import livereload from "rollup-plugin-livereload";

import process from "node:process";

// Get all HTML files in the src/pages directory
const htmlEntries = glob.sync("src/pages/**/index.html");

export default {
  input: htmlEntries,
  output: {
    // Put all JS in an assets directory
    entryFileNames: "assets/scripts/[hash].js",
    chunkFileNames: "assets/scripts/[hash].js",
    assetFileNames: (assetInfo) => {
      const info = assetInfo.name.split(".");
      const ext = info[info.length - 1];
      if (/png|jpg|svg|gif|webp/.test(ext)) {
        return `assets/images/[hash][extname]`;
      }
      if (/css/.test(ext)) {
        return `assets/styles/[hash][extname]`;
      }
      return `assets/[hash][extname]`;
    },
    format: "es",
    dir: "dist",
  },
  preserveEntrySignatures: false,

  nodeResolve: {
    exportConditions: ["browser", "development"],
    extensions: [".js", ".ts"], // Add this line
  },

  plugins: [
    alias({
      entries: [
        { find: "@lib", replacement: "./out-tsc/src/lib" },
        { find: "@components", replacement: "./out-tsc/src/components" },
        { find: "@pages", replacement: "./out-tsc/src/pages" },
      ],
    }),
    nodeResolve(),
    /** Replace environment variables */
    replace({
      preventAssignment: true,
      "process.env.NODE_ENV": JSON.stringify(
        process.env.NODE_ENV || "development",
      ),
    }),
    /** Enable using HTML as rollup entrypoint */
    html({
      minify: process.env.NODE_ENV === "production",
      injectServiceWorker: false,
      // This is critical - it maintains your directory structure
      flattenOutput: false,
      // Transform the path to match your desired URL structure
      transformHtml: [
        (html, { path: filePath }) => {
          // Extract the page path from src/pages/
          const pagePathMatch = filePath.match(
            /src\/pages\/(.+)\/index\.html$/,
          );
          if (pagePathMatch) {
            const pagePath = pagePathMatch[1];
            // For pages other than home, place them in their own directory
            if (pagePath !== "home") {
              return {
                // This determines where the HTML file will be output
                path: `${pagePath}/index.html`,
                html,
              };
            } else {
              // Home page goes to root
              return {
                path: "index.html",
                html,
              };
            }
          }
          return { html };
        },
      ],
    }),
    // Rest of your plugins...
    serve({
      open: false, // Open in browser
      verbose: true, // Show server logs
      contentBase: ["./out-tsc", "./src/pages", "./src/"], // Serve from these directories
      historyApiFallback: true, // For single-page apps
      host: "localhost", // Host address
      port: 3000, // Port number
    }),
    livereload({
      watch: ["out-tsc", "src/pages"], // Watch directory for changes
    }),
  ],
};
