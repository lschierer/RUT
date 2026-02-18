# Build-time vs Runtime Processing

## Build-time Tasks (in `build_luke.pl`)

### 1. Markdown Conversion ✓ (Already implemented)
- Convert `.mdwn` → `.md` using pandoc
- Extract ikiwiki directives
- Selective reconversion based on git history

### 2. Redirect Extraction ✓ (Already implemented)
- Scan `.mdwn` files for `[[!meta redir="target"]]`
- Generate `dist/redirects.json`

### 3. Date Manifest ✓ (Already implemented)
- Extract last-edited dates from:
  - Git history (default)
  - YAML frontmatter (`date:` field)
  - Ikiwiki meta tags (`[[!meta date="..."]]`)
- Generate `dist/dates.json`

### 4. Calendar Generation ⚠️ (NEEDS IMPLEMENTATION)

**Purpose:** Pre-generate monthly calendar HTML fragments

**Input:** Scan `log/{YYYY}/{MM}/` directories for `.md` files

**Output:** `log/archive/{YYYY}/{MM}/calendar.html`

**Algorithm:**
```perl
for each year/month with content:
  - Get days in month (DateTime)
  - For each day 1-31:
    - Check if log/{YYYY}/{MM}/{DD}/ exists with .md files
    - If yes: create link <a href="/~luke/log/{YYYY}/{MM}/{DD}/">{DD}</a>
    - If no: plain text {DD}
  - Generate HTML table (7 columns, week rows)
  - Write to log/archive/{YYYY}/{MM}/calendar.html
```

**Template:**
```html
<table class="calendar">
  <thead>
    <tr><th>Sun</th><th>Mon</th>...<th>Sat</th></tr>
  </thead>
  <tbody>
    <tr>
      <td></td>  <!-- Empty for days before month starts -->
      <td><a href="/~luke/log/2007/08/01/">1</a></td>
      <td>2</td>  <!-- No posts this day -->
      ...
    </tr>
  </tbody>
</table>
```

### 5. Archive Index Generation ⚠️ (NEEDS IMPLEMENTATION)

**Purpose:** Pre-generate year/month index pages

**Year Index:**
- Input: Scan `log/` for year directories
- Output: `log/archive/{YYYY}/index.md` with frontmatter:
  ```yaml
  ---
  title: "Archive for {YYYY}"
  layout: "rut"
  archive_type: "year"
  year: {YYYY}
  months:
    - month: "01"
      count: 5
    - month: "03"
      count: 12
  ---
  ```

**Month Index:**
- Input: Scan `log/{YYYY}/{MM}/` for day directories
- Output: `log/archive/{YYYY}/{MM}/index.md` with frontmatter:
  ```yaml
  ---
  title: "Archive for {Month} {YYYY}"
  layout: "rut"
  archive_type: "month"
  year: {YYYY}
  month: {MM}
  days: [1, 3, 5, 9, 15, 22, 30]
  ---
  ```

### 6. Category Index Scanning ⚠️ (OPTIONAL)

**Purpose:** Generate category metadata

**Input:** Scan for category directories (e.g., `log/science/`, `log/Society/`)

**Output:** `dist/categories.json`
```json
{
  "science": {
    "posts": ["log/science/prolife_science.md", ...],
    "count": 15
  },
  "Society": {
    "posts": ["log/Society/homosexuality.md", ...],
    "count": 23
  }
}
```

## Runtime Tasks (in web server)

### 1. Route Matching
- Match URL to file path
- Check redirects first (from `dist/redirects.json`)
- Try file extensions in order: `.html`, `.md`, `.pdf`, `.txt`
- Try directory index files

### 2. Markdown Rendering
- Read `.md` file
- Extract YAML frontmatter
- Convert markdown to HTML (using Discount or Text::MultiMarkdown)
- Load last-edited date from `dist/dates.json`
- Render with template

### 3. Template Rendering
- Select layout from frontmatter or default
- Inject content, title, dates
- Add current calendar widget (from pre-generated HTML)
- Render final HTML

### 4. Static File Serving
- Serve `.html`, `.pdf`, `.txt` directly
- Serve assets from `staticAssets/`
- Serve CSS/JS from `dist/`

### 5. Legacy URL Redirects
- Check for old date format: `/log/{YYYYMMDD}/`
- Convert to new format: `/log/{YYYY}/{MM}/{DD}/`
- 301 redirect

## Updated `build_luke.pl` Tasks

Add to existing script:

```perl
# Step 4: Generate calendar fragments
say "=== Step 4: Generating calendar fragments ===";
my $calendar_gen = App::CalendarGenerator->new(
  source_dir => './log',
  output_dir => './log/archive',
);
$calendar_gen->generate_all_calendars();

# Step 5: Generate archive indexes
say "=== Step 5: Generating archive indexes ===";
my $archive_gen = App::ArchiveGenerator->new(
  source_dir => './log',
  output_dir => './log/archive',
);
$archive_gen->generate_year_indexes();
$archive_gen->generate_month_indexes();
```

## New Modules Needed

### `App::CalendarGenerator`
- `generate_all_calendars()` - Scan log/ and generate all calendar.html files
- `generate_calendar($year, $month)` - Generate single calendar
- `get_days_with_posts($year, $month)` - Return array of days with content

### `App::ArchiveGenerator`
- `generate_year_indexes()` - Create index.md for each year
- `generate_month_indexes()` - Create index.md for each month
- `scan_year($year)` - Get months with content
- `scan_month($year, $month)` - Get days with content

## Summary

**Already Done:**
- ✓ Markdown conversion (.mdwn → .md)
- ✓ Redirect extraction
- ✓ Date manifest

**Need to Add:**
- ⚠️ Calendar HTML generation
- ⚠️ Archive index generation
- ⚠️ Category metadata (optional)

**Runtime stays simple:**
- Route matching
- Markdown rendering
- Template rendering
- Static file serving
- Redirects (using pre-generated manifests)
