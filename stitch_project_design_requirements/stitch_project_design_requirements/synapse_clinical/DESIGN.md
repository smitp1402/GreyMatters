# Design System Specification: The Cognitive Sanctuary

## 1. Overview & Creative North Star
The "Creative North Star" for this design system is **The Cognitive Sanctuary**. In the high-stakes environment of neuro-educational feedback, the UI must act as a silent partner—minimizing cognitive load while providing surgical precision. We are moving away from the "gamified" clutter of traditional ed-tech and toward a "Clinical-Editorial" hybrid. 

This design system breaks the standard template look by merging the high-tech utility of a surgical HUD with the authoritative, immersive feel of an academic journal. We achieve this through:
*   **Intentional Asymmetry:** Using unbalanced layouts to guide the eye toward "Primary Learning Layers."
*   **Tonal Depth:** Replacing harsh lines with sophisticated, layered surface shifts.
*   **Typographic Duality:** A sharp contrast between the technical (Sans-serif) and the academic (Serif).

## 2. Colors & Surface Philosophy
The palette is rooted in deep, immersive tones that favor focus over distraction. 

### The Foundation
*   **Background (`#131313`):** The absolute base. It represents the "void" of distraction.
*   **Focus Blue (`primary`: `#acc7ff`):** Used as a laser-focused accent. It should draw the eye only to interactive elements or high-priority focus metrics.
*   **Flow Green (`secondary_container`: `#3a4a5f` variants):** Utilized for success and "In-Zone" states.
*   **Amber Drift (`tertiary`: `#fbbc00`):** Specifically for intervention. It is soft but distinct, signaling a need for refocus without triggering an "error" response.

### The "No-Line" Rule
Sectioning must never be achieved via 1px solid borders. Boundaries are defined through background shifts. For example, a content area using `surface-container-low` should sit directly on the `surface` background. The change in hex code provides enough "retinal separation" without creating the visual noise of a border.

### Surface Hierarchy & Nesting
Treat the UI as a series of stacked sheets of high-grade material.
1.  **Level 0:** `surface` (#131313) - The primary canvas.
2.  **Level 1:** `surface-container-low` (#1c1b1b) - Main content areas or sidebars.
3.  **Level 2:** `surface-container-high` (#2a2a2a) - Interactive cards or data HUDs.
4.  **Level 3:** `surface-container-highest` (#353534) - Context menus or active states.

### The "Glass & Gradient" Rule
To elevate the "Clinical" feel, floating HUD elements should use **Glassmorphism**. Apply a background blur (16px–24px) to `surface_variant` at 60% opacity. For primary CTAs, use a subtle linear gradient from `primary` to `primary_container` (angled at 135°) to provide a "spectral glow" that feels high-tech and premium.

## 3. Typography
The system employs a dual-typeface strategy to separate the "Functional UI" from the "Knowledge Layer."

### Functional UI (Inter)
*   **Display/Headline:** Use `display-md` (2.75rem) for critical focus scores. The Inter typeface provides a clean, neutral, and data-driven aesthetic.
*   **Labels:** `label-md` and `label-sm` are strictly for HUD metrics and navigation, keeping the UI tight and efficient.

### The Learning Layer (Newsreader)
*   **Body-LG/MD:** All educational content (the "Primary Learning Layer") must be set in **Newsreader**. This serif choice mimics traditional school texts and high-end editorial journals, signaling to the brain that it is time for deep, academic absorption. 
*   **Title-LG/MD:** Use these for article headers to create an authoritative, "library-like" atmosphere within the tech-heavy interface.

## 4. Elevation & Depth
We eschew traditional drop shadows in favor of **Tonal Layering**.

*   **The Layering Principle:** Place a `surface-container-lowest` card on a `surface-container-low` section. The subtle contrast creates a natural "lift" that mimics ambient studio lighting.
*   **Ambient Shadows:** If an element must float (e.g., an intervention alert), use an extra-diffused shadow: `offset: 0 12px, blur: 40px, color: rgba(0, 0, 0, 0.4)`. 
*   **The "Ghost Border":** For complex data cards where tonal shifts aren't enough, use a Ghost Border: `outline-variant` (#414754) at **15% opacity**. This provides a hint of structure without the "boxed-in" feeling of a standard UI.

## 5. Components

### Circular Gauges (Focus Scores)
*   **Visual Style:** High-precision, thin-stroke rings using `primary` for the active state and `surface-container-highest` for the track.
*   **Interaction:** Use a soft "glow" (outer shadow) in the `primary` color when a user hits a "Flow State."

### Data-Rich Cards
*   **Styling:** No dividers. Use `surface-container-high` background.
*   **Spacing:** Use generous padding (1.5rem / 24px) to separate metrics. High-contrast typography (`on-surface` for values, `on-surface-variant` for labels) creates the hierarchy.

### Buttons
*   **Primary:** `surface-tint` background with `on-primary` text. Use `rounded-md` (0.375rem) for a professional, slightly sharp edge.
*   **Secondary:** No background. Use a "Ghost Border" (outline-variant at 20%) that becomes 100% opaque on hover.

### Inputs & HUD Elements
*   **HUD Elements:** Minimal, floating, and semi-transparent. Labels should be in `label-sm` to maintain a "clinical tool" aesthetic.
*   **Inputs:** Use `surface-container-lowest` for the field background to create a "recessed" look, making the interactive area feel tactile.

## 6. Do's and Don'ts

### Do:
*   **Embrace Negative Space:** Allow the serif learning content to "breathe" with wide margins, contrasting with the dense, technical HUD on the periphery.
*   **Use Subtle Transitions:** Color shifts between `surface` tiers should be felt rather than immediately seen.
*   **Prioritize Legibility:** Ensure Newsreader body text always sits on a high-contrast background (e.g., `on-surface` text on `surface-container-low`).

### Don't:
*   **Don't use 1px solid borders:** This is the quickest way to make a high-end system look like a generic dashboard.
*   **Don't use pure black (#000000):** It is too harsh for an EEG platform and causes eye strain. Stick to the `surface` (#131313) foundation.
*   **Don't mix font roles:** Never use Newsreader (Serif) for functional UI buttons or Inter (Sans) for long-form educational reading. The psychological separation is key to the system's success.