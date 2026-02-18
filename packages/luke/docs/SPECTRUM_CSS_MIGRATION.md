# Open-Props to Spectrum-CSS Migration

## Overview
This document outlines the conversion from Open-Props to Spectrum-CSS for the luke package styles.

## Changes Made

### 1. Import Statements
**Before (Open-Props):**
```css
@import "open-props/open-props.min.css";
@import "open-props/normalize.min.css";
@import "open-props/buttons.min.css";
@import "open-props/brand-colors.min.css";
```

**After (Spectrum-CSS):**
```css
@import "@spectrum-css/tokens/dist/index.css";
@import "@spectrum-css/page/dist/index.css";
@import "@spectrum-css/typography/dist/index.css";
```

### 2. Color Token Mapping

| Open-Props | Spectrum-CSS | Usage |
|------------|--------------|-------|
| `--blue-5` | `--spectrum-blue-900` | Brand dark color |
| `--indigo-7` | `--spectrum-gray-50` | Primary text (dark theme) |
| `--blue-8` | `--spectrum-blue-400` | Secondary text |
| `--gray-8` through `--gray-11` | `--spectrum-gray-100` through `--spectrum-gray-400` | Surface colors |
| `--gray-0` | `--spectrum-gray-50` | Icon colors |

### 3. Sizing Token Mapping

| Open-Props | Spectrum-CSS | Context |
|------------|--------------|---------|
| `--size-3` | `--spectrum-global-dimension-size-200` | Standard margins |
| `--size-2` | `--spectrum-global-dimension-size-150` | Smaller margins |
| `--size-13` | `--spectrum-global-dimension-size-2400` | Logo height |
| `--size-relative-2` | `--spectrum-global-dimension-size-150` | Padding |
| `--size-relative-5` | `--spectrum-global-dimension-size-400` | Table margins |
| `--size-8` | `--spectrum-global-dimension-size-600` | Large margins |
| `--size-4` | `--spectrum-global-dimension-size-300` | Medium padding |
| `--size-15` | `--spectrum-global-dimension-size-3000` | License width |

### 4. Font Size Token Mapping

| Open-Props | Spectrum-CSS | Usage |
|------------|--------------|-------|
| `--font-size-0` | `--spectrum-global-dimension-font-size-75` | Reduced text (90%) |
| `--font-size-1` | `--spectrum-global-dimension-font-size-100` | Standard text |

### 5. Border & Radius Token Mapping

| Open-Props | Spectrum-CSS | Usage |
|------------|--------------|-------|
| `--border-size-1` | `1px` | Standard borders |
| `--border-size-2` | `2px` | Emphasized borders |
| `--radius-conditional-3` | `--spectrum-global-dimension-size-50` | Border radius |

## Files Modified

1. **styles/global.css**
   - Updated imports
   - Converted color tokens
   - Converted sizing tokens

2. **styles/home.css**
   - Updated logo height sizing

3. **styles/rut.css**
   - Updated imports
   - Converted all sizing, font, and border tokens
   - Maintained layout structure

4. **package.json**
   - Removed `open-props` dependency
   - Kept existing Spectrum-CSS dependencies

## Testing Recommendations

1. **Visual Inspection:**
   - Check header layout and spacing
   - Verify aside/sidebar appearance
   - Confirm table styling in calendar views
   - Review footer layout

2. **Responsive Testing:**
   - Test on mobile, tablet, and desktop viewports
   - Verify flex layouts still work correctly

3. **Color Verification:**
   - Ensure dark theme colors are appropriate
   - Check text contrast ratios for accessibility

4. **Build Process:**
   ```bash
   pnpm install  # Update dependencies
   pnpm build    # Build CSS
   ```

## Notes

- Spectrum-CSS uses a more structured token system with explicit sizing scales
- Some Open-Props relative sizing has been converted to fixed Spectrum sizes
- The overall look and feel should remain very similar
- Spectrum-CSS provides better consistency with Adobe's design system
- All custom CSS variables (--brand, --text-1, etc.) are preserved for backward compatibility

## Rollback

If issues arise, the original Open-Props implementation can be restored by:
1. Reverting changes to the three CSS files
2. Re-adding `"open-props": "catalog:"` to package.json dependencies
3. Running `pnpm install`
