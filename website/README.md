# 🚀 Hur Delivery Website

> A high-end, beautifully animated landing page for the Hur Delivery app

![Status](https://img.shields.io/badge/status-production--ready-success)
![React](https://img.shields.io/badge/React-18.2-blue)
![Vite](https://img.shields.io/badge/Vite-5.1-646cff)
![License](https://img.shields.io/badge/license-MIT-green)

A professional, fully animated, and bilingual (Arabic/English) website showcasing the Hur Delivery platform with stunning visuals and smooth user experience.

## Features

- 🌍 **Bilingual Support**: Full Arabic and English translation with RTL layout
- 🎨 **Beautiful Animations**: Smooth, professional animations using Framer Motion
- 📱 **Fully Responsive**: Optimized for all screen sizes
- 🎯 **Modern Design**: Clean, contemporary UI with gradient effects
- ⚡ **High Performance**: Fast loading with optimized assets
- 🔄 **Interactive Components**: Engaging hover effects and transitions

## Tech Stack

- **React 18**: Modern React with hooks
- **Vite**: Lightning-fast build tool
- **Framer Motion**: Advanced animation library
- **i18next**: Internationalization
- **React Icons**: Beautiful icon library
- **Custom CSS**: Hand-crafted responsive styles

## Getting Started

### Prerequisites

- Node.js 18+ (recommended)
- npm or yarn

### Installation

1. Navigate to the website directory:
   ```bash
   cd website
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the development server:
   ```bash
   npm run dev
   ```

4. Open your browser to `http://localhost:3000`

### Build for Production

```bash
npm run build
```

The optimized production files will be in the `dist` directory.

### Preview Production Build

```bash
npm run preview
```

## Project Structure

```
website/
├── src/
│   ├── components/         # React components
│   │   ├── Navbar.jsx
│   │   ├── Hero.jsx
│   │   ├── Stats.jsx
│   │   ├── Features.jsx
│   │   ├── Values.jsx
│   │   ├── HowItWorks.jsx
│   │   ├── Testimonials.jsx
│   │   ├── CTA.jsx
│   │   ├── Footer.jsx
│   │   └── ParticlesBackground.jsx
│   ├── styles/             # Component styles
│   │   ├── Navbar.css
│   │   ├── Hero.css
│   │   ├── Stats.css
│   │   ├── Features.css
│   │   ├── Values.css
│   │   ├── HowItWorks.css
│   │   ├── Testimonials.css
│   │   ├── CTA.css
│   │   ├── Footer.css
│   │   └── ParticlesBackground.css
│   ├── i18n.js            # Translation configuration
│   ├── App.jsx            # Main app component
│   ├── main.jsx           # App entry point
│   └── index.css          # Global styles
├── index.html
├── vite.config.js
└── package.json
```

## Color Scheme

The website uses the same color scheme as the Hur Delivery app:

- **Primary**: #008C95 (Teal)
- **Secondary**: #1E40AF (Blue)
- **Success**: #10B981 (Green)
- **Warning**: #F59E0B (Orange)
- **Error**: #EF4444 (Red)

## Fonts

- **Arabic**: Cairo, Noto Sans Arabic, Tajawal
- **Latin**: System fonts with fallbacks

## Key Sections

1. **Hero Section**: Eye-catching introduction with animated phone mockup
2. **Stats Section**: Impressive numbers with animated counters
3. **Features Section**: Showcase of app capabilities with icons
4. **Values Section**: Core principles and values of the platform
5. **How It Works**: Step-by-step guide for users
6. **Testimonials**: User reviews and feedback
7. **CTA Section**: Call-to-action with download links
8. **Footer**: Contact info and social links

## Customization

### Changing Colors

Edit the CSS variables in `src/index.css`:

```css
:root {
  --color-primary: #008C95;
  --color-secondary: #1E40AF;
  /* ... other colors */
}
```

### Adding/Editing Translations

Edit `src/i18n.js`:

```javascript
const resources = {
  ar: {
    translation: {
      "key": "Arabic text"
    }
  },
  en: {
    translation: {
      "key": "English text"
    }
  }
};
```

### Modifying Animations

Animations are configured in component files using Framer Motion. Example:

```jsx
<motion.div
  initial={{ opacity: 0, y: 50 }}
  animate={{ opacity: 1, y: 0 }}
  transition={{ duration: 0.6 }}
>
  Content
</motion.div>
```

## Performance Tips

- Images are lazy-loaded
- Animations use GPU acceleration
- CSS is optimized with minimal repaints
- Production build is minified and tree-shaken

## Browser Support

- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)

## License

Part of the Hur Delivery project.

## Contact

For questions or support, contact the Hur Delivery team.

