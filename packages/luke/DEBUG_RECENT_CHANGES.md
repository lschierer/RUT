# Quick test to see if git log works

Run this from `packages/luke`:

```bash
cd /Volumes/workplace/src/schierer/PAGI-WebServer/SchiererOrg/packages/luke
git log --oneline -n 10 -- log/**/*.md log/**/*.mdwn
```

If that shows commits, then rebuild:

```bash
mise exec -- perl ./bin/build_luke.pl
cat dist/recent_changes.json | head -20
```

The issue was that `work_tree => $source_dir` was pointing to `.` (packages/luke) but we need the git repo root. Changed to `work_tree => '.'` which should work from the packages/luke directory.
