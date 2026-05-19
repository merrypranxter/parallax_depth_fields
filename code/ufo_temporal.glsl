// UFO TEMPORAL DEPTH — Time as the Depth Axis
// The depth map doesn't encode space. It encodes time.
// depth = 0 (focal plane) = NOW.
// depth → 1 = past receding into chromatic blur.
// depth < 0 (behind focal = depth clamped at 0 edge) = future approaching as
//            ultraviolet-shifted premonitions.
//
// Objects from different historical moments coexist in the frame at once.
// The UFO is always at depth = 0 (the present moment).
// Cave paintings recede at depth ≈ 0.9 (deep past, rose-tinted, soft).
// Undiscovered futures shimmer at the near edge (UV-blue, crisp, ominous).
//
// "Time is depth. The past is out of focus.
//  The future is too sharp — it hasn't learned to blur yet."

precision highp float;

uniform vec2  u_resolution;
uniform float u_time;
uniform vec2  u_mouse;

// PARAMETERS
const float FOCAL_TIME         = 0.0;     // 0 = present. Positive = past-focused.
const float CHROMATIC_INTENSITY = 1.2;
const float PARALLAX_STRENGTH   = 0.11;
const float MAX_BLUR_PAST        = 25.0;  // Past is soft
const float MAX_BLUR_FUTURE      = 4.0;   // Future is crisp but cold
const float TIME_SCALE           = 1.0;
const int   NUM_EPOCHS           = 6;     // Temporal layers

// ---- Noise ------------------------------------------------------------------

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5, f = 1.0;
    for (int i = 0; i < 4; i++) { v += noise(p * f) * a; a *= 0.5; f *= 2.1; }
    return v;
}

// ---- Epoch content generators -----------------------------------------------
// Each epoch has its own visual language matching its "time period"

// EPOCH 0: Future (depth < 0, but we clamp at 0 boundary)
// Cold, geometric, impossibly precise — things that haven't happened yet
vec3 futureContent(vec2 uv, float time) {
    // Perfect, eerie grids — geometric structures not yet built
    float gridX = abs(sin(uv.x * 40.0)) ;
    float gridY = abs(sin(uv.y * 40.0));
    float grid  = pow(max(gridX, gridY), 15.0) * 0.6;

    float n = noise(uv * 8.0 + time * 0.3);

    // UV-shifted palette: ultraviolet-blue-white. Future is cold and electric.
    vec3 base = vec3(0.05, 0.10, 0.25) + n * 0.1;
    base += grid * vec3(0.2, 0.5, 1.0);

    // Premonition flicker: brief flashes of clarity
    float premonition = step(0.97, noise(uv * 3.0 + time * 2.0)) * 0.3;
    base += premonition * vec3(0.8, 0.9, 1.0);

    return base;
}

// EPOCH 1: Present (depth ≈ 0) — the NOW layer
// UFO: hovering, present, undeniable
vec3 presentContent(vec2 uv, float time) {
    float n1 = fbm(uv * 2.5 + time * 0.05);
    float n2 = noise(uv * 6.0 - time * 0.07);

    // Night sky, dark ground
    float horizon = smoothstep(0.40, 0.55, uv.y + n1 * 0.03);
    vec3 sky   = vec3(0.02, 0.03, 0.08) + n2 * 0.03;
    vec3 ground = vec3(0.08, 0.10, 0.06) + n1 * 0.05;
    vec3 base  = mix(ground, sky, horizon);

    // Stars
    float starField = step(0.97, hash(floor(uv * 200.0) * 7.13 + 3.77));
    float starBlink = sin(time * (hash(floor(uv * 200.0)) * 4.0 + 1.0)) * 0.3 + 0.7;
    base += starField * starBlink * 0.8;

    // UFO: metallic disc at present-moment depth = 0
    vec2 ufoPos = vec2(0.5 + sin(time * 0.08) * 0.12, 0.55 + sin(time * 0.12) * 0.02);
    vec2 ufoP   = (uv - ufoPos) * vec2(u_resolution.x / u_resolution.y, 1.0);
    // Disc shape: squashed ellipse
    float ufoDist = length(ufoP * vec2(1.0 / 0.12, 1.0 / 0.04));
    float ufoBody = smoothstep(1.0, 0.7, ufoDist);
    // Dome on top
    float domeDist = length((ufoP - vec2(0.0, 0.025)) * vec2(1.0 / 0.05, 1.0 / 0.035));
    float dome     = smoothstep(1.0, 0.6, domeDist);

    // UFO lights: rotating, colored
    float lightAngle = atan(ufoP.y, ufoP.x) + time * 1.5;
    float lights = step(0.7, abs(sin(lightAngle * 8.0))) * smoothstep(0.8, 0.4, ufoDist) * 0.5;

    vec3 ufoColor = mix(vec3(0.7, 0.75, 0.8), vec3(1.0, 0.9, 0.6), lights);
    base = mix(base, ufoColor, max(ufoBody, dome) * 0.9);

    // Tractor beam: below the UFO
    float beamX  = abs(uv.x - ufoPos.x) * (u_resolution.x / u_resolution.y);
    float beamY  = smoothstep(ufoPos.y - 0.2, ufoPos.y, uv.y) * (1.0 - smoothstep(ufoPos.y - 0.01, ufoPos.y + 0.02, uv.y));
    float beamW  = 0.04 + (ufoPos.y - uv.y) * 0.2;
    float beam   = smoothstep(beamW, 0.0, beamX) * beamY * 0.4;
    base        += beam * vec3(0.5, 1.0, 0.4) * (0.5 + 0.5 * sin(time * 5.0 - uv.y * 20.0));

    return base;
}

// EPOCH 2: Near past — 1970s
// Warm, analog, slightly washed out. Film grain. Earth tones.
vec3 nearPastContent(vec2 uv, float time) {
    float n = fbm(uv * 3.0 + time * 0.04);
    float n2 = noise(uv * 7.0 + time * 0.02);

    // 70s palette: avocado, burnt orange, harvest gold
    vec3 avocado  = vec3(0.52, 0.55, 0.25);
    vec3 orange   = vec3(0.78, 0.40, 0.12);
    vec3 gold     = vec3(0.85, 0.70, 0.25);

    vec3 col = mix(avocado, orange, smoothstep(0.3, 0.7, n));
    col = mix(col, gold, smoothstep(0.6, 0.9, n2));

    // Warm tint, film fade
    col *= 0.8 + 0.3 * n;
    col  = mix(col, vec3(0.85, 0.78, 0.65) * 0.3, 0.25);   // Faded film base

    return col;
}

// EPOCH 3: Mid past — medieval
// Ochre, umber, stone grey. No electricity. Firelight.
vec3 midPastContent(vec2 uv, float time) {
    float n = fbm(uv * 2.0 + time * 0.02);
    float fire = fbm(uv * 10.0 + vec2(0.0, time * 1.0)) * 0.5;

    vec3 stone = vec3(0.45, 0.40, 0.32);
    vec3 fire3 = vec3(0.90, 0.40, 0.05);
    vec3 dark  = vec3(0.12, 0.08, 0.05);

    vec3 col = mix(dark, stone, n);
    // Fire sources: bright spots
    float fireSrc = smoothstep(0.6, 1.0, fbm(uv * 3.0 + time * 0.1));
    col = mix(col, fire3, fireSrc * 0.6);

    return col * (0.7 + fire * 0.5);
}

// EPOCH 4: Deep past — prehistoric
// Ochre pigments on cave walls. Red hands. Bison silhouettes.
vec3 deepPastContent(vec2 uv, float time) {
    float n = fbm(uv * 1.5 + time * 0.01);

    // Cave wall texture: rough, damp stone
    vec3 wall = vec3(0.35, 0.25, 0.18) + n * 0.15;

    // Cave painting marks — hand stencils and animal silhouettes
    // Procedural "painting" at fixed UV positions
    vec2 hand = vec2(0.35, 0.55);
    float handPrint = 0.0;
    for (int f = 0; f < 5; f++) {
        vec2 fingerBase = hand + vec2(float(f) * 0.018 - 0.036, 0.0);
        float finger = exp(-length(uv - fingerBase - vec2(0.0, 0.025)) * 40.0);
        finger += exp(-length(uv - fingerBase) * 55.0) * 0.5;
        handPrint += finger;
    }
    float palm = exp(-length(uv - hand) * 25.0);
    handPrint += palm;
    handPrint = clamp(handPrint, 0.0, 1.0);

    vec3 pigment = vec3(0.75, 0.25, 0.10);   // Red ochre
    wall = mix(wall, pigment, handPrint);

    return wall;
}

// EPOCH 5: Temporal noise floor — the beginning of time
// Pure static. Cosmic microwave background.
vec3 cmbContent(vec2 uv, float time) {
    float cmb = noise(uv * 50.0 + time * 0.5) * 0.4
              + noise(uv * 120.0 - time * 0.3) * 0.3
              + noise(uv * 300.0 + time * 0.2) * 0.3;

    // CMB temperature fluctuations: microkelvin-scale, false-colored
    return mix(vec3(0.02, 0.05, 0.12), vec3(0.35, 0.15, 0.45), cmb);
}

// ---- Temporal chromatic parallax --------------------------------------------
// "time" (= depth) encodes temporal distance from focal_time
// Past = redshifted (Hubble redshift → cosmic distance = time)
// Future = blueshifted (approaching, Doppler)

vec3 temporalChromatic(vec2 uv, float epochDepth, float time) {
    // Signed temporal distance from present (0.0)
    float td  = epochDepth;   // 0=present, 1=deep past, -epsilon=future

    // Hubble-inspired: past is redshifted, future is blueshifted
    // Red channel: past-biased displacement
    // Blue channel: future-biased displacement
    float rDisp = td * PARALLAX_STRENGTH * CHROMATIC_INTENSITY * 1.3;
    float gDisp = td * PARALLAX_STRENGTH * CHROMATIC_INTENSITY * 0.4;
    float bDisp = td * PARALLAX_STRENGTH * CHROMATIC_INTENSITY * -0.8;

    // Note: since we compute per-epoch below, we just return the chromatic-displaced
    // version of whichever epoch content is right
    return vec3(rDisp, gDisp, bDisp);   // Returns displacement deltas — used by caller
}

// ---- Epoch compositor -------------------------------------------------------

vec3 epochColor(vec2 uv, int epochIdx, float time) {
    if (epochIdx == 0) return futureContent(uv, time);
    if (epochIdx == 1) return presentContent(uv, time);
    if (epochIdx == 2) return nearPastContent(uv, time);
    if (epochIdx == 3) return midPastContent(uv, time);
    if (epochIdx == 4) return deepPastContent(uv, time);
    return cmbContent(uv, time);
}

vec3 epochChromatic(vec2 uv, int epochIdx, float depth, float time) {
    vec3 disp = temporalChromatic(uv, depth, time);
    vec3 col;
    col.r = epochColor(uv + vec2(disp.r, 0.0), epochIdx, time).r;
    col.g = epochColor(uv + vec2(disp.g, 0.0), epochIdx, time).g;
    col.b = epochColor(uv + vec2(disp.b, 0.0), epochIdx, time).b;
    return col;
}

// ---- Main -------------------------------------------------------------------

void main() {
    vec2  uv       = gl_FragCoord.xy / u_resolution.xy;
    vec2  centered  = uv - 0.5;
    centered.x     *= u_resolution.x / u_resolution.y;

    float time     = u_time * TIME_SCALE;
    vec2  mouseUV  = u_mouse / u_resolution;

    // Mouse Y controls temporal focus: where in time is "sharp"
    // Y=1 (top) = focused on the present. Y=0 (bottom) = focused on deep past.
    float mouseTFocus = 1.0 - mouseUV.y;   // Map top=0 (present), bottom=1 (deep past)
    float temporalFocus = clamp(mouseTFocus, 0.0, 1.0);

    // ---- Accumulate temporal layers
    vec3  color      = vec3(0.0);
    float totalWeight = 0.0;

    for (int i = 0; i < NUM_EPOCHS; i++) {
        float fi = float(i);
        // Epoch depths: 0=future(edge), 1=present, 2-5=past
        // Map i → temporal depth for focus calculation
        float epochT;
        if (i == 0) epochT = -0.1;   // Future: slightly in front of focal
        else        epochT = float(i - 1) / float(NUM_EPOCHS - 2);   // Present to CMB

        // How far from temporal focus?
        float focalDist = abs(epochT - temporalFocus);

        // Weight: Gaussian peak at focal time
        float w = exp(-focalDist * focalDist * 8.0) + 0.05;

        // Depth-of-field: blur past epochs (they're "out of time-focus")
        float blurR = focalDist * focalDist * (epochT >= 0.0 ? MAX_BLUR_PAST : MAX_BLUR_FUTURE);
        vec3  col   = epochChromatic(uv, i, epochT, time);

        if (blurR > 0.5) {
            vec3 blurred = vec3(0.0);
            for (int k = 0; k < 6; k++) {
                float ang = float(k) / 6.0 * 6.28318 + time * 0.1;
                vec2  off = vec2(cos(ang), sin(ang)) * blurR / u_resolution.x;
                blurred  += epochChromatic(uv + off, i, epochT, time);
            }
            col = mix(col, blurred / 6.0, clamp(blurR / MAX_BLUR_PAST, 0.0, 0.9));
        }

        // Past epochs: rose-tint (redshift) and desaturate with age
        if (epochT > 0.0) {
            float age  = epochT;
            float grey = dot(col, vec3(0.299, 0.587, 0.114));
            col = mix(col, vec3(grey), age * 0.4);
            col = mix(col, col * vec3(1.1, 0.9, 0.85), age * 0.3);
        }

        // Future epochs: blue-tint and sharpen
        if (epochT < 0.0) {
            col = mix(col, col * vec3(0.7, 0.85, 1.2), 0.4);
        }

        color      += col * w;
        totalWeight += w;
    }
    color /= totalWeight;

    // ---- Present-moment anchoring: the UFO always reads as solid / now
    vec3 present  = presentContent(uv, time);
    float nowMask = step(0.85, presentContent(uv, time).g + presentContent(uv, time).b * 0.5);
    color = mix(color, present, nowMask * 0.7);

    // ---- Temporal shimmer: at the boundary between epochs, time "stutters"
    float epochBoundary = fract(temporalFocus * float(NUM_EPOCHS));
    float stutter = step(0.48, epochBoundary) * step(epochBoundary, 0.52) * 0.1;
    float stutterNoise = noise(uv * 100.0 + time * 20.0);
    color = mix(color, vec3(stutterNoise), stutter);

    // ---- Vignette
    float vig = 1.0 - dot(centered, centered) * 0.65;
    color *= clamp(vig, 0.2, 1.0);

    // ---- Time grain: present is clean, past/future is grainy
    float temporalGrain = abs(temporalFocus - 0.0) * 0.06;
    float grain = (hash(uv * u_resolution + fract(time) * 500.0) - 0.5) * temporalGrain;
    color += grain;

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
