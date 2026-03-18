/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: '#FF8200',   // Ivory Coast Orange
        secondary: '#009A44', // Ivory Coast Green
        accent: '#FFD215',    // Yellow Accent
        cta: '#FF8200',       // Call to Action (Orange)

        background: '#FAF9F6',// Off-white
        dark: '#0A1A18',      // Dark Green/Black
        text: '#000000',      // Pure Black for neobrutalism
      },
      fontFamily: {
        heading: ['Outfit', 'sans-serif'],
        body: ['Outfit', 'sans-serif'],
      },
    },
  },
  plugins: [],
}

