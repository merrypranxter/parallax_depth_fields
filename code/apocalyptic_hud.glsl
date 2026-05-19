// APOCALYPTIC HUD — Corrupted Machine Vision
// The machine is dying. Or you are. Unclear which.
//
// Corrupted depth buffer: Z-values are wrong. Planes render in the wrong order.
// The HUD tries to maintain readouts but underlying data is chaos.
// Text in unreadable scripts. Reticles tracking empty space.
// Warning systems warning about the warning systems.
// A chromatic separation that isn't beautiful — it's traumatic.
//
// "ERROR: DEPTH BUFFER INTEGRITY 0.23
//  FOCAL PLANE LOCATION: UNKNOWN
//  RECOMMENDED ACTION: [CORRUPTED]"

precision highp float;

uniform vec2  u_resolution;
uniform float u_time;
uniform vec2  u_mouse;

// PARAMETERS
const float GLITCH_AMOUNT      = 0.55;   // Overall corruption level
const float CHROMATIC_INTENSITY = 1.9;   // Chromatic aberration (traumatic level)
const float PARALLAX_STRENGTH   = 0.28;  // Strong depth displacement
const float TIME_SCALE          = 1.0;
const float SCANLINE_DAMAGE     = 0.7;   // How much of scanlines are damaged

// ---- Noise / hash -----------------------------------------------------------

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash1(float f) {
    return fract(sin(f * 17.3921) * 43758.5453);
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

// ---- Corrupted depth map ----------------------------------------------------
// Normally a depth value should be in [0,1].
// "Corrupted" depth has wrong values: objects at wrong depths, z-fighting,
// random spikes, and values outside valid range.

float corruptDepth(vec2 uv, float time) {
    float base = noise(uv * 3.0 + time * 0.05);   // "Normal" scene depth

    // Corruption sources:
    // 1. Random depth spike pixels
    float spike = step(0.985, hash(uv * u_resolution + floor(time * 10.0) * 1337.0));
    float spikeVal = hash(uv * 500.0 + time) * 2.0 - 0.5;  // Can exceed [0,1]

    // 2. Horizontal sync errors: whole rows teleport in depth
    float rowError = step(0.92, hash(vec2(floor(uv.y * u_resolution.y), floor(time * 3.0))));
    float rowShift = hash(vec2(floor(uv.y * u_resolution.y * 0.5), time)) * 0.8 - 0.4;

    // 3. "Bleeding" between depth planes — Z-buffer contamination
    float bleed = noise(uv * 20.0 + vec2(time * 0.3, 0.0)) * 0.4;

    // 4. Lost-sync event: every few seconds, depth is completely scrambled
    float eventT   = floor(time * 0.7);
    float eventHsh = hash(vec2(eventT, 0.42));
    float lostSync = step(0.8, eventHsh) * smoothstep(0.0, 0.3, fract(time * 0.7));
    float scramble = noise(uv * 6.0 + vec2(eventT * 17.1, eventT * 3.7));

    float depth = base;
    depth += spike * spikeVal;
    depth += rowError * rowShift;
    depth += bleed * GLITCH_AMOUNT;
    depth = mix(depth, scramble, lostSync * GLITCH_AMOUNT);

    // Do NOT clamp — the corruption lets values escape [0,1]
    return depth;
}

// ---- Corrupted scene content ------------------------------------------------
// The underlying "image" the depth buffer is supposed to describe

vec3 corruptScene(vec2 uv, float depth, float time) {
    float n1 = noise(uv * 3.0 + time * 0.03);
    float n2 = noise(uv * 8.0 - time * 0.05);

    // Base: dark, industrial — ruined factory, dead server room
    vec3 base = vec3(0.04, 0.05, 0.06) + n1 * 0.08 + n2 * 0.04;

    // Green phosphor "alive" signals (like emergency lighting)
    float greenStrip = abs(sin(uv.y * 18.0 + depth * 3.0)) ;
    greenStrip = pow(greenStrip, 20.0) * 0.2;
    base += greenStrip * vec3(0.0, 0.5, 0.1);

    // Red warning patches (too-near objects)
    float dangerNear = smoothstep(0.0, 0.2, depth) * 0.3;
    base += dangerNear * vec3(0.3, 0.0, 0.0);

    // Depth-plane pop-through: objects from wrong layer briefly visible
    float wrongLayer = step(0.96, noise(uv * 5.0 + floor(time * 5.0) * 0.1)) * 0.6;
    base += wrongLayer * vec3(0.8, 0.7, 0.1) * n1;

    return base;
}

// Chromatic sample with corrupted depth driving the parallax
vec3 corruptChromatic(vec2 uv, float depth, float time) {
    // Parallax based on corrupted depth — wrong values create wild displacements
    float disp = clamp(depth - 0.5, -0.5, 0.5) * PARALLAX_STRENGTH * CHROMATIC_INTENSITY;

    // Channels also glitch independently
    float glitchR = (hash(vec2(time * 7.3, 0.1)) - 0.5) * GLITCH_AMOUNT * 0.04;
    float glitchB = (hash(vec2(time * 5.1, 0.9)) - 0.5) * GLITCH_AMOUNT * 0.03;

    vec3 col;
    col.r = corruptScene(uv + vec2(disp * 1.4 + glitchR,  0.001), depth, time).r;
    col.g = corruptScene(uv + vec2(disp * 0.5,             0.000), depth, time).g;
    col.b = corruptScene(uv + vec2(disp * -1.1 + glitchB, -0.001), depth, time).b;

    return col;
}

// ---- VHS / digital glitch artifacts -----------------------------------------

// Horizontal sync failure: rows shift left/right
vec2 syncError(vec2 uv, float time) {
    float row    = floor(uv.y * u_resolution.y);
    float rowH   = hash(vec2(row, floor(time * 4.0)));
    float rowH2  = hash(vec2(row * 0.5, floor(time * 2.0)));

    // Probability of sync error on this row
    float syncFail = step(1.0 - GLITCH_AMOUNT * 0.4, rowH);
    float shift    = (rowH2 - 0.5) * 0.08 * syncFail;

    return uv + vec2(shift, 0.0);
}

// Pixel block corruption: NxN blocks teleport to random positions
vec2 blockGlitch(vec2 uv, float time) {
    float blockSize = 0.04;
    vec2  block     = floor(uv / blockSize);
    float bHash     = hash(block + floor(time * 8.0) * 0.17);

    if (bHash > 1.0 - GLITCH_AMOUNT * 0.3) {
        float shiftX = (hash(block * 3.71 + time) - 0.5) * 0.3;
        float shiftY = (hash(block * 1.93 + time) - 0.5) * 0.1;
        return uv + vec2(shiftX, shiftY);
    }
    return uv;
}

// ---- HUD drawing: corrupted overlays ----------------------------------------

// A "character" from an unknown / corrupted script — procedural noise glyphs
float glyphMask(vec2 p, float seed) {
    p = fract(p);
    float n = noise(p * 4.0 + seed);
    float bars  = step(0.4, fract(p.y * 5.0 + n * 0.3)) * 0.5;
    float vbars = step(0.4, fract(p.x * 4.0 + n * 0.2)) * 0.5;
    return max(bars, vbars) * step(0.3, n);
}

// Text line: a row of corrupted glyphs
float textLine(vec2 uv, vec2 start, float cellW, float cellH, int numChars, float seed) {
    vec2 local = uv - start;
    if (local.x < 0.0 || local.y < 0.0 || local.x > cellW * float(numChars) || local.y > cellH)
        return 0.0;
    int charIdx = int(floor(local.x / cellW));
    vec2 charUV = vec2(fract(local.x / cellW), local.y / cellH);
    return glyphMask(charUV, seed + float(charIdx) * 0.37);
}

// Corrupted reticle: tries to draw a tracking box but fails
float corruptReticle(vec2 uv, vec2 center, float size, float corruption, float time) {
    vec2  p    = (uv - center) * vec2(u_resolution.x / u_resolution.y, 1.0);
    float lw   = 0.002;

    // Corner brackets, but corrupted: brackets jitter and sometimes teleport
    vec2 q = abs(p) - vec2(size, size * 0.8);

    // Random jitter per frame
    float jitterX = (hash(vec2(time * 5.0, 1.0)) - 0.5) * corruption * 0.03;
    float jitterY = (hash(vec2(time * 3.0, 2.0)) - 0.5) * corruption * 0.02;
    q += vec2(jitterX, jitterY);

    float bLen = size * 0.3;
    float hArm = length(vec2(max(-q.x - bLen, 0.0), max(abs(q.y) - lw, 0.0))) - lw * 0.5;
    float vArm = length(vec2(max(abs(q.x) - lw, 0.0), max(-q.y - bLen, 0.0))) - lw * 0.5;

    float bracket = min(hArm, vArm);
    float alpha   = clamp(-bracket / (lw * 2.0), 0.0, 1.0);

    // Parts of the reticle randomly drop out
    float dropout = step(1.0 - corruption * 0.5, hash(floor(uv * 150.0) + floor(time * 15.0) * 0.1));
    alpha *= (1.0 - dropout);

    return alpha;
}

// ---- Main -------------------------------------------------------------------

void main() {
    vec2  uv0     = gl_FragCoord.xy / u_resolution.xy;
    vec2  centered = uv0 - 0.5;
    centered.x   *= u_resolution.x / u_resolution.y;

    float time    = u_time * TIME_SCALE;

    // ---- Apply glitch transforms to UV before sampling
    vec2 uv = syncError(uv0, time);
    uv      = blockGlitch(uv, time);

    // ---- Sample corrupted depth
    float depth = corruptDepth(uv, time);

    // ---- Chromatic scene with corrupted parallax
    vec3 color = corruptChromatic(uv, depth, time);

    // ---- VHS color dropout: occasional full-channel drop
    float chDropR = step(1.0 - GLITCH_AMOUNT * 0.15, hash(vec2(floor(time * 6.0), 3.7)));
    float chDropB = step(1.0 - GLITCH_AMOUNT * 0.12, hash(vec2(floor(time * 4.0), 8.1)));
    color.r *= (1.0 - chDropR);
    color.b *= (1.0 - chDropB);

    // ---- Corrupted scanlines
    float scanRow   = sin(uv0.y * u_resolution.y * 0.9);
    float scanBase  = scanRow * 0.04 + 0.96;
    // Some scanlines are damaged: brighter or completely dropped
    float scanHash  = hash(vec2(floor(uv0.y * u_resolution.y), floor(time * 2.0)));
    float damaged   = step(1.0 - SCANLINE_DAMAGE * 0.2, scanHash);
    float scanDmg   = mix(1.0, (scanHash - 0.8) * 5.0 * 2.0 - 1.0, damaged);
    color          *= scanBase * mix(1.0, scanDmg, SCANLINE_DAMAGE * 0.3);

    // ---- HUD overlays: damaged and corrupted
    // Warning text: random-script glyphs
    float hud1 = textLine(uv0, vec2(0.05, 0.85), 0.022, 0.018, 16, 1.0 + floor(time * 0.5));
    float hud2 = textLine(uv0, vec2(0.05, 0.82), 0.022, 0.015, 12, 4.7 + floor(time * 0.3));
    float hud3 = textLine(uv0, vec2(0.70, 0.15), 0.018, 0.014, 8,  2.3 + floor(time * 0.7));

    vec3 hudGreen = vec3(0.15, 0.90, 0.25);
    vec3 hudRed   = vec3(0.90, 0.10, 0.05);
    color = mix(color, hudGreen, hud1 * 0.75);
    color = mix(color, hudRed,   hud2 * 0.75);
    color = mix(color, hudGreen, hud3 * 0.6);

    // Status bar (partial — half of it is corrupted black)
    float statusBar = step(0.89, uv0.y) * step(uv0.y, 0.91);
    float statusFill = uv0.x < 0.35 ? 1.0 : hash(vec2(floor(uv0.x * 80.0), 0.0));
    statusFill = mix(statusFill, 0.0, step(0.5, hash(vec2(floor(uv0.x * 30.0), floor(time)))));
    color = mix(color, vec3(0.0, 0.6, 0.1) * statusFill, statusBar * 0.7);

    // Corrupted reticles: tracking things that aren't there
    vec2 ghostTarget1 = vec2(0.3 + sin(time * 2.1) * 0.15, 0.5 + cos(time * 1.7) * 0.1);
    vec2 ghostTarget2 = vec2(0.65 + cos(time * 1.3) * 0.1, 0.45 + sin(time * 2.5) * 0.12);

    float ret1 = corruptReticle(uv0, ghostTarget1, 0.06, GLITCH_AMOUNT, time);
    float ret2 = corruptReticle(uv0, ghostTarget2, 0.04, GLITCH_AMOUNT * 0.8, time);
    color = mix(color, vec3(0.1, 0.9, 0.2), ret1 * 0.8);
    color = mix(color, vec3(0.9, 0.2, 0.1), ret2 * 0.7);

    // ---- "Dead zone": random region of totally lost signal
    float deadZone = step(0.94, noise(uv0 * 4.0 + floor(time * 0.5) * 2.3));
    float deadColor = hash(uv0 * 200.0 + floor(time * 12.0));
    color = mix(color, vec3(deadColor * 0.1), deadZone * GLITCH_AMOUNT);

    // ---- Color bleed: channels smear into each other at edges of corrupted regions
    float bleedMask = noise(uv0 * 10.0 + time * 0.4) * GLITCH_AMOUNT;
    color.r = mix(color.r, color.b, bleedMask * 0.3);
    color.b = mix(color.b, color.r, bleedMask * 0.2);

    // ---- Vignette (broken — uneven darkening)
    float vig = 1.0 - dot(centered, centered) * 0.8;
    // One corner of the vignette is corrupted
    float cornerBreak = smoothstep(0.0, 0.4, centered.x + 0.5) * smoothstep(0.0, 0.4, centered.y + 0.5);
    vig = mix(vig, vig * 0.4, cornerBreak * GLITCH_AMOUNT * 0.5);
    color *= clamp(vig, 0.1, 1.0);

    // ---- Final: occasional total-frame flash (capacitor discharge aesthetic)
    float bigFlash = step(0.998, hash(vec2(floor(time * 15.0), 9.9)));
    color = mix(color, vec3(0.9, 1.0, 0.6), bigFlash * 0.7);

    gl_FragColor = vec4(color, 1.0);
}
