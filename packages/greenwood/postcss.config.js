import postcssImport from "postcss-import";
import cssnano from "cssnano";
import autoprefixer from "autoprefixer";
import postcssJitProps from "postcss-jit-props";
import OpenProps from "open-props";

/** @type {import('postcss-load-config').Config} */
export default {
  plugins: [postcssImport(), postcssJitProps(OpenProps), autoprefixer, cssnano],
};
