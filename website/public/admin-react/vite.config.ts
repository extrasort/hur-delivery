import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { copyFileSync, existsSync } from 'fs'
import { resolve } from 'path'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    {
      name: 'copy-htaccess',
      closeBundle() {
        // Copy .htaccess file for Apache deployments (optional)
        try {
          copyFileSync(
            resolve(__dirname, 'public/.htaccess'),
            resolve(__dirname, '../admin/.htaccess')
          )
          console.log('✓ Copied .htaccess (Apache)')
        } catch (err) {
          console.warn('Warning: Could not copy .htaccess:', err)
        }

        // Copy Netlify/Vercel redirect helpers if present
        try {
          copyFileSync(
            resolve(__dirname, 'public/_redirects'),
            resolve(__dirname, '../admin/_redirects')
          )
          console.log('✓ Copied _redirects (SPA)')
        } catch (err) {
          console.warn('Warning: Could not copy _redirects file:', err)
        }

        // Duplicate index.html as 404/200 fallback for static hosting
        try {
          const outDir = resolve(__dirname, '../admin')
          const indexPath = resolve(outDir, 'index.html')
          const notFoundPath = resolve(outDir, '404.html')
          const spaPath = resolve(outDir, '200.html')

          if (existsSync(indexPath)) {
            copyFileSync(indexPath, notFoundPath)
            copyFileSync(indexPath, spaPath)
            console.log('✓ Generated SPA fallbacks (404.html & 200.html)')
          }
        } catch (err) {
          console.warn('Warning: Could not create SPA fallback files:', err)
        }
      }
    }
  ],
  build: {
    outDir: '../admin',
    emptyOutDir: true,
  },
  base: './',
})
