# Luke Controller Fixes

## Issues Fixed

### 1. "Too many arguments" Error
**Problem:** Async route handlers were defined as `async sub ($c, $ctx)` but Thunderhorse was passing 3 arguments (including route parameters).

**Fix:** Changed all async subs to accept variable arguments: `async sub ($c, $ctx, @args)`

**Files Changed:**
- `lib/Schierer/Org/Controller/Luke.pm`

**Locations:**
- `build()` method - main content routes
- `build()` method - catch-all static asset route
- `_register_redirects()` method
- `_register_static_files()` method

### 2. 404 on `/~luke` and `/~luke/`
**Problem:** No routes registered for the root luke paths.

**Fix:** Added explicit routes for:
- `/~luke` - Serves `index.html` or redirects to `/~luke/log/`
- `/~luke/` - Same as above

### 3. 404 on `/~luke/log` and `/~luke/log/`
**Problem:** No routes registered for the log index.

**Fix:** Added explicit routes for:
- `/~luke/log` - Serves `log/index.html` or renders `log/index.md`
- `/~luke/log/` - Same as above

## Testing

After these fixes, the following should work:

```bash
just quickdev
```

Then visit:
- http://127.0.0.1:3004/~luke - Should redirect to /~luke/log/ or serve index.html
- http://127.0.0.1:3004/~luke/log - Should render log/index.md
- http://127.0.0.1:3004/~luke/log/2005/01/26/20050126-1504/ - Should render markdown post

## Route Priority

Routes are registered in this order:
1. Redirects (from `dist/redirects.json`)
2. Static files (root-level `.html`, `.pdf`, `.txt`)
3. All markdown content (`.md` files under `log/`)
4. Index routes (`/~luke`, `/~luke/`, `/~luke/log`, `/~luke/log/`)
5. Catch-all static assets (`/~luke/*path`)

## Next Steps

If you still get 404s, check:
1. Is `packages/luke` the correct path in config?
2. Does `packages/luke/log/index.md` exist?
3. Are there any markdown files being found? (Check server logs for "Registered N ~luke content routes")
