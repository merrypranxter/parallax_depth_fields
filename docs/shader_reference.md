# SHADER REFERENCE
## Complete Uniform & Parameter API for All Shaders

> *"Every parameter is a theory. Tune them until the theory matches what you feel."*

---

## UNIVERSAL UNIFORMS

All shaders in this repo share a consistent base uniform interface. If you're wiring these up yourself (WebGL, Three.js, ShaderToy), bind these first.

| Uniform | Type | Description |
|---------|------|-------------|
| `u_resolution` | `vec2` | Canvas size in pixels: `vec2(width, height)` |
| `u_time` | `float` | Elapsed time in seconds. Used for animation. |
| `u_mouse` | `vec2` | Mouse position in pixels: `vec2(x, y)`. Y=0 is bottom-left. |

**Important:** `u_mouse.y` is in screen-space pixels with Y=0 at the bottom. Normalize with `u_mouse / u_resolution` to get [0,1] UV space.

---

## `basic_parallax.glsl`

**Purpose:** Clean 5-plane depth composition with chromatic separation. The canonical starting point.

### Compile-time Constants

| Constant | Default | Range | Effect |
|----------|---------|-------|--------|
| `NUM_PLANES` | `5` | 2–12 | Number of depth layers composited. More = smoother depth |
| `FOCAL_DEPTH` | `0.5` | 0.0–1.0 | Which depth is sharpest. Overridden by mouse Y (50% blend) |
| `CHROMATIC_INTENSITY` | `0.8` | 0.0–2.0 | Strength of R/G/B channel separation |
| `PARALLAX_STRENGTH` | `0.12` | 0.0–0.5 | Displacement per depth unit |
| `MAX_BLUR` | `15.0` | 0.0–50.0 | Blur radius at maximum depth distance |
| `TIME_SCALE` | `1.0` | 0.0–5.0 | Animation speed multiplier |

### Interaction
- **Mouse Y** → shifts focal depth by 50% toward mouse position
- Chromatic channel offsets: R=+1.2×, G=+0.6×, B=−0.9×

### Output characteristics
- Procedural content (no textures required)
- 4-sample blur approximation (fast but approximate)
- Quadratic depth-of-field falloff
- CRT scanline overlay + vignette

---

## `depth_map_parallax.glsl`

**Purpose:** Production-ready shader driven by a real depth map texture. Drop-in for scene compositing.

### Textures

| Uniform | Type | Description |
|---------|------|-------------|
| `u_depthMap` | `sampler2D` | Grayscale depth: **white = near (0)**, **black = far (1)** |
| `u_colorTex` | `sampler2D` | The scene texture to apply chromatic displacement to |

*Note: if `u_colorTex` is not bound, falls back to procedural content.*

### Constants

| Constant | Default | Effect |
|----------|---------|--------|
| `FOCAL_DEPTH` | `0.5` | Focus depth in map space |
| `CHROMATIC_INTENSITY` | `0.9` | Separation strength |
| `PARALLAX_STRENGTH` | `0.15` | Displacement magnitude |
| `MAX_BLUR` | `12.0` | Max pixel blur radius |
| `BLUR_SAMPLES` | `8` | Poisson disc samples for DoF blur |

### Interaction
- **Mouse Y** → adjusts focal depth by 40%
- Edge enhancement: depth-edge discontinuities get extra chromatic halo (strength controlled by `CHROMATIC_INTENSITY`)

### Depth map conventions
```
White (1.0) = near camera (small depth value)
Black (0.0) = far from camera (large depth value)
```
This is the OpenGL convention (inverted from Direct3D). Flip with `depth = 1.0 - rawDepth` if needed.

---

## `hud_reticle.glsl`

**Purpose:** Multi-depth Terminator-style tracking reticles with lock-on animation and data readouts.

### Constants

| Constant | Default | Effect |
|----------|---------|--------|
| `NUM_RETICLES` | `3` | Number of simultaneous tracking reticles |
| `HUD_OPACITY` | `0.85` | Overall HUD alpha |
| `CHROMATIC_INTENSITY` | `0.7` | Chromatic split on reticle outlines |
| `GLITCH_AMOUNT` | `0.15` | Probability of per-frame corruption flash |
| `LOCK_SPEED` | `8.0` | How fast reticle snaps to lock-on state |

### Reticle layout (hardcoded, modify in `main()`)

| Index | Depth | Behavior |
|-------|-------|----------|
| 0 | 0.1 (near) | Follows mouse (85% weighted) |
| 1 | 0.45 (mid) | Drifts on sine path, semi-locked |
| 2 | 0.8 (far) | Fully locked — stationary orbit |

### Lock state
- `0.0` = tracking (spinning rotation ring, red color, wide chromatic split)
- `1.0` = locked (corner brackets appear, green color, no chromatic split, lock pulse)
- Interpolates smoothly between states

### Data readout
Each reticle displays a 2-digit distance readout (in pixel-art font) below the circle. Value fluctuates with `sin(time * 3.0 + depth) * 5.0`.

---

## `paradoxical_depth.glsl`

**Purpose:** Recursive depth layers containing each other. Chromatic aberration compounds with recursion.

### Constants

| Constant | Default | Effect |
|----------|---------|--------|
| `RECURSION_DEPTH` | `3.0` | How many recursion levels (keep ≤ 4 for performance) |
| `CHROMATIC_INTENSITY` | `1.5` | Per-level chromatic separation |
| `PARALLAX_STRENGTH` | `0.08` | Per-level displacement |
| `GLITCH_AMOUNT` | `0.3` | Probability a window shows the wrong recursion level |

### Interaction
- **Mouse Y** → selects which recursion level to "focus" on (0 = outermost, max = innermost)
- Global chromatic split oscillates with `sin(time * 0.5) * 0.02`

### Performance note
Each increment of `RECURSION_DEPTH` multiplies shader samples by approximately 3×. At depth=4 on a 1920×1080 canvas, this may drop below 30fps on integrated graphics.

---

## `emotional_depth.glsl`

**Purpose:** Emotional state as depth axis. Mouse is the "focus of attention" — nearby regions get high emotional intensity.

### Constants

| Constant | Default | Effect |
|----------|---------|--------|
| `EMOTION_INTENSITY` | `1.0` | Overall emotional scale |
| `CHROMATIC_GRIEF` | `1.2` | Grief → chromatic separation |
| `BLUR_NOSTALGIA` | `8.0` | Nostalgia (low emotion) → soft focus |
| `SHARP_ANGER` | `0.0` | Anger (high emotion) → no blur |
| `TREMBLE_ANXIETY` | `2.0` | Anxiety → screen tremor |

### Emotion-to-visual mapping

| Emotion value | Visual state | Color |
|---------------|-------------|-------|
| 0.0 (calm) | Soft, de-focused, nostalgic | Soft blue-grey |
| 0.25 (peace→joy) | Warm, brightening | Warm gold |
| 0.5 (sorrow) | Purple, mid-blur | Bruised purple |
| 0.75 (anger) | Sharp, oversaturated | Blood red |
| 1.0 (fear) | Trembling, sickly | Sickly teal |

### Interaction
- **Mouse position** → center of emotional intensity (things near mouse = high emotion)
- Heartbeat at `emotion * 4.0 Hz`

---

## `quantum_depth.glsl`

**Purpose:** Objects exist in multiple depth states until mouse hover collapses the wave function.

### Constants

| Constant | Default | Effect |
|----------|---------|--------|
| `NUM_STATES` | `4` | Depth eigenstates per object (Born rule superposition count) |
| `COLLAPSE_RADIUS` | `0.18` | Mouse proximity (UV) that triggers collapse |
| `CHROMATIC_INTENSITY` | `1.6` | High = more uncertainty = more chromatic smear |
| `PARALLAX_STRENGTH` | `0.12` | Per-eigenstate displacement |

### Physics model
- **Unobserved:** weighted blend of `NUM_STATES` depth eigenstates. Interference term: `cos(phase + n * π/2 + time * 0.8)`.
- **Observed:** snaps to chosen eigenstate near `baseDepth`.
- **Collapse radius:** smooth transition via `smoothstep(COLLAPSE_RADIUS, COLLAPSE_RADIUS * 0.25, mouseDist)`.
- 4 objects, slowly drifting on sine paths.

---

## `synesthetic_depth.glsl`

**Purpose:** Depth planes as musical notes. Visual frequencies = audio frequencies. The scene is a chord.

### Constants

| Constant | Default | Effect |
|----------|---------|--------|
| `NUM_PLANES` | `7` | Number of depth planes = notes in the chord |
| `CHROMATIC_INTENSITY` | `1.0` | Chromatic separation per plane |
| `BASE_TEMPO` | `0.8` | Slowest breath rate (Hz equivalent) |
| `PITCH_RATIOS` | `[1.0, 1.25, 1.5, 2.0, 2.5, 3.0, 4.0]` | Just intonation C major chord ratios |

### Scriabin color mapping

| Note | Color |
|------|-------|
| C | Red |
| D | Yellow |
| E | Pearl white |
| F | Dark red-violet |
| G | Orange |
| A | Green |
| B | Blue |

### Interaction
- **Mouse Y** → selects focal note (loudest plane)
- **Mouse X** → pitch bend (shifts spatial frequencies of all planes)
- Resonance filter Q = 2.5 (sharp note peaks)
- Beating effect when two notes are close in frequency

---

## `thermal_depth.glsl`

**Purpose:** FLIR/Predator thermal vision. Temperature = depth.

### Constants

| Constant | Default | Effect |
|----------|---------|--------|
| `FOCAL_TEMP` | `0.5` | Focus temperature [0=cold, 1=hot] |
| `THERMAL_NOISE` | `0.04` | Sensor noise (shot noise, uncooled FPA character) |
| `HEAT_SHIMMER` | `0.008` | Atmospheric distortion above hot surfaces |
| `SCAN_SPEED` | `0.5` | Rolling scan artifact speed |
| `MAX_BLUR` | `8.0` | Max blur (thermal sensors have lower resolution) |

### FLIR iron palette stops

| Value | Color | Temperature analog |
|-------|-------|-------------------|
| 0.0 | Black | Cold |
| 0.15 | Purple | Below ambient |
| 0.25 | Blue | Ambient |
| 0.40 | Cyan | Slightly warm |
| 0.50 | Green | Body temp |
| 0.65 | Yellow | Warm |
| 0.80 | Orange | Hot |
| 0.90 | Red | Very hot |
| 1.00 | White | Extreme heat |

### Interaction
- **Mouse Y** → shifts focal temperature (which temp is sharpest)
- Targeting reticle automatically tracks hottest detected source

---

## `anamorphic_depth.glsl`

**Purpose:** Anamorphic lens simulation. Horizontal FOV compressed. Oval bokeh. Horizontal lens flares.

### Constants

| Constant | Default | Effect |
|----------|---------|--------|
| `SQUEEZE_FACTOR` | `1.6` | Anamorphic squeeze ratio (1.33–2.0×) |
| `FOCAL_DEPTH` | `0.45` | Focus distance |
| `CHROMATIC_INTENSITY` | `0.9` | Chromatic separation |
| `PARALLAX_H` | `0.14` | Horizontal parallax strength |
| `PARALLAX_V` | `0.06` | Vertical parallax (smaller = more anamorphic compression) |
| `MAX_BLUR_H` | `30.0` | Bokeh width (oval — wider) |
| `MAX_BLUR_V` | `12.0` | Bokeh height (oval — shorter) |
| `FLARE_INTENSITY` | `0.6` | Anamorphic horizontal streak brightness |

### Interaction
- **Mouse Y** → focal depth control
- Two bright "sun" sources with horizontal flares
- Elliptical secondary ghost reflection

---

## `biological_parallax.glsl`

**Purpose:** Morphs between predator (binocular depth, tunnel vision) and prey (panoramic, flat) visual modes.

### Constants

| Constant | Default | Effect |
|----------|---------|--------|
| `THREAT_LEVEL` | `0.5` | Default mode blend (0=prey, 1=predator) |
| `CHROMATIC_INTENSITY` | `1.0` | Separation in predator mode |
| `MAX_BLUR` | `18.0` | DoF blur maximum |
| `FOCAL_DEPTH_PREY` | `0.5` | Prey focuses mid-field |
| `FOCAL_DEPTH_PRED` | `0.3` | Predator focuses near (threat) |

### Mode characteristics

| Parameter | Prey (0.0) | Predator (1.0) |
|-----------|-----------|----------------|
| FOV | ~180° (panoramic wrap) | ~70° (binocular) |
| Depth discrimination | Minimal | Deep stereo |
| Peripheral sharpness | Enhanced (motion alert) | Degraded |
| Color palette | Natural (grass, sky, bark) | IR-tinted (heat-coded) |
| Pupil | Wide (dilated, low contrast) | Narrow (tight vignette) |
| Chromatic aberration | Minimal (blue-yellow axis only) | Strong (red-near, blue-far) |

### Interaction
- **Mouse X** → threat level (left = peaceful prey, right = alert predator)
- Transition flash at 0.5 (moment of mode switch)
- Adrenaline chromatic shift at periphery under high threat

---

## `ufo_temporal.glsl`

**Purpose:** Time replaces space on the depth axis. Six temporal epochs composited by distance from "now."

### Constants

| Constant | Default | Effect |
|----------|---------|--------|
| `FOCAL_TIME` | `0.0` | Temporal focus (0=present) |
| `CHROMATIC_INTENSITY` | `1.2` | Temporal chromatic separation |
| `MAX_BLUR_PAST` | `25.0` | Past is very soft (old memories) |
| `MAX_BLUR_FUTURE` | `4.0` | Future is sharper but cold |
| `NUM_EPOCHS` | `6` | Temporal layers |

### Epoch mapping

| Epoch | Time | Visual content | Color treatment |
|-------|------|----------------|-----------------|
| 0 | Future (−ε) | Geometric grids, premonitions | UV-blue, cold |
| 1 | Present (0) | Night sky, UFO, tractor beam | Natural, sharp |
| 2 | Near past | 1970s landscape | Warm, analog film grain |
| 3 | Mid past | Medieval firelight | Ochre, umber |
| 4 | Deep past | Cave paintings (red ochre) | Pigment palette |
| 5 | Cosmic past | CMB noise | Purple-black static |

### Interaction
- **Mouse Y** → temporal focus (top=present, bottom=deep past)
- Past epochs: redshifted, desaturated with age (Hubble redshift analogy)
- Future epochs: blueshifted (Doppler approaching)
- Temporal stutter at epoch boundaries

---

## `apocalyptic_hud.glsl`

**Purpose:** Corrupted machine vision. Broken depth buffer. Horror HUD. Z-fighting as aesthetic.

### Constants

| Constant | Default | Effect |
|----------|---------|--------|
| `GLITCH_AMOUNT` | `0.55` | Overall corruption level [0=clean, 1=total chaos] |
| `CHROMATIC_INTENSITY` | `1.9` | Traumatic chromatic separation |
| `PARALLAX_STRENGTH` | `0.28` | Strong (wrong) depth displacement |
| `SCANLINE_DAMAGE` | `0.7` | Proportion of scanlines affected by damage |

### Corruption systems

1. **Depth spikes:** random pixels get wildly wrong depth values
2. **Row sync errors:** horizontal lines shift by random UV amounts  
3. **Block glitch:** NxN UV blocks teleport to new positions
4. **Z-bleeding:** depth values bleed across spatial neighbors
5. **Lost sync events:** periodic full-frame depth scramble
6. **Channel dropout:** red or blue channel drops to zero for one frame
7. **Corrupted glyphs:** HUD text in unreadable procedural script
8. **Dead zones:** regions of total signal loss

### No interaction
The apocalyptic HUD does not respond to mouse. The machine is not asking for your input.

---

## SHARED UTILITY FUNCTIONS

These functions appear (with identical or near-identical implementations) across all shaders:

### `float hash(vec2 p)`
2D → 1D pseudo-random hash. Output in [0,1].
```glsl
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
```

### `float noise(vec2 p)`
2D value noise (smooth interpolation). Output in [0,1].
Uses bilinear interpolation between hashed lattice points with smoothstep (`f = f*f*(3.0-2.0*f)`).

### `float fbm(vec2 p, int octaves)` *(some shaders)*
Fractional Brownian Motion — layered noise with decreasing amplitude.
```
output = Σ(i=0 to octaves-1) noise(p * 2^i) * 0.5^i
```

---

## PARAMETER QUICK-REFERENCE TABLE

| Parameter | `basic` | `depth_map` | `hud` | `paradox` | `emotion` | `quantum` | `synesthetic` | `thermal` | `anamorphic` | `biological` | `ufo` | `apocalyptic` |
|-----------|---------|-------------|-------|-----------|-----------|-----------|---------------|-----------|--------------|--------------|-------|---------------|
| Chromatic intensity | 0.8 | 0.9 | 0.7 | 1.5 | 1.2 | 1.6 | 1.0 | 0.3* | 0.9 | 1.0 | 1.2 | 1.9 |
| Parallax strength | 0.12 | 0.15 | — | 0.08 | — | 0.12 | 0.10 | 0.06 | 0.14 | 0.12 | 0.11 | 0.28 |
| Max blur | 15 | 12 | — | — | 8.0 | — | 0.4 | 8.0 | 30/12† | 18 | 25/4‡ | — |
| Depth planes | 5 | continuous | 3 | 3 | continuous | 4 | 7 | continuous | 6 | 5 | 6 | corrupted |
| Time scale | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
| Mouse control | focal Y | focal Y | position | level Y | focus XY | collapse XY | note Y, bend X | focal Y | focal Y | threat X | epoch Y | none |

*thermal doesn't separate RGB — low CA is correct  
†anamorphic: H=30, V=12 (oval bokeh)  
‡ufo: past=25, future=4 (asymmetric time blur)  

---

*See also: `implementation_guide.md` for wiring these into WebGL/Three.js.*
*See also: `optics_basics.md` for the physics behind the parameters.*
