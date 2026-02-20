import * as fs from 'fs';
import * as path from 'path';
import { build } from 'esbuild';
import process from 'process';

// Find all component files to use as entry points
const componentsDir = './src/components';
const entryPoints = fs.readdirSync(componentsDir)
  .filter(file => file.endsWith('.ts'))
  .map(file => path.join(componentsDir, file));

// Build configuration
build({
  entryPoints,
  outdir: './build-output/components',
  bundle: true,
  minify: process.env.NODE_ENV === 'production',
  sourcemap: true,
  format: 'esm',
  target: ['es2020'],
  splitting: true,
  platform: 'browser',
  define: {
    'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV || 'development')
  },
  external: [], // Add any external packages that shouldn't be bundled
}).catch(() => process.exit(1));

