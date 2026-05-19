# ANIMATION TECHNIQUES
## Temporal Patterns, Breathing, Heartbeat, and Tremor

> *"Static is a lie. Everything alive breathes. Even the things that aren't alive anymore."*

---

## THE CORE LANGUAGE OF TEMPORAL ANIMATION

All animation in these shaders derives from `u_time` — a monotonically increasing float representing elapsed seconds. From this single value, you can generate every biological, mechanical, and emotional rhythm.

The key functions:

| Function | Shape | Use |
|----------|-------|-----|
| `sin(t * f)` | Smooth oscillation | Breathing, gentle pulsing |
| `sin(t * f) * 0.5 + 0.5` | Remapped to [0,1] | Non-negative oscillation |
| `pow(sin(t*f), n)` | Narrow spike at peak | Heartbeat, blink |
| `fract(t * f)` | Sawtooth | Scan lines, counting |
| `mod(t, period)` | Periodic reset | Beat intervals |
| `step(threshold, hash(...))` | Random binary event | Glitch triggers |
| `smoothstep(0,1, fract(...))` | Smooth periodic ramp | Breathing expansion |
| `floor(t * f)` | Discrete time steps | Frame-rate-locked effects |

---

## BIOLOGICAL RHYTHMS

### Breathing (0.3–0.5 Hz)

The slowest, most universal biological rhythm. Use for:
- Shader overall scale pulsing (vignette expanding/contracting)
- Depth of field shifting (breathing as focus change)
- Saturation and brightness oscillation

```glsl
// Slow, organic breath — mimics 0.3 Hz (2 breaths per minute, deep sleep)
float breath = sin(u_time * 0.3 * 6.28318) * 0.5 + 0.5;

// Awake breathing — 0.3 Hz (18 breaths/min)
float wakeBreath = sin(u_time * 1.884) * 0.5 + 0.5;

// Make it feel like a real breath: slower inhale, faster exhale
// Use asymmetric function: cubic ease out
float breathCycle = fract(u_time * 0.25);  // 0.25 Hz = 15 breaths/min
float exhale = breathCycle < 0.4 ?
    smoothstep(0.0, 0.4, breathCycle) :           // Slow inhale (40%)
    1.0 - smoothstep(0.4, 1.0, breathCycle);      // Faster exhale (60%)

// Application: vignette breathing
float vigRadius = 0.5 + exhale * 0.15;
float vig = 1.0 - dot(centered, centered) * vigRadius;
```

### Heartbeat (60–180 BPM)

Sharp, double-peak, then silence. The hardest rhythm to fake convincingly.

```glsl
// Single sharp beat at ~70 BPM (1.17 Hz)
float beatPhase = fract(u_time * 1.17);    // One beat every 0.85 seconds
float beat1 = exp(-pow((beatPhase - 0.1) * 30.0, 2.0));   // First peak (systole)
float beat2 = exp(-pow((beatPhase - 0.22) * 40.0, 2.0)) * 0.4;  // Second peak (diastole)
float heartbeat = beat1 + beat2;

// Application: subtle red-channel pulse (blood flow)
color.r += heartbeat * 0.08 * emotion;

// Anxiety: 140 BPM
float anxietyBeat = fract(u_time * 2.33);
float fastBeat = pow(sin(anxietyBeat * 3.14159), 12.0);  // Narrower peaks

// Application: screen brightness flicker
color *= 1.0 + fastBeat * 0.05 * anxietyLevel;
```

### Eye saccade and blink

```glsl
// Blink: every 4-6 seconds, black flash lasting ~150ms
float blinkInterval = 5.0;
float blinkPhase = fract(u_time / blinkInterval);
float blink = 1.0 - smoothstep(0.0, 0.03, blinkPhase)  // Close: fast (50ms)
                  * smoothstep(0.05, 0.03, blinkPhase); // Open: slower (100ms)
color *= blink;

// Microsaccade: constant high-frequency tiny jitter during fixation
float saccadeX = (noise(vec2(u_time * 8.0, 1.7)) - 0.5) * 0.002;
float saccadeY = (noise(vec2(u_time * 7.3, 8.2)) - 0.5) * 0.002;
vec2 saccadeUV = uv + vec2(saccadeX, saccadeY);
```

### Adrenaline / arousal response

When threat level rises, temporal patterns accelerate and amplify:

```glsl
// All rhythms scale with arousal
float arousal = smoothstep(0.0, 1.0, threatLevel);  // [0,1]

float baseBreathHz = 0.25;       // Rest
float maxBreathHz  = 0.5;        // Panic
float breathHz = mix(baseBreathHz, maxBreathHz, arousal);
float arousedBreath = sin(u_time * breathHz * 6.28318) * 0.5 + 0.5;

float baseBPM   = 60.0;         // Rest
float maxBPM    = 180.0;        // Fight/flight
float heartHz   = mix(baseBPM, maxBPM, arousal) / 60.0;
float beatPhase = fract(u_time * heartHz);
float arousedBeat = pow(sin(beatPhase * 3.14159), 12.0);
```

---

## MACHINE / MECHANICAL RHYTHMS

### Scan-line roll

Classic CRT/radar/FLIR artifact: a bright line rolls up the screen.

```glsl
// Rolls at 0.5 Hz (every 2 seconds)
float scanPos  = fract(u_time * 0.5);
float scanLine = smoothstep(0.008, 0.0, abs(uv.y - scanPos));

// Multiple scan lines (like interlace)
float scanMulti = sin(uv.y * u_resolution.y * 0.5 + u_time * 30.0) * 0.03 + 0.97;
color *= scanMulti;

// Thermal FLIR scan (horizontal, not vertical)
float thermalScan = smoothstep(0.005, 0.0, abs(uv.x - fract(u_time * 0.3)));
color += thermalScan * vec3(0.3, 0.8, 0.4) * 0.05;
```

### Radar sweep

```glsl
// Rotating sweep line
float sweepAngle = u_time * 1.0;  // 1 revolution per second
vec2 centered = uv - 0.5;
float angle = atan(centered.y, centered.x);
float r = length(centered);

// "Afterglow" sweep trail
float angleDiff = mod(angle - sweepAngle, 6.28318);
float sweep = exp(-angleDiff * 3.0) * smoothstep(0.5, 0.1, r);
color += sweep * vec3(0.0, 0.8, 0.2) * 0.3;
```

### Clock tick

Discrete, step-function time. Data readouts that update every N frames.

```glsl
float tickRate = 4.0;  // 4 updates per second
float ticked = floor(u_time * tickRate) / tickRate;  // Quantized time

// Use ticked instead of u_time for display values that should snap to new values
float displayValue = floor(mix(0.0, 99.0, noise(vec2(ticked, 0.0))));
```

### Data stream / teletype

```glsl
// Characters revealed one at a time (typewriter effect)
float charReveal = fract(u_time * 8.0);  // 8 chars/second

// Column-by-column reveal
float col = floor(uv.x * 40.0);  // 40-column text field
float revealedCols = u_time * 8.0;
float charAlpha = step(col, revealedCols);
```

---

## EMOTIONAL TEMPORAL PATTERNS

### Grief (slow, irregular, unpredictable)

```glsl
// Grief has no regular rhythm — it comes in waves, then goes quiet
float griefWave  = noise(vec2(u_time * 0.15, 3.7));  // Slow, irregular
float griefSurge = smoothstep(0.6, 0.9, griefWave);  // Only the high points
float griefFade  = exp(-u_time * 0.01) + 0.1;         // Time heals (slightly)

// Grief tremor: involuntary fine shaking during surge
vec2 griefTremor = vec2(
    noise(vec2(u_time * 15.0, 0.3)),
    noise(vec2(u_time * 12.0, 7.1))
) * griefSurge * 0.006;
```

### Dissociation (too-smooth, too-slow, floating)

```glsl
// Time feels wrong: too slow and perfectly smooth
float dissoTime  = pow(fract(u_time * 0.05), 0.3);   // Eased time — "drag"
float dissoBob   = sin(dissoTime * 6.28318 * 2.0) * 0.008;  // Gentle float

// Everything is slightly behind — lag
vec2 laggedUV = uv + (uv - 0.5) * dissoBob;  // Subtle inward pull
```

### Euphoria (fast, bright, overcrowded)

```glsl
// Multiple fast rhythms in constructive interference
float e1 = sin(u_time * 5.3) * 0.5 + 0.5;
float e2 = sin(u_time * 7.1) * 0.5 + 0.5;
float e3 = sin(u_time * 3.7) * 0.5 + 0.5;

// Moments when all three peak together: euphoric flash
float euphoriaPeak = e1 * e2 * e3;
color += euphoriaPeak * 0.2 * vec3(1.0, 0.9, 0.5);  // Warm bright flash

// Chromatic aberration modulated by euphoria
float euphoricCA = 0.3 + euphoriaPeak * 1.5;
```

### Paranoia (random jerks, wrong timing)

```glsl
// Random directional jumps — the world is wrong
float parantTime = floor(u_time * 6.0);  // 6 random events per second
float parantH = hash(vec2(parantTime, 1.0)) - 0.5;
float parantV = hash(vec2(parantTime, 2.0)) - 0.5;

// Only large events matter (threshold the randoms)
float paranShift = step(0.35, abs(parantH));
vec2 paranJitter = vec2(parantH, parantV) * paranShift * 0.015;
```

---

## DEPTH-SPECIFIC TEMPORAL EFFECTS

### Focal plane breathing

The focus point itself drifts over time — creates organic, eye-like attention shifts.

```glsl
// Slow focus wander — 0.1 Hz
float focalBreath = sin(u_time * 0.628) * 0.15 + 0.5;  // [0.35, 0.65]

// Add micro-tremor for realism
float focalTremor = noise(vec2(u_time * 2.0, 5.5)) * 0.02;

float focal = focalBreath + focalTremor;
```

### Chromatic pulse

Chromatic aberration that pulses on a beat:

```glsl
float beatPhase  = fract(u_time * 1.2);
float chromPulse = exp(-beatPhase * 4.0);  // Sharp decay after beat
float chromIntensity = 0.5 + chromPulse * 1.0;  // [0.5, 1.5]
```

### Depth plane interference (Z-fighting rhythm)

Two planes at similar depths create rhythmic visibility swaps:

```glsl
float planeA = 0.5;
float planeB = 0.5 + 0.01 * sin(u_time * 8.0);  // Plane B oscillates above/below A

// When planeA and planeB are almost equal, they "fight"
float fighting = exp(-pow((planeA - planeB) * 100.0, 2.0));
color = mix(colorA, colorB, fighting * (sin(u_time * 20.0) * 0.5 + 0.5));
```

### Time-of-day depth shift

For scenes that span diurnal cycles, depth perception changes with light:

```glsl
float dayPhase = fract(u_time * 0.02);  // 50-second day cycle

float sunAngle  = dayPhase * 6.28318;
float sunHeight = sin(sunAngle);  // -1 = midnight, +1 = noon

// Chromatic intensity: higher at dawn/dusk (golden hour)
float goldenHour = 1.0 - abs(sunHeight);  // Max when sun is at horizon
float chromaticIntensity = 0.5 + goldenHour * 1.5;

// Focal depth: closer at night (pupil dilated, hyperfocal near), farther at noon
float focal = mix(0.3, 0.6, sunHeight * 0.5 + 0.5);
```

---

## TEMPORAL LAYERING

Multiple rhythms at different scales create organic, non-repetitive animation:

### The harmonic stack

```glsl
// Base: geological breathing (very slow)
float geo     = sin(u_time * 0.05)  * 0.4 + 0.6;

// Mid: weather-scale shifts (slow)
float weather = sin(u_time * 0.3 + 1.0) * 0.3 + 0.7;

// Fast: human-scale breathing
float body    = sin(u_time * 1.6 + 2.0) * 0.2 + 0.8;

// Instantaneous: nervous system
float nerve   = noise(vec2(u_time * 8.0, 3.3)) * 0.1 + 0.9;

// Combine: multiply for modulation (or add for layering)
float totalAnim = geo * weather * body * nerve;
```

### Breaking the repetition

Pure sine waves feel mechanical after a few cycles. Add:

```glsl
// 1. Phase modulation: the period itself oscillates
float modFreq = 1.6 + sin(u_time * 0.12) * 0.3;  // Wobbling frequency
float wobble  = sin(u_time * modFreq);

// 2. Amplitude envelope: long-period gain changes
float gain    = 0.5 + noise(vec2(u_time * 0.04, 0.0)) * 0.5;
float signal  = sin(u_time * 2.0) * gain;

// 3. Phase randomization: occasional reset
float resetT  = floor(u_time * 0.1);             // Reset every 10 seconds
float phase   = hash(vec2(resetT, 7.7)) * 6.28318;  // Random phase after reset
float reset   = sin(u_time * 2.0 + phase);
```

---

## TRANSITION ANIMATIONS

### Fade in/out

```glsl
// Fade in over 2 seconds at shader start
float fadeIn   = smoothstep(0.0, 2.0, u_time);

// Fade to specific color (e.g., "wake" from black)
color *= fadeIn;

// Cross-fade between two states
float t        = smoothstep(0.0, 1.0, u_time / transitionDuration);
color          = mix(colorA, colorB, t);
```

### Glitch transition

```glsl
// Glitch burst when transitioning between states
float glitchT = smoothstep(0.0, 0.1, transitionProgress) *
                (1.0 - smoothstep(0.1, 0.2, transitionProgress));
// Peak at middle of transition (10-20% complete)

float glitchShift = (hash(uv + u_time) - 0.5) * glitchT * 0.1;
vec2 glitchedUV = uv + vec2(glitchShift, 0.0);
```

### Lock-on snap (used in `hud_reticle.glsl`)

```glsl
// Overshoot spring animation
float target = 1.0;  // where we're snapping to
float current = 0.0;

// Simulate spring: overshoots then settles
float springT = 1.0 - exp(-LOCK_SPEED * deltaTime);
float spring  = mix(current, target, springT);

// The overshoot: add decaying oscillation
float overshoot = exp(-LOCK_SPEED * u_time * 0.5) * sin(u_time * LOCK_SPEED * 2.0) * 0.15;
float animated  = spring + overshoot;
```

---

## PARAMETER CHEATSHEET

| Effect | Formula | `timeScale` | Notes |
|--------|---------|-------------|-------|
| Geological breath | `sin(t*0.05)*0.4+0.6` | 0.05 | Mountains breathing |
| Deep sleep breath | `sin(t*0.2)*0.3+0.7` | 0.2 | |
| Resting breath | `sin(t*1.6)*0.2+0.8` | 1.6 | 15/min |
| Excited breath | `sin(t*3.2)*0.25+0.75` | 3.2 | 30/min |
| Resting heartbeat | `exp(-pow(fract(t*1.2)-0.1, 2.0)*400.0)` | 1.2 | 72 BPM |
| Fast heartbeat | `exp(-pow(fract(t*2.5)-0.1, 2.0)*400.0)` | 2.5 | 150 BPM |
| Anxiety tremor | `noise(uv*100.0+t*20.0)*0.003` | 20.0 | |
| Slow blink | `smoothstep(0.0,0.03,fract(t/5.0))*(1.0-smoothstep(0.05,0.03,fract(t/5.0)))` | 1/5 | 12/min |
| LED blink | `step(0.5, sin(t*4.0)*0.5+0.5)` | 4.0 | Binary |
| Scan line | `fract(t*0.5)` | 0.5 | Roll |
| Glitch event | `step(0.97, hash(vec2(floor(t*5.0), 0.0)))` | 5.0 | 5/sec |

---

*See also: `shader_reference.md` for `TIME_SCALE` parameter usage per shader.*
*See also: `artistic_directions.md` for which temporal patterns match which aesthetic moods.*
