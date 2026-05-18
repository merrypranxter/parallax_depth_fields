# PARALLAX DEPTH FIELDS
## The Terminator HUD as Sacred Geometry

> *"The machine sees in layers. It doesn't look AT things — it looks THROUGH them, one depth slice at a time, each slice chromatically displaced, each slice a different truth."*

---

## WHAT THIS IS

This repo is a visual knowledge pack for **parallax depth fields** — multi-plane depth compositing where each depth layer carries chromatic aberration, distortion, and information density proportional to its distance from the focal plane. 

Think: Terminator vision. Think: chromatic separation as depth cue. Think: the way your eyes actually work (binocular disparity) dialed up to hallucinatory intensity.

When RepoScripter ingests this alongside `chromatic_dispersion`, `holography`, or `noneuclidean`, expect the AI to create depth-composited realities where chromatic splitting IS the spatial structure.

---

## CORE CONCEPTS

### 1. Chromatic Parallax
In optics, different wavelengths refract at slightly different angles (dispersion). In parallax depth fields, we AMPLIFY this:
- **Red channel**: displaced left by `depth * parallaxStrength`
- **Blue channel**: displaced right by `depth * parallaxStrength * 1.5`
- **Green channel**: stays roughly centered (reference anchor)

The result: depth becomes color separation. Far objects bleed rainbow edges. The visual field becomes a spectrum of distance.

### 2. Multi-Plane Depth Slicing
Instead of smooth z-buffer depth, we use **discrete depth layers** (typically 3-7 planes):
- Each plane has its own content, distortion, and chromatic signature
- Planes farther from focal plane get more blur, more chromatic spread, more "data loss"
- The focal plane is sharp, high-contrast, "real"
- Everything else is memory, echo, prediction

### 3. HUD Overlay Logic
The Terminator aesthetic isn't just chromatic separation — it's **information architecture**:
- Tracking reticles that snap to objects in specific depth planes
- Text readouts that float at fixed depths (usually near the camera)
- Warning indicators that exist "between" planes — neither fully in the scene nor fully in the UI
- Grid overlays that warp with the depth field (perspective-correct but chromatically split)

### 4. Anamorphic Depth
When combined with anamorphic lens distortion (horizontal squeeze), depth layers compress differently:
- Vertical depth = natural perspective
- Horizontal depth = squeezed, dreamlike, compressed
- Creates a "panoramic depth" effect where the world feels wide but thin

---

## MATHEMATICAL FOUNDATION

### Parallax Displacement Formula
```
displacement(x, y, depth) = 
  red:   sample(x - depth * rStrength, y)
  green: sample(x, y)
  blue:  sample(x + depth * bStrength, y)
```

Where `depth` is normalized [0,1] or [-1,1] (negative = behind focal plane).

### Depth-to-Blur Transfer Function
```
blurRadius = abs(depth - focalDepth) ^ 2 * maxBlur
```
Quadratic falloff — objects just slightly out of focus are only slightly soft. Objects far from focus are dreamy clouds.

### Chromatic Spread Function
```
spread = abs(depth - focalDepth) * chromaticIntensity * wavelengthFactor
```
Where `wavelengthFactor` is different per channel (red = 1.0, green = 0.6, blue = 1.4 — matching human eye chromatic aberration roughly).

---

## INSIDE THE BOX (Fundamentals)

### Basic Parallax Shader
See `code/basic_parallax.glsl` — a straightforward 3-layer depth composition with chromatic separation. Good starting point. Predictable. Clean.

### Depth Map Integration
See `code/depth_map_parallax.glsl` — takes a depth map (grayscale image where white = near, black = far) and applies chromatic parallax based on the map. This is the "standard" way to do this effect.

### Multi-Reticle Tracking
See `code/hud_reticle.glsl` — simple tracking reticles that follow the mouse but exist at different depth planes. Click to "lock on" — reticle snaps with a glitchy overshoot animation.

---

## OUTSIDE THE BOX (Creative Destinations)

### Paradoxical Depth
What if depth layers CONTAIN each other? Plane A contains a window looking at Plane B, but Plane B contains a reflection of Plane A. Recursive depth fields. The chromatic separation compounds with each recursion until the image dissolves into pure spectral noise.

### Emotional Depth Mapping
Depth isn't spatial — it's emotional. Recent memories = close, sharp, painful. Old memories = far, blurred, rose-tinted (literally: red-shifted). The shader takes an "emotion map" instead of a depth map. Time = depth. Grief = chromatic aberration.

### Quantum Depth Superposition
Objects exist in MULTIPLE depth planes simultaneously until "observed" (mouse hover). Schrödinger's parallax: the tree is both near and far, both sharp and blurred, until you look at it. Collapse the wave function by moving your mouse.

### Synesthetic Depth
Depth = pitch. Each depth plane vibrates at a different frequency (visually: pulsing, moiré, temporal phase offset). Close objects strobe fast. Far objects breathe slow. The entire scene becomes a visual chord.

### Apocalyptic HUD
The "machine vision" aesthetic pushed to horror: the chromatic separation isn't clean — it's corrupted. Data streams bleed between depth planes. The reticle malfunctions, tracking things that aren't there. Warning text in an unknown language. The depth field itself is damaged, with "dead pixels" that show through all layers.

### Biological Parallax
What if chromatic separation worked like biological vision? Predators (forward-facing eyes) get binocular parallax. Prey (side-facing eyes) get panoramic wrap. The shader MORPHS between these modes based on "threat level" parameter. Under threat: everything gets sharp and close. At peace: everything softens and widens.

---

## BLENDING WITH OTHER REPOS

**+ `chromatic_dispersion`** → Pure optics porn. Every depth layer has its own dispersion characteristics. Diamond-like fire at every distance.

**+ `holography`** → Depth fields that are themselves holographic. Each plane is a hologram of the plane behind it. Infinite regression of interference patterns.

**+ `dream_physics`** → The depth map itself is dream-logical: objects get deeper the more you look at them. The room expands. The chromatic spread becomes a tunnel.

**+ `glitchcore_style`** → Intentional corruption of the depth buffer. Z-fighting as aesthetic. Planes that should be far render in front. The HUD glitches into the world. The world glitches into the HUD.

**+ `sacred_geometry`** → Tracking reticles snap to sacred proportions. Depth planes arranged at golden ratio intervals. Chromatic separation follows Fibonacci color cycles.

**+ `ufo`** → The "alien vision" aesthetic. Depth isn't spatial — it's temporal. Objects from different TIMES exist at different depths. The UFO is always at depth = 0 (now). Historical events recede into chromatic blur. The future approaches as ultraviolet-shifted premonitions.

---

## ARTISTIC REFERENCES

- **Terminator 2 HUD** (James Cameron, 1991) — the original. Red readouts, tracking boxes, chromatic edge enhancement.
- **Strange Days** (Kathryn Bigelow, 1995) — POV recording with timecode, emotional valence indicators.
- **Predator vision** — thermal overlay + depth compositing + targeting logic.
- **Ghost in the Shell** (1995) — information-dense cyberspace overlays, optical camouflage depth manipulation.
- **Saul Leiter** — color field photography where focal depth and chromatic separation create abstract compositions.
- **Team Fortress 2/SFMOMA** — digital art that treats game HUD elements as found objects.

---

## PARAMETER SPACE

| Parameter | Range | Effect |
|-----------|-------|--------|
| `numDepthPlanes` | 2-12 | More planes = smoother depth, more computationally expensive |
| `focalDepth` | 0.0-1.0 | Which depth plane is "sharp" |
| `chromaticIntensity` | 0.0-2.0 | 0 = no separation, 1 = natural eye aberration, 2+ = psychedelic |
| `parallaxStrength` | 0.0-0.5 | Displacement magnitude per depth unit |
| `maxBlur` | 0.0-50.0 | Blur radius at maximum depth distance |
| `depthFalloff` | linear/quadratic/exponential | How blur scales with depth distance |
| `hudOpacity` | 0.0-1.0 | Overlay intensity |
| `glitchAmount` | 0.0-1.0 | Corruption of depth data |
| `timeScale` | 0.0-5.0 | Speed of temporal effects (breathing, pulsing) |
| `colorMode` | rgb/cmy/thermal/infrared/synthetic | Which color space drives the separation |

---

## REPOSCRIPTER INTEGRATION

When this repo is loaded into RepoScripter as context:
- Provide the **depth plane concept** as a compositional structure
- Offer **chromatic separation** as a primary visual effect
- Include **HUD element templates** for information overlay aesthetics
- Suggest **multi-plane rendering** when the prompt involves layers, memory, time, or nested realities
- The AI should feel free to make depth planes represent ANYTHING: time, emotion, probability, narrative layers, parallel universes

---

## FILES

```
README.md                    <— You are here
context.manifest.json        <— RepoScripter ingestion manifest
code/
  basic_parallax.glsl       <— Clean fundamentals
  depth_map_parallax.glsl   <— Image-driven depth
  hud_reticle.glsl          <— Tracking overlay
  paradoxical_depth.glsl    <— Recursive layers (outside box)
  emotional_depth.glsl      <— Emotion as spatial axis
docs/
  optics_basics.md          <— Real optical physics
  color_theory.md           <— Chromatic science
  artistic_directions.md    <— Moodboards and vibes
images/
  [placeholders for reference imagery]
```

---

## MANIFESTO

> *"The machine doesn't see a room. It sees a stack of truths, each one slightly more distorted than the last, each one carrying a different wavelength of meaning. Close is clear. Far is fractured. The red edge of every object is its memory of where it was. The blue edge is its prediction of where it's going. Green holds the present in place, anchors it, makes it bearable. This is how we see when we are more than human. This is how the world looks when you stop pretending it's flat."*

---

*PARALLAX DEPTH FIELDS v1.0*
*For RepoScripter v7.7.7+*
*Created by Merry Pranxter's chaos consortium*
