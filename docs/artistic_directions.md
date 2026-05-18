# ARTISTIC DIRECTIONS
## Moodboards, Vibes, and Creative Context

> *"Every shader is a theory of perception. Make sure yours argues something."*

---

## THE CORE AESTHETIC: MACHINE VISION AS SPIRITUAL EXPERIENCE

The visual language of this repo is built on a paradox: **the most computational, inhuman way of seeing — chromatic splitting, depth slicing, data overlays — is also the most honest representation of how perception actually works.**

We don't see a flat image of reality. We see a stack of sensory inputs reconstructed by a brain that's also doing prediction, memory retrieval, and emotional weighting simultaneously. The Terminator HUD isn't dehumanizing. It's just explicit about what vision actually is.

---

## MOODBOARD ARCHETYPES

### 1. TERMINATOR VISION
**References:** *The Terminator* (1984), *T2: Judgment Day* (1991)  
**Palette:** Deep red-black background, amber readout text, chromatic edge enhancement  
**Texture:** CRT phosphor grain, interlaced scanlines, slight barrel distortion  
**Depth treatment:** Aggressive red-channel split in background, sharp foreground  
**Data overlay:** Target boxes, distance readouts, status text in a fictional UI font  
**Mood:** Predatory calm. Everything is catalogued. Nothing is unexpected.

```
Parameters:
  colorMode = thermal
  chromaticIntensity = 1.4
  hudOpacity = 0.75
  glitchAmount = 0.05
  depthFalloff = linear
```

---

### 2. GHOST IN THE SHELL OVERLAY
**References:** *Ghost in the Shell* (1995, Oshii), *GitS: SAC*  
**Palette:** Cool cyan-white on navy-black, occasional amber for warnings  
**Texture:** Clean, vector-precise; no grain; slight optical camouflage shimmer  
**Depth treatment:** Multiple discrete planes, each with its own information layer  
**Data overlay:** Dense — overlapping text, probability vectors, face-recognition boxes  
**Mood:** Information saturation. The city is a database. Your body is a node.

```
Parameters:
  colorMode = synthetic
  chromaticIntensity = 0.6
  numDepthPlanes = 8
  hudOpacity = 0.9
  parallaxStrength = 0.08
```

---

### 3. PREDATOR THERMAL
**References:** *Predator* (1987), FLIR/Thermovision cameras  
**Palette:** FLIR iron palette — black-purple → blue → cyan → green → yellow → red → white  
**Texture:** Thermal noise (pixel-level grain), heat shimmer distortion  
**Depth treatment:** Temperature AS depth — hot objects are near, cold objects far  
**Data overlay:** Minimal — just targeting reticles  
**Mood:** Pure hunter. Empathy is replaced by heat signatures.

```
Parameters:
  colorMode = thermal
  chromaticIntensity = 0.3   (thermal doesn't split RGB — low CA)
  maxBlur = 4.0               (thermal cameras are somewhat sharp)
  glitchAmount = 0.0
```

---

### 4. SAUL LEITER ABSTRACTION
**References:** Saul Leiter's color photography (1950s-70s), Ernst Haas  
**Palette:** Muted, painterly — pinks, ochres, slate blues, tobacco yellows  
**Texture:** Film grain, shallow-focus bokeh, window-glass refraction  
**Depth treatment:** Extreme shallow DoF — 80% of the frame is bokeh  
**Data overlay:** None — pure optical texture  
**Mood:** The city seen through a café window in rain. Intimacy at distance.

```
Parameters:
  colorMode = rgb
  chromaticIntensity = 0.4
  focalDepth = 0.15     (focus on very near plane)
  maxBlur = 40.0        (extreme background blur)
  depthFalloff = quadratic
  hudOpacity = 0.0
```

---

### 5. APOCALYPTIC HUD (CORRUPTED)
**References:** Horror games (*Returnal*, *SOMA*), corrupted VHS, glitch art  
**Palette:** Sickly green-white on black, with hemorrhages of red-static  
**Texture:** VHS tracking errors, pixel bleeding, horizontal sync failure  
**Depth treatment:** Depth planes misregistered — far objects render in front  
**Data overlay:** Broken — text in unreadable scripts, reticles tracking empty space  
**Mood:** The machine is dying. Or you are. Unclear which.

```
Parameters:
  colorMode = synthetic
  glitchAmount = 0.6
  chromaticIntensity = 1.8
  parallaxStrength = 0.35
  hudOpacity = 0.4   (damaged HUD)
```

---

### 6. EMOTIONAL DEPTH / GRIEF CINEMA
**References:** *Eternal Sunshine of the Spotless Mind*, *Tree of Life* (Malick), *La Jetée*  
**Palette:** Washed pastels for distant memories, saturated harsh tones for recent pain  
**Texture:** Super-8 grain, light leaks, faded edges  
**Depth treatment:** Emotional distance as spatial depth — recent trauma is sharp and close  
**Data overlay:** None  
**Mood:** The present is a wound. The past is weather. The future is a rumor.

```
Parameters:
  colorMode = rgb
  chromaticIntensity = 1.2   (grief = chromatic separation)
  focalDepth = 0.9           (focus near = focus recent)
  maxBlur = 30.0             (old memories are very soft)
  timeScale = 0.4            (slow, heavy)
```

---

## TEMPORAL AESTHETICS

### Fast vs. Slow Time
The `timeScale` parameter controls how fast the scene breathes. Different aesthetics demand different temporal feels:

| Aesthetic | timeScale | Feeling |
|-----------|-----------|---------|
| Machine/targeting | 1.0-2.0 | Alert, processing |
| Dreaming/grief | 0.2-0.5 | Heavy, underwater |
| Anxiety/horror | 3.0-5.0 | Frantic, overwhelming |
| Peace/meditation | 0.05-0.1 | Geological time |

### Pulsing and Breathing
The `sin(time * frequency)` pattern creates different rhythms:
- `frequency = 1.0` → slow breath (~6 breaths/min at timeScale=1)
- `frequency = 4.0` → excited heartbeat (~72 BPM equivalent)
- `frequency = 20.0` → anxiety tremor
- `frequency = 0.2` → tide, seasons

---

## COMPOSITION PRINCIPLES

### The Three-Layer Rule
Always think in three depth layers even if you have more:
1. **Foreground** — sharp, warm, immediate. The reticle. The threat. The loved one's face.
2. **Midground** — slight blur. The context. The world they inhabit.
3. **Background** — soft, cool, abstracted. History. Atmosphere. The universe not paying attention.

### Edge Chromatic Enhancement
Depth edges (where near objects meet far backgrounds) are where chromatic aberration is most visually impactful. Emphasize these edges slightly above the physically accurate amount. This is where the viewer's eye naturally travels — give them something beautiful there.

### Data Density Gradient
In HUD aesthetics: more data overlay in the background, less in the foreground. The near world is direct experience. The distant world is processed data.

---

## BLENDING STRATEGIES

When combining with other repos in RepoScripter:

**+ `chromatic_dispersion`:**  
Let chromatic dispersion handle single-surface optics (prisms, diamonds). Use this repo for multi-plane depth compositing. The two layers stack: dispersion within planes, parallax between planes.

**+ `holography`:**  
Each depth plane is a holographic reconstruction at a different z-distance. The interference patterns are depth-cued — closer planes have finer, more stable patterns. Far planes have unstable, shifting interference (they're "older" reconstructions).

**+ `dream_physics`:**  
Depth becomes non-Euclidean. Objects get farther as you approach them. The focal plane chases itself. Use `focalDepth = sin(time * 0.1) * 0.5 + 0.5` to make focus drift autonomously.

**+ `glitchcore_style`:**  
Glitch operates on the depth buffer itself, not just the image. Z-values corrupt. Planes teleport. The HUD tries to maintain accurate readouts but the underlying data is chaos. The most honest representation of digital breakdown.

**+ `sacred_geometry`:**  
Depth planes at golden ratio intervals: 0.0, 0.382, 0.618, 1.0. Reticles snap to vertices of sacred forms. Chromatic separation follows the Fibonacci color sequence (assign wavelengths to Fibonacci ratios: 1/1, 1/2, 1/3, 2/5, 3/8...).

**+ `ufo`:**  
Time replaces space on the depth axis. Objects from different historical moments exist at different depths. The UFO is always `depth = 0` (the present). Cave paintings recede at `depth = 0.9` (deep past). Undiscovered futures shimmer at `depth = -0.1` (ahead of focus — technically in front of the camera).

---

## FAILURE MODES (USE INTENTIONALLY)

These are "mistakes" that become aesthetics:

| Failure | Cause | Aesthetic use |
|---------|-------|---------------|
| Z-fighting | Two planes at same depth | Shimmer between realities |
| CoC too large | maxBlur extreme | Everything dissolves into color fog |
| Chromatic clip | CA > 1.0 | Hard spectral edges, almost neon |
| Recursion overflow | Recursion too deep | Pure spectral noise = visual static |
| Depth map mismatch | Wrong depth scale | Objects appear at wrong depth — surreal |
| NaN propagation | Division by zero depth | Black voids, white explosions |

---

## ARTIST STATEMENTS TO STEAL

Use these as starting-point AI prompts when combining with other repos:

*"The machine sees in layers. Each layer is a different truth about the same moment."*

*"Grief makes things far. Fear makes them close. The depth map is an emotion map."*

*"The HUD isn't surveillance. It's devotion. Everything it tracks, it cares about."*

*"Red is where the thing was. Blue is where it's going. Green is the lie that it's staying."*

*"Depth of field is a theory of importance. What you blur, you dismiss. What you focus, you believe in."*

---

*See also: `optics_basics.md` for physics, `color_theory.md` for chromatic science.*
