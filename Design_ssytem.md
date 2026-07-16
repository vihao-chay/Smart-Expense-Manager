---
name: Smart Expense Manager
colors:
  surface: '#f7faf8'
  surface-dim: '#d7dbd9'
  surface-bright: '#f7faf8'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f1f4f3'
  surface-container: '#ebefed'
  surface-container-high: '#e5e9e7'
  surface-container-highest: '#e0e3e1'
  on-surface: '#181c1c'
  on-surface-variant: '#3e4947'
  inverse-surface: '#2d3130'
  inverse-on-surface: '#eef1f0'
  outline: '#6e7977'
  outline-variant: '#bdc9c6'
  surface-tint: '#006a63'
  primary: '#005c55'
  on-primary: '#ffffff'
  primary-container: '#0f766e'
  on-primary-container: '#a3faef'
  inverse-primary: '#80d5cb'
  secondary: '#006b5f'
  on-secondary: '#ffffff'
  secondary-container: '#6df5e1'
  on-secondary-container: '#006f64'
  tertiary: '#0c5b56'
  on-tertiary: '#ffffff'
  tertiary-container: '#2f746f'
  on-tertiary-container: '#b3f7f0'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#9cf2e8'
  primary-fixed-dim: '#80d5cb'
  on-primary-fixed: '#00201d'
  on-primary-fixed-variant: '#00504a'
  secondary-fixed: '#71f8e4'
  secondary-fixed-dim: '#4fdbc8'
  on-secondary-fixed: '#00201c'
  on-secondary-fixed-variant: '#005048'
  tertiary-fixed: '#abefe8'
  tertiary-fixed-dim: '#8fd3cc'
  on-tertiary-fixed: '#00201e'
  on-tertiary-fixed-variant: '#00504b'
  background: '#f7faf8'
  on-background: '#181c1c'
  surface-variant: '#e0e3e1'
typography:
  display-currency:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 28px
  title-md:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  container-padding: 16px
  gutter: 12px
---

## Brand & Style
The design system is centered on **Modern Fintech Minimalism**, specifically tailored for a younger demographic that values efficiency and clarity. The aesthetic balances the rigor of financial management with a friendly, approachable interface. 

The visual style utilizes a "Soft Corporate" approach—borrowing the reliability of traditional banking but stripping away the density in favor of high whitespace, clear information hierarchy, and smooth transitions. The UI should evoke a sense of calm control over one's finances, using subtle depth and soft geometry to make complex data feel digestible.

## Colors
The palette is built on a foundation of deep teals and clean neutrals. 

- **Primary Tones:** Used for brand actions, active states, and focus areas.
- **Semantic Colors:** Critical for financial feedback. Income (#22C55E) and Expense (#EF4444) are used with high intentionality—only for amounts and trend indicators to prevent visual fatigue.
- **Surface Strategy:** In Light Mode, we use a cool-gray background (#F8FAFC) to let white surface cards pop. In Dark Mode, the background shifts to a deep navy (#0F172A) with slightly lifted slate surfaces (#1E293B) to maintain depth without harsh pure-black contrasts.

## Typography
Inter is used across the system for its exceptional legibility in data-dense environments. 

- **Currency Formatting:** The `display-currency` role is critical for the VND format (e.g., 12.500.000 ₫). It uses a heavy weight and tighter letter spacing to ensure large numbers feel contained and impactful.
- **Hierarchy:** Bold headlines provide a strong anchor for page sections, while Secondary Text color is applied to `body-md` and `label-md` roles to signify metadata (like transaction dates or categories).
- **Scale:** On mobile devices, headlines downscale to maintain comfortable line lengths and prevent layout breaking with large currency strings.

## Layout & Spacing
This design system utilizes a **4-pixel baseline grid** for internal component spacing and an **8-pixel rhythm** for layout-level spacing.

- **Mobile Constraints:** The standard container margin is 16px. Elements within cards should use 12px or 16px padding.
- **Grouping:** Use 8px (sm) for related elements (e.g., an icon and its text label) and 16px (md) or 24px (lg) to separate distinct sections of the dashboard.
- **Fluidity:** Cards and input fields should expand to the full width of the container minus margins to maximize tap targets for mobile users.

## Elevation & Depth
Depth is communicated through **Tonal Layers** supplemented by **Ambient Shadows**.

- **Level 0 (Background):** The base layer (#F8FAFC).
- **Level 1 (Cards):** Surface color (#FFFFFF) with a very soft, diffused shadow: `0px 4px 12px rgba(15, 23, 42, 0.05)`. This creates a floating effect without looking heavy.
- **Level 2 (Active/Modals):** Used for bottom sheets and snackbars. These should have a more pronounced shadow to indicate they sit high above the interface.
- **Dark Mode Adjustment:** In dark mode, shadows are replaced with subtle inner borders (1px) or slight increases in surface lightness to indicate elevation, as shadows are less effective on dark backgrounds.

## Shapes
The shape language is "Rounded-Soft."

- **Cards & Containers:** Use a 16px radius (`rounded-lg`) as the standard. This matches the friendly, modern aesthetic while remaining professional.
- **Buttons:** Primary buttons use a 12px radius. Smaller interactive elements like chips use 8px or a full pill shape.
- **Inputs:** Text fields follow the card radius at 12px to maintain a consistent visual rhythm within forms.

## Components
Consistent styling across Material 3 components ensures the app feels native yet branded.

- **Cards:** The primary container for transactions and budget summaries. Always use a 16px corner radius and Level 1 elevation.
- **Buttons:** 
  - *Primary:* Solid #0F766E with white text, 12px radius, minimum height of 48px.
  - *Secondary:* Ghost style with Primary color border and text.
- **Chips:** Used for transaction categories (e.g., "Food", "Transport"). Use a light tint of the primary color or semantic colors with a 20% opacity background.
- **Input Fields:** Filled style with a 1px border (#E2E8F0). On focus, the border transitions to Primary (#0F766E) with a 2px thickness.
- **Lists:** Transaction lists should use "Standard List Items" from M3 but with increased vertical padding (12px) and no dividers; use whitespace or subtle background shifts instead.
- **Progress Bars:** For budget tracking, use thick (8px) bars with rounded caps. The track should be a light neutral and the fill should use the Primary or Semantic color depending on budget health.