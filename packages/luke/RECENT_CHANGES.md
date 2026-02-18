# Recent Changes - Minimal Implementation

## Overview

Clean, efficient recent changes implementation that:
1. Generates JSON manifest at build time
2. Renders via template at runtime
3. No massive TypeScript files or slow processing

## Build-Time Generation

**Module:** `lib/App/RecentChangesManifest.pm`

**What it does:**
- Scans git log for commits affecting `log/**/*.md(wn)` files
- Excludes build commits and calendar updates
- Extracts file paths and titles from frontmatter
- Generates `dist/recent_changes.json` with structured data

**Output Format:**
```json
[
  {
    "commit": "abc123def456",
    "commit_url": "https://github.com/lschierer/RUT/commit/abc123...",
    "message": "feat: add new post",
    "timestamp": 1234567890,
    "files": [
      {
        "path": "2005/01/26/20050126-1504",
        "title": "Post Title from Frontmatter",
        "url": "/~luke/log/2005/01/26/20050126-1504/"
      }
    ]
  }
]
```

**Limits:**
- 100 commits (configurable)
- 10 files per commit
- Excludes index.md files
- Excludes commits starting with `fix:` or `break:`

## Runtime Rendering

**Route:** `/~luke/log/recent` or `/~luke/log/recent/`

**Template:** `templates/luke/recent_changes.tt`

**Controller:** `lib/Schierer/Org/Controller/Luke.pm`
- Loads `dist/recent_changes.json`
- Formats timestamps
- Renders with template

## Build Integration

**File:** `bin/build_luke.pl`

**Step 6:** Generate recent changes manifest
```bash
cd packages/luke
mise exec -- perl ./bin/build_luke.pl
```

## Template

Simple definition list format:
```html
<dl class="recent-changes">
  <dt><a href="commit_url">abc123</a></dt>
  <dd>2005-01-26 12:34:56</dd>
  <dd>Commit message</dd>
  <dd>
    <ul class="filelist">
      <li><a href="/~luke/log/path/">Post Title</a></li>
    </ul>
  </dd>
</dl>
```

## Advantages Over Previous Attempts

### vs TypeScript Version
- ❌ Old: Generated massive `commitHistory.ts` file
- ✅ New: Small JSON manifest (~50KB)
- ❌ Old: Slow client-side rendering
- ✅ New: Fast server-side rendering
- ❌ Old: Never worked right
- ✅ New: Clean, simple, works

### vs Perl HTML Generation
- ❌ Old: Generated HTML directly in Perl
- ✅ New: Generates data, renders via template
- ❌ Old: Mixed concerns (data + presentation)
- ✅ New: Separated concerns
- ❌ Old: Unused variables, incomplete
- ✅ New: Complete, minimal implementation

## Testing

```bash
# Build
cd packages/luke
mise exec -- perl ./bin/build_luke.pl

# Check output
cat dist/recent_changes.json | jq '.[0]'

# Start server
cd ../..
just quickdev

# Visit
http://127.0.0.1:3004/~luke/log/recent
```

## Files

```
packages/luke/
├── lib/App/
│   └── RecentChangesManifest.pm  # Build-time generator
├── bin/
│   └── build_luke.pl              # Calls generator
└── dist/
    └── recent_changes.json        # Generated manifest

SchiererOrg/
├── lib/Schierer/Org/Controller/
│   └── Luke.pm                    # Runtime handler
└── templates/luke/
    └── recent_changes.tt          # Display template
```

## Configuration

Change limit in `build_luke.pl`:
```perl
my $recent_gen = App::RecentChangesManifest->new(
  source_dir => '.',
  output_file => './dist/recent_changes.json',
  limit => 200,  # Show more commits
);
```

## Next Steps

1. Add link to recent changes in sidebar
2. Style the definition list with CSS
3. Add pagination if needed
4. Consider caching the rendered HTML
