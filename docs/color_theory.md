# COLOR THEORY
## Chromatic Science for Parallax Depth Fields

> *"Color is distance. Wavelength is memory. The spectrum is a timeline."*

---

## THE VISIBLE SPECTRUM AS A SPATIAL AXIS

Standard chromatic aberration follows wavelength order:
```
VIOLET  BLUE  CYAN  GREEN  YELLOW  ORANGE  RED
380nm   450   490   550    580     620     700nm
  ←— bends most                bends least —→
```

In **chromatic parallax**, we hijack this axis and map it to depth:
- **Red → near** (warm, advancing colors)
- **Blue → far** (cool, receding colors)

This matches human perceptual tendencies: warm hues appear to advance, cool hues recede. The physics and psychology of color point in the same direction.

---

## COLOR MODELS IN DEPTH SHADERS

### RGB (Default)
Separate R, G, B channels carry different parallax displacements. Green is the anchor (reference, luminance-weighted). Red and blue diverge symmetrically.

Best for: general purpose, Terminator/HUD aesthetics

### CMY (Subtractive)
Complementary mapping — cyan recedes, magenta holds center, yellow advances. Feels more painterly, less digital.

Best for: watercolor/film noir aesthetics, analog camera effects

### Thermal
Depth is mapped to temperature-coded color:
```
Cold (far) → Black → Blue → Cyan → Green → Yellow → Red → White (near/hot)
```
Exact temperature-luminance curves from FLIR/Thermovision cameras.

Best for: Predator vision, surveillance aesthetic, infrared compositing

### Infrared
Real IR photography characteristics:
- Foliage → nearly white (high IR reflectance)
- Sky → very dark
- Skin tones → very light, luminous
- Depth haze reduces contrast and shifts cool
Combine with depth for "thermal distance" rendering.

### Synthetic
Arbitrary — assign any color mapping. Useful when the "depth signal" encodes something other than physical distance (emotion, time, probability — see `emotional_depth.glsl`).

---

## THE OPPONENT COLOR MODEL

Human color perception is organized around three opponent channels:
- **Light-Dark** (L-D): luminance axis
- **Red-Green** (R-G): opposing hues
- **Blue-Yellow** (B-Y): opposing hues

This matters for chromatic aberration perception: R-G separation is most jarring to the human eye because it conflicts with a primary opponent channel. B-Y separation feels dreamier, less alarming.

| Effect | Opponent channel exploited |
|--------|---------------------------|
| Anger, urgency | R-G split (maximum perceptual conflict) |
| Nostalgia, soft memory | B-Y drift |
| Alien/synthetic | Non-opponent: pure spectral (700nm vs 400nm) |

---

## COLOR TEMPERATURE AND DEPTH

In real photography, **atmospheric perspective** makes distant objects:
1. Lower in contrast
2. Bluer (sky scatter adds blue haze)
3. Lighter in tonal value

This is why the conventional depth-to-color mapping works psychologically:
```
Near:  High contrast + warm color temperature (~3200K)
Far:   Low contrast + cool color temperature (~8000K)
```

The shaders approximate this by mixing toward a "sky tint" color at high depth values.

---

## CHROMATIC SPREAD MATHEMATICS

### Per-Channel Wavelength Factors
Derived from glass dispersion curves (Cauchy coefficients for borosilicate):

| Channel | Wavelength | Relative refraction | Shader factor |
|---------|-----------|---------------------|---------------|
| Red     | 656nm     | 1.000               | 1.0           |
| Green   | 546nm     | 1.032               | 0.6 (anchor)  |
| Blue    | 486nm     | 1.058               | 1.4           |

In the shaders, these factors govern how far each channel displaces from center:
```glsl
float rFactor = 1.2;   // Red diverges right
float gFactor = 0.5;   // Green stays near center
float bFactor = -0.9;  // Blue diverges left (opposite direction)
```

### Spread Function
```glsl
spread = abs(depth - focalDepth) * chromaticIntensity * wavelengthFactor
```

### Compounding in Recursive Layers
In `paradoxical_depth.glsl`, each recursion level adds its own displacement. After *n* levels:
```
totalSpread ≈ spread × Σ(i=1 to n) factor^i ≈ spread / (1 - factor)  [for factor < 1]
```
This geometric series converges if the per-level factor < 1.0. At exactly 1.0, the series diverges to spectral noise — the desired "dissolve" aesthetic at max recursion.

---

## FALSE COLOR PALETTES

### Terminator Red
```
Background: #000000 — #0a0000 (near-black)
Primary:    #cc1a00 — #ff3300 (blood orange-red)
Highlight:  #ff9900 — #ffcc00 (amber data readouts)
Accent:     #ffffff — #ffeecc (hot white for near-field objects)
```

### Machine Vision (cool)
```
Background: #000508 — #001015
Primary:    #00b4cc — #00e5ff (electric cyan)
Highlight:  #80ffcc — #ffffff
Accent:     #0044ff (blue for distance data)
```

### Emotional Depth Palette
Based on color psychology research (Itten, Albers):
```
Peace/Far:  #b2ccd4 — #7fa8b5  (desaturated blue-grey)
Joy:        #f5d67a — #f0b93b  (warm gold)
Sorrow:     #9966bb — #6633aa  (bruised purple)
Anger:      #e61a2d — #cc0011  (blood red)
Fear:       #33cc99 — #1ab585  (sickly teal-green)
```

### Thermal (FLIR Standard)
```
0°C:   #000000 → #1a0066 (black-purple)
20°C:  #0033cc → #0099ff (cold blue)
37°C:  #00cc66 → #cccc00 (transition green/yellow)
50°C:  #ff6600 → #ff0000 (hot orange-red)
100°C: #ffffff            (white hot)
```

---

## SATURATION AND DEPTH

A counterintuitive but effective technique: **increase saturation with depth distance** (the opposite of atmospheric perspective). This creates a hyper-saturated background that reads as "synthetic" or "machine-rendered" — the machine sees more color at distance, not less. It has more perfect sensors.

Blend factor:
```glsl
float syntheticSat = 1.0 + abs(depth - focalDepth) * 1.5;
vec3 grey = vec3(dot(color, vec3(0.299, 0.587, 0.114)));
color = mix(grey, color, syntheticSat);
```

---

## COLORBLINDNESS CONSIDERATIONS

Standard red-green chromatic parallax is invisible to deuteranopes and protanopes (~8% of males). If accessibility matters, use the **Blue-Yellow** axis for primary depth encoding instead:
```glsl
float bFactor = 1.4;   // Blue: far
float yFactor = -0.9;  // Yellow (negative blue channel): near
float gFactor = 0.3;   // Green: anchor
```

---

*See also: `optics_basics.md` for physical optics, `artistic_directions.md` for visual moodboards.*
