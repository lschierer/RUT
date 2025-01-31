const fileDebug: Record<string, boolean> = {
  "src/components/RecentChanges.ts": false,
  "src/components/license.ts": false,
  "src/components/MainIndex.ts": false,
  "src/components/TagIndex.ts": true,
  "src/components/tags.ts": false,
  "src/lib/debug.ts": false,
  "src/lib/greenwoodPages.ts": false,
  "src/lib/users.ts": false,
  "src/pages/luke/gpg.ts": false,
};

const debugFunction = (myName: string): boolean => {
  return fileDebug[myName];
};

export default debugFunction;
