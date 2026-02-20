import * as fs from 'fs';
import { spawn } from 'child_process';

console.log('Watching for changes...');

// Watch the src directory
fs.watch('./src', { recursive: true }, (eventType, filename) => {
  if (filename && filename.endsWith('.ts')) {
    console.log(`File ${filename} changed, rebuilding...`);
    const build = spawn('node', ['esbuild.config.js'], { stdio: 'inherit' });
    
    build.on('close', (code) => {
      if (code !== 0) {
        console.error(`Build process exited with code ${code}`);
      } else {
        console.log('Build completed successfully');
      }
    });
  }
});

