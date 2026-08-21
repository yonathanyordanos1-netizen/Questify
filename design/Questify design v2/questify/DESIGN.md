---
name: Questify
colors:
  surface: '#f7f9fc'
  surface-dim: '#d8dadd'
  surface-bright: '#f7f9fc'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f7'
  surface-container: '#eceef1'
  surface-container-high: '#e6e8eb'
  surface-container-highest: '#e0e3e6'
  on-surface: '#191c1e'
  on-surface-variant: '#594139'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eff1f4'
  outline: '#8d7168'
  outline-variant: '#e1bfb5'
  surface-tint: '#ab3500'
  primary: '#ab3500'
  on-primary: '#ffffff'
  primary-container: '#ff6b35'
  on-primary-container: '#5f1900'
  inverse-primary: '#ffb59d'
  secondary: '#565e74'
  on-secondary: '#ffffff'
  secondary-container: '#dae2fd'
  on-secondary-container: '#5c647a'
  tertiary: '#515f74'
  on-tertiary: '#ffffff'
  tertiary-container: '#8c9ab1'
  on-tertiary-container: '#243245'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdbd0'
  primary-fixed-dim: '#ffb59d'
  on-primary-fixed: '#390c00'
  on-primary-fixed-variant: '#832600'
  secondary-fixed: '#dae2fd'
  secondary-fixed-dim: '#bec6e0'
  on-secondary-fixed: '#131b2e'
  on-secondary-fixed-variant: '#3f465c'
  tertiary-fixed: '#d5e3fc'
  tertiary-fixed-dim: '#b9c7df'
  on-tertiary-fixed: '#0d1c2e'
  on-tertiary-fixed-variant: '#3a485b'
  background: '#f7f9fc'
  on-background: '#191c1e'
  surface-variant: '#e0e3e6'
typography:
  display:
    fontFamily: Plus Jakarta Sans
    fontSize: 48px
    fontWeight: '800'
    lineHeight: '1.1'
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '800'
    lineHeight: '1.2'
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '800'
    lineHeight: '1.2'
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: '1.3'
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.6'
  label-bold:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: 0.02em
  button:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '600'
    lineHeight: '1'
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 8px
  sm: 16px
  md: 24px
  lg: 40px
  xl: 64px
  gutter: 16px
  margin-mobile: 20px
  container-max: 1200px
---

## Brand & Style
The design system is built on a **Modern-Gamified** aesthetic. It bridges the gap between high-performance productivity tools and the engaging feedback loops of RPG interfaces. The personality is energetic, encouraging, and high-contrast, designed to make mundane tasks feel like meaningful progression.

The style utilizes **Clean Minimalism** as a foundation to prevent cognitive overload, layered with **Tactile/High-Contrast** elements that provide a sense of physical interaction. Surfaces are crisp, whitespaces are generous, and action elements are bold to drive user momentum.

## Colors
The palette is centered around **questOrange**, a high-energy primary hue used exclusively for interactive "quest" actions and progress indicators. 

- **Primary (questOrange):** Used for primary calls to action, active states, and critical progress milestones.
- **Surface (Background):** A cool-toned off-white (#F4F6F9) that reduces glare and allows orange elements to pop.
- **Typography:** Deep slate (#0F172A) provides maximum legibility for headers, while a softer slate (#475569) manages secondary metadata.
- **Functional Accents:** Success Green is used for "Quest Complete" states, and a vibrant Purple is reserved for Experience Point (XP) rewards.

## Typography
This design system uses **Plus Jakarta Sans** for its friendly yet precise geometric construction. 

Headings must use **ExtraBold (800)** or **Bold (700)** weights to establish an authoritative, "heroic" hierarchy. Body text remains light and airy to balance the visual weight of the headings. All button labels use **SemiBold (600)** for optimal readability against high-contrast backgrounds. For mobile displays, headline sizes scale down significantly to preserve screen real estate for task lists.

## Layout & Spacing
The layout follows a **Fluid Grid** model with a hard 4px baseline rhythm. 

- **Desktop:** 12-column grid with 24px gutters. Content is contained within a 1200px max-width wrapper.
- **Mobile:** 4-column grid with 16px gutters and 20px side margins.
- **Logic:** Vertical spacing between unrelated quest categories should use `lg` (40px), while items within a list use `sm` (16px) to maintain grouping. Cards and interactive modules should use `md` (24px) internal padding to feel spacious and premium.

## Elevation & Depth
Depth is conveyed through **Tonal Layering** and **Soft Ambient Shadows**. 

1.  **Level 0 (Floor):** The background (#F4F6F9).
2.  **Level 1 (Cards):** White (#FFFFFF) surfaces with a very subtle, diffused shadow (0px 4px 20px rgba(15, 23, 42, 0.05)).
3.  **Level 2 (Interactive):** Primary buttons and active quest items use a more pronounced shadow to appear "lifted" and ready for interaction.

Avoid heavy black shadows; use the primary text color (#0F172A) at very low opacities (5-8%) to tint shadows for a more natural, modern look.

## Shapes
The shape language is **Rounded and Friendly**, moving away from clinical sharp corners to emphasize the gamified nature of the app.

- **Primary Buttons:** Fixed at **16px** corner radius to create a soft, approachable "clicky" feel.
- **Small Icons/Badges:** Use **10px** corner radius to maintain consistency at smaller scales.
- **Containers/Cards:** Use **24px** (rounded-xl) for large dashboard cards to create a distinct frame for quests.

## Components
- **Primary Buttons:** 16px corner radius, Background: `questOrange`, Text: White. On hover, apply a subtle scale-up (1.02x) to mimic a physical button.
- **Quest Cards:** White background, 24px corner radius, Level 1 shadow. Include a 4px thick vertical accent bar on the left edge using `questOrange` for active quests.
- **Chips/Tags:** 10px corner radius, light version of the category color (e.g., 10% opacity Orange) with bold 12px text.
- **Progress Bars:** 8px height, rounded caps. Background: `questSecondaryText` at 10% opacity; Fill: `questOrange`.
- **Input Fields:** 12px corner radius, 2px border in `neutral_color`. On focus, the border transitions to `questOrange`.
- **XP Toast:** A specialized notification component using the `accent_xp` purple, floating at Level 2 elevation to celebrate achievement.