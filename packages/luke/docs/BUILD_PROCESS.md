# Luke Package Build Process

## Overview
The luke package build process has been streamlined to eliminate unnecessary abstraction layers.

## Build Steps (in order)

### 1. Install Dependencies
```bash
pnpm install
```
Installs both Perl and Node.js dependencies.

### 2. Convert Content & Build Manifests
```bash
./bin/build_luke.pl
```

This script:
- Analyzes git history to determine which `.mdwn` files need reconversion
- Converts ikiwiki markdown (`.mdwn`) to GFM markdown (`.md`) using pandoc
- Extracts redirect directives from ikiwiki meta tags
- Generates `dist/redirects.json` for 308 redirects
- Builds `dist/dates.json` with last-edited metadata from git/frontmatter/meta tags

**Output:**
- `dist/conversion_log.txt` - Conversion details
- `dist/dates.json` - Last-edited dates for all content
- `dist/redirects.json` - URL redirect mappings

### 3. Build TypeScript/CSS Assets
```bash
pnpm build:prod
```

This runs:
- `esbuild` to compile TypeScript
- PostCSS pipeline to build CSS from Spectrum-CSS

**Output:**
- `dist/styles/` - Compiled CSS

## Just Targets

### `just build-luke-content`
Runs the complete build process (steps 2-3 above).

### `just content-setup`
Runs `install` + `build-luke-content`.

### `just sync-frontend`
Builds luke content and syncs to frontend package.

## Deprecated Files

- `bin/setup.sh` - **DEPRECATED**: Replaced by direct justfile commands
- `bin/process.pl` - **DEPRECATED**: Functionality moved to `build_luke.pl`
- `bin/tsSetup.sh` - **DEPRECATED**: Replaced by `pnpm build:prod`

## File Serving Rules

1. `.txt`, `.pdf`, `.html` at `packages/luke/*` → serve at `~/luke/*`
2. Files under `packages/luke/staticAssets/*` → serve at `~/luke/*`
3. `.md` files under `packages/luke/**/*` → process with discount, serve at `~/luke/**/*`
4. `.mdwn` files under `packages/luke/log/**/*` → convert to `.md`, then apply rule 3
5. Blog posts get template with last-edited date (from `dist/dates.json`)
6. Redirects from `dist/redirects.json` → 308 permanent redirects

## Quick Start

```bash
cd /Volumes/workplace/src/schierer/PAGI-WebServer/SchiererOrg
just build-luke-content
```
