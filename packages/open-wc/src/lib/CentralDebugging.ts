console.log("🔍🔍🔍 LOADING CUSTOM DEBUG MODULE 🔍🔍🔍");

import * as log4js from "log4js";

const debugSettings: Map<string, boolean> = new Map<string, boolean>([
  ["src/components/random-unfinished-thoughts.ts", false],
  ["src/components/MainMarkdown.ts", true],
  ["src/lib/CentralDebugging.ts", false],
  ["src/pages/home/home-page.ts", false],
]);

export const initDebug = () => {
  log4js.configure({
    appenders: {
      out: { type: "stdout" },
    },
    categories: {
      default: { appenders: ["out"], level: "trace" },
    },
  });
};

export const logger = log4js.getLogger();

// Export a default function for backward compatibility
export const debugEnabled = (modulePath: string): boolean => {
  const enabled = debugSettings.get(modulePath);
  if (enabled !== undefined) {
    return enabled;
  }
  return false;
};
