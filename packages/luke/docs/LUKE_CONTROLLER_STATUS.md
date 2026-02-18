# Luke Controller - Current State

## What's Implemented

### Controller: `lib/Schierer/Org/Controller/Luke.pm`

**Base Class:** `WebFramework::Controller::Base`
- Inherits from `Thunderhorse::Controller`
- Has `WebFramework::Role::Markdown` role (provides `render_markdown_page`)
- Has `WebFramework::Role::LogConfig` role

**Key Features:**
1. ✅ Loads markdown files from `packages/luke/log/**/*.md`
2. ✅ Loads redirects from `packages/luke/dist/redirects.json`
3. ✅ Loads date manifest from `packages/luke/dist/dates.json`
4. ✅ Registers routes for all markdown content
5. ✅ Registers routes for static files (`.html`, `.pdf`, `.txt`)
6. ✅ Handles static assets from `staticAssets/`
7. ✅ Formats relative dates ("3 days ago", etc.)

**Routes Registered:**
- Redirects (308) from `redirects.json`
- Static files at root level
- All markdown content: `/~luke/log/**/*.md` → `/~luke/log/**/`
- Index routes: `/~luke`, `/~luke/`, `/~luke/log`, `/~luke/log/`
- Catch-all: `/~luke/*path` for assets

## Configuration

**Default Content Directory:** `packages/luke`

Override in config:
```perl
{
  config => {
    luke_content_dir => 'packages/luke',
  }
}
```

## What's Missing (To Be Implemented)

### 1. Template Integration
The controller calls `render_markdown_page` which uses templates, but we need to create the luke-specific templates:

**Needed Templates:**
- `templates/luke/log_entry.tt` - Blog post layout
- Or use existing `templates/markdown.tt` with proper vars

**Template Variables Provided:**
```perl
{
  content => $html,           # Rendered markdown
  title => $title,            # From frontmatter or path
  current_year => $year,
  last_edited => "3 days ago", # Relative date
  template => 'luke/log_entry',
}
```

### 2. Archive Page Rendering
The generated archive index pages (`log/archive/YYYY/index.md`) need to be rendered with special handling for the frontmatter data.

**Archive Frontmatter:**
```yaml
---
title: "Archive for 2005"
layout: rut
archive_type: year
year: 2005
months:
  - month: "01"
    count: 9
---
```

**Needed:** Template that reads `archive_type` and renders accordingly.

### 3. Calendar Widget
The `rut` layout needs to inject the current month's calendar.

**Implementation:**
```perl
# In controller or helper
sub get_current_calendar ($self) {
  my ($year, $month) = (localtime)[5,4];
  $year += 1900;
  $month = sprintf("%02d", $month + 1);
  
  my $cal_file = $self->luke_dir->child("log/archive/$year/$month/calendar.html");
  return $cal_file->exists ? $cal_file->slurp_utf8 : '';
}
```

### 4. Legacy URL Redirects
The old `YYYYMMDD` format URLs need 301 redirects to `YYYY/MM/DD`.

**Pattern:** `/~luke/log/20050131/...` → `/~luke/log/2005/01/31/...`

**Implementation:** Add to `build()` method before other routes.

## Testing Checklist

After restart:
- [ ] `/~luke` - Should redirect or serve index
- [ ] `/~luke/log` - Should render log index
- [ ] `/~luke/log/2005/01/26/20050126-1504/` - Should render markdown post
- [ ] `/~luke/assets/owl.gif` - Should serve static asset
- [ ] `/~luke/styles/global.css` - Should serve CSS
- [ ] Check server logs for "Registered N ~luke content routes"

## Next Steps

1. **Create templates** in `templates/luke/`
2. **Add calendar widget** helper
3. **Add legacy URL redirects** for `YYYYMMDD` format
4. **Test archive pages** rendering

## Notes

- The `packages/frontend` directory is deprecated - only use as reference
- All new code goes in `lib/Schierer/Org/`
- Templates go in `templates/` at project root
- Build process generates manifests in `packages/luke/dist/`
