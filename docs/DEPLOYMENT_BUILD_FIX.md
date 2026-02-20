# Deployment Build Process Fix

## Problem
The deployment script was running `build_luke.pl` on the EC2 instance during deployment, but this script and its dependencies (ConversionManifest, IkiConverter, DateManifest, RecentChanges) all require `Git::Repository`, which needs a `.git` directory. This doesn't exist on the deployed instance.

Additionally, the build output was going to a `dist/` directory, which was being excluded by CDK's default asset exclusions (the glob pattern `dist` matches at any level, including `packages/luke/dist`).

## Solution

### 1. Renamed Output Directory
Changed from `dist` to `build-output` to avoid CDK's default exclusions:
- Updated `build_luke.pl` to use `./build-output`
- Updated `App::IkiConverter` default log path
- Updated `App::DateManifest` default output path
- Updated `.gitignore` in packages/luke
- Updated `justfile` watchexec path

### 2. Moved Build to Pre-CDK Phase
The build now happens **before** CDK packaging, not during deployment:

**Before:**
```
Local: just deploy-prod
  → CDK synth/deploy
    → EC2: build-for-deploy.sh runs build_luke.pl (FAILS - no .git)
```

**After:**
```
Local: just deploy-prod
  → just build-luke-content (runs build_luke.pl with .git available)
    → CDK synth (packages build-output/ into asset)
      → CDK deploy
        → EC2: build-for-deploy.sh (no longer runs build_luke.pl)
```

### 3. Updated Files

**justfile:**
- Added `build-luke-content` dependency to all deploy-* recipes
- Updated watchexec path from `dist` to `build-output`

**scripts/build-for-deploy.sh:**
- Removed `build_luke.pl` execution
- Removed `pnpm build:prod` for luke package
- Now only installs dependencies and extracts archives

**packages/luke/bin/build_luke.pl:**
- Changed output directory from `./dist` to `./build-output`
- Updated all internal path references

**packages/luke/lib/App/IkiConverter.pm:**
- Updated default log_file path

**packages/luke/lib/App/DateManifest.pm:**
- Updated default output_file path

## Deployment Flow

1. Developer runs `just deploy-prod` (or dev/test)
2. `build-luke-content` runs first (with Git available)
   - Converts ikiwiki markdown
   - Generates manifests, archives, calendar
   - Outputs to `packages/luke/build-output/`
3. CDK synth packages the code (including `build-output/`)
4. CDK deploy sends asset to EC2
5. On EC2, `build-for-deploy.sh` only installs dependencies
6. Application starts with pre-built content

## Benefits
- No Git dependency on EC2 instance
- Build artifacts properly included in CDK asset
- Faster deployment (no rebuild on instance)
- Cleaner separation of build vs deploy phases
