import eslint from "@eslint/js";
import tseslint from "typescript-eslint";
import globals from "globals";

export default tseslint.config(
  {
    ignores: ["packages/infrastructure/.sst/**", "packages/luke/dist/**"],
  },
  {
    extends: [
      tseslint.configs.recommendedTypeChecked,
      tseslint.configs.strictTypeChecked,
    ],
    rules: {
      "no-unused-vars": "off",
      "@typescript-eslint/no-unused-vars": "error",
      "@typescript-eslint/consistent-type-imports": [
        "error",
        {
          prefer: "type-imports",
          fixStyle: "inline-type-imports",
        },
      ],
      "@typescript-eslint/restrict-template-expressions": [
        "error",
        {
          allowNumber: true,
        },
      ],
    },
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: {
        ...globals.browser,
      },
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
        projectFolderIgnoreList: ["**/node_modules/**"],
      },
    },
  },
  {
    files: ["**/*/*.js", "**/*/*.mjs"],
    extends: [eslint.configs.recommended, tseslint.configs.disableTypeChecked],
  },
  {
    files: [
      "sst.config.ts",
      "packages/infrastructure/**/*.ts",
      "packages/infrastructure/**/*.mts",
    ],
    rules: {
      "@typescript-eslint/no-unused-vars": "off",
      "@typescript-eslint/triple-slash-reference": "off",
    },
  },
);
