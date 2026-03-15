# AGENTS.md

This file provides instructions for AI coding agents on how to work with this project.

## Project Overview

This is a SvelteKit application for an event calendar. It uses TypeScript, Prettier, and ESLint for code quality, and Tailwind CSS v4 for styling. The backend is powered by PocketBase.

## Build and Test Commands

This project uses `pnpm` as the package manager and `devenv` for the development environment.

All commands should be prefixed with `devenv shell --` to run them in the proper environment.

- **Install dependencies:** `devenv shell -- pnpm install`
- **Run development server:** `devenv shell -- pnpm dev`
- **Build for production:** `devenv shell -- pnpm build`
- **Lint and format:** `devenv shell -- pnpm lint`
- **Check for type errors:** `devenv shell -- pnpm check`

## Code Style

- **Tabs:** Use tabs for indentation.
- **Quotes:** Use single quotes.
- **Trailing Comma:** No trailing commas.
- **Print Width:** 100 characters.
- **Formatting:** Use `devenv shell -- pnpm format` to format the code.

## Tailwind CSS v4 Configuration

This project uses **Tailwind CSS v4**, which has a different configuration approach than v3:

- **Theme configuration:** Colors and design tokens are defined in `src/app.css` using the `@theme` directive, NOT in `tailwind.config.js`
- **Config file purpose:** The `tailwind.config.js` file is only used for content paths (where to scan for classes)
- **Utility generation:** The `@theme` block automatically generates utility classes like `bg-primary-500`, `text-brand-primary`, etc.
- **CSS-first approach:** All theme customization is done in CSS files using `@theme` blocks

### Adding New Colors

To add new colors that generate utility classes:

1. Add them to the `@theme` block in `src/app.css`:
   ```css
   @theme {
   	--color-my-color: #hexvalue;
   }
   ```
2. This automatically generates utilities: `bg-my-color`, `text-my-color`, `border-my-color`, etc.
3. Do NOT add colors to `tailwind.config.js` - they will be ignored

### Current Color Palette

- **Primary colors** (dark violet): `primary-50` through `primary-900` (generates `bg-primary-*`, `text-primary-*`, etc.)
- **Brand colors**: `brand-primary`, `brand-secondary`, `brand-accent`, `brand-dark`, `brand-highlight`

## Security Considerations

- The application uses PocketBase for the backend, which is hosted at `https://data.palikkaharrastajat.fi`. Ensure that the PocketBase security rules are properly configured to prevent unauthorized access to data.
- Authentication is handled via OAuth2 with an OIDC provider. The authentication logic is in `src/lib/auth.ts`.
- When making changes to the authentication or data access logic, be sure to test thoroughly to prevent security vulnerabilities.
