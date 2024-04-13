// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const colors = require('tailwindcss/colors');

const subtleColor = "#E5E7EB";

module.exports = {
  darkMode: 'class',
  content: [
    '**/*.erb',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/javascript/**/*.js'
  ],
  theme: {
    fontFamily: {
      sans: ["'DM Sans'", 'sans-serif'],
      serif: ["'DM Sans'", 'sans-serif'],
    },
    extend: {

      colorsDisabled: {
        cyan: '#9cdbff',
        //gray: grayColors,
      },
      colors: {

        emphasis: "var(--rau-bg-emphasis)",
        default: "var(--rau-bg, white)",
        subtle: "var(--rau-bg-subtle)",
        muted: "var(--rau-bg-muted)",
        inverted: "var(--rau-bg-inverted)",
        info: "var(--rau-bg-info)",
        success: "var(--rau-bg-success)",
        attention: "var(--rau-bg-attention)",
        error: "var(--rau-bg-error)",
        darkerror: "var(--rau-bg-dark-error)",
        
        transparent: 'transparent',
        current: 'currentColor',
        black: colors.black,
        white: colors.white,
        gray: colors.zinc,
        indigo: colors.indigo,
        red: colors.rose,
        green: colors.emerald,
        yellow: colors.amber,
        brand: {
          /*50: "#faf5ff",
          100: "#f3e8ff",
          200: "#e9d5ff",
          300: "#d8b4fe",
          400: "#c084fc",
          500: "#a855f7",
          600: "#9333ea",
          700: "#7e22ce",
          800: "#6b21a8",
          900: "#581c87",*/
          /*50:  "#fff7ed",
          100: "#ffedd5",
          200: "#fed7aa",
          300: "#fdba74",
          400: "#fb923c",
          500: "#f97316",
          600: "#ea580c",
          700: "#c2410c",
          800: "#9a3412",
          900: "#7c2d12"*/
          /*50:  "#000",
          100: "#000",
          200: "#000",
          300: "#000",
          400: "#000",
          500: "#000",
          600: "#000",
          700: "#000",
          800: "#000",
          900: "#000"*/

          50:  "#fdf2f8",
          100: "#fce7f3",
          200: "#fbcfe8",
          300: "#f9a8d4",
          400: "#f472b6",
          500: "#ec4899",
          600: "#db2777",
          700: "#be185d",
          800: "#9d174d",
          900: "#831843",
          950: "#500724"
        }
      },

      borderColor: {
        emphasis: "var(--rau-border-emphasis, #9CA3AF)",
        default: "var(--rau-border, #D1D5DB)",
        subtle: `var(--rau-border-subtle, ${subtleColor})`,
        muted: "var(--rau-border-muted, #F3F4F6)",
        booker: `var(--rau-border-booker, ${subtleColor})`,
        error: "var(--rau-border-error, #AA2E26)",
      },
      textColor: {
        emphasis: "var(--rau-text-emphasis, #111827)",
        default: "var(--rau-text, #374151)",
        subtle: "var(--rau-text-subtle, #6B7280)",
        muted: "var(--rau-text-muted, #9CA3AF)",
        inverted: "var(--rau-text-inverted, white)",
        info: "var(--rau-text-info, #253985)",
        success: "var(--rau-text-success, #285231)",
        attention: "var(--rau-text-attention, #73321B)",
        error: "var(--rau-text-error, #752522)",
        //brand: "var(--rau-brand-text,'white')",
      },
    }
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/typography'),
  ]
}
