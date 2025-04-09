import { greenwoodPluginPostCss } from "@greenwood/plugin-postcss";
import { greenwoodPluginGoogleAnalytics } from "@greenwood/plugin-google-analytics";
import { greenwoodPluginImportRaw } from "@greenwood/plugin-import-raw";

export default {
  useTsc: true,
  activeContent: true,
  isolation: true,
  optimization: "default",
  prerender: false,
  staticRouter: false,
  markdown: {
    plugins: ["rehype-autolink-headings", "remark-gfm", "remark-rehype"],
    settings: {
      commonmark: true,
    },
  },
  plugins: [
    greenwoodPluginPostCss({
      extendConfig: true,
    }),
    greenwoodPluginGoogleAnalytics({
      analyticsId: "G-Y3WJYW9RQ1",
    }),
    greenwoodPluginImportRaw(),
  ],
};
