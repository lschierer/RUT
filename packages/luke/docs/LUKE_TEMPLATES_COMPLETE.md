# Luke Templates - Implementation Complete

## Templates Created

### Layouts
**Location:** `templates/layouts/`

1. **`luke_rut.tt`** - Full blog layout with sidebar
   - Header with logo and GitHub link
   - Article content area
   - Sidebar with:
     - Calendar widget (current month)
     - Archive year links (2005-present)
   - Footer with copyright and CC license

2. **`luke_default.tt`** - Simple page layout
   - Basic header/content/footer
   - No sidebar
   - Minimal styling

### Content Templates
**Location:** `templates/luke/`

1. **`log_entry.tt`** - Wrapper for blog posts
   - Selects layout based on frontmatter
   - Defaults to `luke_rut` layout
   - Wraps markdown content

## Template Variables

All templates receive:
```perl
{
  content => $html,              # Rendered markdown
  title => $title,               # From frontmatter or path
  current_year => 2026,          # Current year
  last_edited => "3 days ago",   # Relative date (if available)
  calendar_widget => "<table>...", # Current month calendar HTML
  layout => "luke_rut",          # Layout name from frontmatter
}
```

## Frontmatter Support

Markdown files can specify layout:
```yaml
---
title: "My Post Title"
layout: luke_default  # or luke_rut (default)
---
```

## Controller Integration

**File:** `lib/Schierer/Org/Controller/Luke.pm`

**Changes:**
1. ✅ Parses frontmatter to get layout preference
2. ✅ Generates current month calendar widget
3. ✅ Passes all variables to template
4. ✅ Uses `luke/log_entry` template for all markdown

**Calendar Widget:**
- Reads from `packages/luke/log/archive/{YEAR}/{MONTH}/calendar.html`
- Generated at build time by `build_luke.pl`
- Falls back to "No calendar available" if missing

## Template Toolkit Syntax

**Variables:** `[% variable %]`
**Conditionals:** `[% IF condition %]...[% END %]`
**Loops:** `[% FOREACH item IN list %]...[% END %]`
**Ranges:** `[% FOREACH year IN [2005 .. current_year] %]`
**Wrapper:** `[% WRAPPER layouts/luke_rut %]...[% END %]`

## Testing

After restart, check:
1. Blog posts use `luke_rut` layout with sidebar
2. Calendar widget shows current month
3. Archive links show years 2005-2026
4. Last edited date appears on posts
5. Layout can be overridden in frontmatter

## File Structure

```
templates/
├── layouts/
│   ├── default.tt          # Generic site layout
│   ├── luke_default.tt     # Simple Luke layout
│   └── luke_rut.tt         # Full Luke blog layout
└── luke/
    └── log_entry.tt        # Blog post wrapper
```

## Next Steps

1. Test rendering with `just quickdev`
2. Visit `/~luke/log/2005/01/26/20050126-1504/`
3. Verify calendar widget appears
4. Check CSS is loading correctly
5. Add archive page templates if needed
