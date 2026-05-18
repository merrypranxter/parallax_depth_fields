# OPTICS BASICS
## The Real Physics Behind the Shaders

> *"Understanding the actual optics makes the distortions feel earned, not arbitrary."*

---

## CHROMATIC ABERRATION

### What It Is
Chromatic aberration occurs when a lens fails to focus all wavelengths of light to the same convergence point. Because different wavelengths travel at different speeds through glass (dispersion), they bend at slightly different angles (refraction).

### Two Types

**Longitudinal (axial) CA:**
- Different wavelengths focus at different distances along the optical axis
- Result: colored fringing on all edges, worst at center-to-edge
- Correction: apochromatic lenses (ED glass)

**Lateral (transverse) CA:**
- Different wavelengths focus at different distances from the optical axis
- Result: color fringing that gets worse toward the edges of the frame
- Correction: achromatic doublets (cemented elements)

### The Math
Refractive index *n* varies with wavelength *λ* (Cauchy's equation):

```
n(λ) ≈ A + B/λ² + C/λ⁴
```

For visible light:
- Red   (~700 nm) → lowest *n*, least bending
- Green (~550 nm) → middle *n*
- Blue  (~450 nm) → highest *n*, most bending

Abbe number *V* measures how much a material disperses light:
```
V = (n_yellow - 1) / (n_blue - n_red)
```
High *V* = low dispersion (good for lenses). Crown glass: V≈64. Flint glass: V≈36.

### In the Shaders
The GLSL shaders exaggerate this physically real effect. When `chromaticIntensity = 1.0`, the separation approximates a very fast, wide-angle lens (≈f/1.4, 24mm, full-frame). At `chromaticIntensity = 2.0`, you're in hallucination territory — physically impossible, aesthetically expressive.

---

## DEPTH OF FIELD

### What It Is
Only objects at the focus distance form a sharp image on the sensor/film. Objects closer or farther are imaged as blurred circles (bokeh circles). The size of the blur circle is called the **circle of confusion (CoC)**.

### The Thin Lens Equation
```
1/f = 1/d_o + 1/d_i
```
Where:
- *f* = focal length
- *d_o* = object distance
- *d_i* = image distance

### Circle of Confusion
```
CoC = |d_i - d_focus| * (aperture_diameter / d_i)
    = f² * |depth - focalDepth| / (N * focalDepth * (depth - f))
```
Simplified to: `CoC ∝ (depth - focalDepth)²` for small depth ranges.

This is the **quadratic falloff** used in the shaders:
```glsl
float blurRadius = abs(depth - FOCAL_DEPTH) * abs(depth - FOCAL_DEPTH) * MAX_BLUR;
```

### Depth of Field Limits
```
Near limit = f * d / (f + N * CoC_max * (d - f) / d)
Far  limit = f * d / (f - N * CoC_max * (d - f) / d)
```
When the far limit reaches infinity: **hyperfocal distance**.

### Bokeh Shape
Real lenses create bokeh circles whose shape depends on the aperture blades:
- Circular aperture → perfect circles
- Hexagonal aperture → hexagonal bokeh
- Anamorphic lenses → elongated ellipses (horizontal stretch)

---

## PARALLAX AND BINOCULAR VISION

### What It Is
**Parallax** is the apparent shift in position of an object when viewed from two different points. For human eyes:
- Baseline: ~65mm (interpupillary distance)
- Near objects: large parallax (large angular difference between eyes)
- Far objects: small parallax

### The Geometry
For an object at distance *d*, with eye baseline *b*, the parallax angle *θ* is:
```
θ ≈ b / d   (for d >> b)
```
The brain uses this to construct stereo depth perception.

### Chromatic Parallax (Artistic Extension)
The shaders extend this concept: instead of two viewpoints, each **wavelength** is treated as a separate "eye" displaced slightly from center. This gives depth information that's encoded in color rather than geometry.

```
red_sample_x   = x - depth * parallaxStrength * 1.2
green_sample_x = x - depth * parallaxStrength * 0.5
blue_sample_x  = x + depth * parallaxStrength * 0.9
```

The horizontal extent of red-to-blue fringing thus directly encodes depth.

---

## ANAMORPHIC OPTICS

### What It Is
Anamorphic lenses use cylindrical elements to squeeze a wider horizontal field of view onto a standard-aspect sensor. During projection, the image is "de-squeezed" to restore the wide aspect ratio.

**Effects of anamorphic optics:**
- **Horizontal lens flares** — the cylindrical element creates streaks across the frame
- **Oval bokeh** — out-of-focus highlights become horizontal ellipses
- **Barrel distortion** — more pronounced on the horizontal axis
- **Different depth perception** — horizontal and vertical parallax diverge

### In the Shaders
Anamorphic depth means `parallaxStrength.x ≠ parallaxStrength.y`. Horizontal displacement carries spatial meaning; vertical displacement is compressed. This creates the wide-but-thin "panoramic depth" aesthetic described in the README.

---

## LENS FLARE AND GHOSTING

### What It Is
Internal reflections between lens elements create secondary images (ghosts) and diffraction around bright sources (flare). These are not bugs — cinematographers deliberately choose lenses with interesting flare characteristics.

### Physics
- **Veiling glare**: diffuse scattering from lens coatings reduces contrast
- **Ghosts**: specular reflections between two lens surfaces create displaced, dimmer copies of bright sources
- **Diffraction spikes**: aperture blades create star-shaped spikes (even number of blades = 2× spikes)

---

## HUMAN EYE OPTICAL PROPERTIES

The human eye is not achromatic:
- **Chromatic aberration**: ~0.5 diopters difference between red and blue focus
- **Longitudinal CA**: blue focuses slightly in front of the retina compared to red
- We compensate for this unconsciously, but it contributes to the "warmth" we perceive in red objects

The brain prioritizes green for luminance (peak sensitivity at ~555 nm), which is why:
- Green holds the reference in the shaders (smallest displacement)
- Red and blue carry the depth-encoded offsets

This matches NTSC/sRGB luminance weights: Y = 0.299R + 0.587G + 0.114B.

---

## REAL-WORLD PARALLAX DEPTH APPLICATIONS

| Application | Depth Method | Chromatic Use |
|---|---|---|
| Cinema (3D) | Stereo baseline shift | None |
| LiDAR + camera fusion | Time-of-flight + RGB | None |
| Holography | Wavefront reconstruction | Interference patterns |
| Infrared night vision | IR depth + RGB overlay | Thermal false-color |
| Terminator HUD aesthetic | Simulated sensor fusion | Exaggerated CA as data |

---

*See also: `color_theory.md` for chromatic science, `artistic_directions.md` for creative context.*
