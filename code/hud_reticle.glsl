// HUD RETICLE
// Terminator-style tracking reticles that exist at different depth planes.
// Multiple reticles float in 3D — each locked to a distinct depth layer.
// Mouse movement pulls the near-plane reticle. Click to "lock on."
// On lock: reticle snaps with a glitchy chromatic overshoot animation.

precision highp float;

uniform vec2 u_resolution;
uniform float u_time;
uniform vec2 u_mouse;

// PARAMETERS
const int   NUM_RETICLES       = 3;      // One per depth plane
const float HUD_OPACITY        = 0.85;
const float CHROMATIC_INTENSITY = 0.7;
const float GLITCH_AMOUNT      = 0.15;   // Probability of a data-corrupt flash
const float LOCK_SPEED         = 8.0;    // How fast reticle snaps on lock
const float TIME_SCALE         = 1.0;

// ---- Helpers ---------------------------------------------------------------

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

// ---- Background scene (so the HUD is visible) ------------------------------

vec3 sceneColor(vec2 uv, float time) {
    float n  = noise(uv * 3.5 + time * 0.05);
    float n2 = noise(uv * 7.0 - time * 0.07);
    float n3 = noise(uv * 15.0 + vec2(time * 0.1, -time * 0.06));

    vec3 base  = mix(vec3(0.02, 0.04, 0.08), vec3(0.05, 0.1, 0.15), n);
    base += vec3(0.0, 0.06, 0.04) * n2 * 0.4;
    base += vec3(0.04, 0.03, 0.0) * n3 * 0.2;

    // Faint horizontal grid — like a targeting range
    float hgrid = pow(abs(sin(uv.y * 60.0)), 24.0) * 0.07;
    float vgrid = pow(abs(sin(uv.x * 60.0)), 24.0) * 0.05;
    base += hgrid + vgrid;

    return base;
}

// ---- Reticle drawing primitives -------------------------------------------

// Signed-distance to a circle outline
float sdCircle(vec2 p, float r, float lineW) {
    return abs(length(p) - r) - lineW;
}

// Signed-distance to an axis-aligned line segment
float sdSegH(vec2 p, float halfLen, float lineW) {
    float dx = max(abs(p.x) - halfLen, 0.0);
    return length(vec2(dx, p.y)) - lineW;
}

float sdSegV(vec2 p, float halfLen, float lineW) {
    float dy = max(abs(p.y) - halfLen, 0.0);
    return length(vec2(p.x, dy)) - lineW;
}

// Corner bracket: draws a small L at each quadrant of a rect
float cornerBracket(vec2 p, vec2 halfSize, float bracketLen, float lineW) {
    // Reflect into first quadrant
    vec2 q = abs(p) - halfSize;

    // Horizontal arm
    float h = abs(q.y) - lineW;
    float hArm = length(vec2(max(-q.x - bracketLen, 0.0), max(h, 0.0))) - lineW * 0.5;

    // Vertical arm
    float v = abs(q.x) - lineW;
    float vArm = length(vec2(max(h, 0.0), max(-q.y - bracketLen, 0.0))) - lineW * 0.5;

    return min(hArm, vArm);
}

// Draw a small numeric readout as blocky pixel art (3×5 digits)
// Returns 1.0 where the "display" has an active segment
float digitPixel(vec2 p, int digit, float cellSize) {
    // Segment patterns for 0-9 in a 3×5 bitmask (top-to-bottom, left-to-right)
    // Encoded as float constants parsed at runtime — simple approach
    p /= cellSize;
    if (p.x < 0.0 || p.x >= 3.0 || p.y < 0.0 || p.y >= 5.0) return 0.0;
    int col = int(floor(p.x));
    int row = int(floor(p.y));
    // 3x5 grid: row 0 = top
    // We encode each digit as 15-bit mask (row-major)
    // Bits: row0c0 row0c1 row0c2 row1c0 ... row4c2
    // Using float array trick (GLSL ES 1.0 compatible)
    float masks[10];
    masks[0] = 29799.0; // 0
    masks[1] =  4732.0; // 1
    masks[2] = 23415.0; // 2
    masks[3] = 29439.0; // 3
    masks[4] = 11310.0; // 4
    masks[5] = 31183.0; // 5
    masks[6] = 31215.0; // 6
    masks[7] = 29257.0; // 7
    masks[8] = 31727.0; // 8
    masks[9] = 31695.0; // 9

    float mask = masks[clamp(digit, 0, 9)];
    int bit = row * 3 + col;
    float shifted = floor(mask / pow(2.0, float(bit)));
    return mod(shifted, 2.0);
}

// ---- Reticle compositor ---------------------------------------------------

// Returns (color, alpha) for a single reticle drawn at `center` (UV space)
// `depth` controls size (near = large) and chromatic displacement
// `locked` smoothly transitions from 0 (tracking) to 1 (locked-on)
vec4 drawReticle(vec2 uv, vec2 center, float depth, float locked,
                 float glitchPhase, float time) {
    vec2 aspect   = vec2(u_resolution.x / u_resolution.y, 1.0);
    // Aspect-correct local coordinates
    vec2 p        = (uv - center) * aspect;
    float scale   = mix(0.12, 0.05, depth); // Near reticle = bigger

    // Base line width, thinner for far reticles
    float lw = 0.001 * mix(2.0, 1.0, depth);

    // ---- Main circle ----
    float mainR   = scale;
    float circ    = sdCircle(p, mainR, lw);

    // ---- Crosshair ----
    // Gap in the middle so the center stays clear
    float gap     = mainR * 0.3;
    float armLen  = mainR * 0.5;
    float h       = sdSegH(p, armLen + gap, lw);
    float v       = sdSegV(p, armLen + gap, lw);
    // Cut out gap region
    h = (abs(p.x) > gap) ? h : 1.0;
    v = (abs(p.y) > gap) ? v : 1.0;

    // ---- Corner brackets (appear on lock) ----
    vec2 boxHalf = vec2(mainR * 1.3, mainR * 1.0);
    float bLen   = boxHalf.x * 0.3;
    float bracket = cornerBracket(p, boxHalf, bLen, lw);

    // ---- Rotation ring (spins faster when unlocked) ----
    float rotSpeed  = mix(1.5, 0.3, locked);
    float rotAngle  = time * rotSpeed + depth * 1.2;
    vec2  rotP      = mat2(cos(rotAngle), -sin(rotAngle),
                           sin(rotAngle),  cos(rotAngle)) * p;
    // Dashed effect on the ring
    float dashAngle  = atan(rotP.y, rotP.x);
    float dash       = step(0.5, fract(dashAngle / 1.047)); // ~60° segments
    float rotCirc    = sdCircle(p, mainR * 1.4, lw * 0.8) * (1.0 - dash * 0.0);
    // Actually just segment by masking
    float rotRing    = (sdCircle(p, mainR * 1.4, lw) < 0.0 && dash > 0.5) ? -1.0 : 1.0;

    // ---- Combine SDF shapes ----
    float shape = min(min(circ, min(h, v)),
                      mix(1.0, bracket, locked));
    shape = min(shape, rotRing);

    float alpha = clamp(-shape / (lw * 2.0), 0.0, 1.0);
    alpha *= HUD_OPACITY;

    // ---- Color: depth-coded + lock state ----
    vec3 trackColor  = mix(vec3(0.9, 0.1, 0.15),  // Red   — near
                            vec3(0.1, 0.8, 0.9),   // Cyan  — far
                            depth);
    vec3 lockColor   = vec3(0.2, 1.0, 0.3);        // Green — locked
    vec3 baseColor   = mix(trackColor, lockColor, locked);

    // Pulse on lock
    float lockPulse  = locked * pow(sin(time * 6.0) * 0.5 + 0.5, 4.0) * 0.4;
    baseColor += lockPulse;

    // ---- Chromatic separation ----
    float split = depth * CHROMATIC_INTENSITY * 0.008;
    float rAlpha = clamp(-sdCircle((uv - center + vec2(split, 0.0)) * aspect,
                                    mainR, lw) / (lw * 2.0), 0.0, 1.0);
    float bAlpha = clamp(-sdCircle((uv - center - vec2(split * 1.5, 0.0)) * aspect,
                                    mainR, lw) / (lw * 2.0), 0.0, 1.0);
    baseColor.r = mix(baseColor.r, 1.0, rAlpha * 0.5 * (1.0 - locked));
    baseColor.b = mix(baseColor.b, 1.0, bAlpha * 0.5 * (1.0 - locked));

    // ---- Glitch: random pixel flash ----
    float glitch = step(1.0 - GLITCH_AMOUNT, hash(vec2(glitchPhase, depth)));
    if (glitch > 0.5 && length(p) < mainR * 2.0) {
        float gFlash = hash(uv * 300.0 + glitchPhase);
        baseColor = mix(baseColor, vec3(1.0, 1.0, 0.0), gFlash * 0.6);
        alpha = max(alpha, gFlash * 0.4);
    }

    // ---- Readout text lines (distance indicator) ----
    // Small block below the circle
    vec2 textP    = (uv - center - vec2(0.0, -mainR * 1.6)) * aspect;
    float textScale = lw * 12.0;
    // "distAmt" simulates a fluctuating distance readout
    float distAmt = mix(80.0, 10.0, depth) + sin(time * 3.0 + depth) * 5.0;
    int   d0 = int(floor(distAmt / 10.0));
    int   d1 = int(mod(floor(distAmt), 10.0));

    vec2  digit0P = textP - vec2(-textScale * 4.0, 0.0);
    vec2  digit1P = textP - vec2( textScale * 0.0, 0.0);

    float textAlpha = digitPixel(digit0P, d0, textScale) +
                      digitPixel(digit1P, d1, textScale);
    textAlpha = clamp(textAlpha, 0.0, 1.0) * HUD_OPACITY * 0.7;

    alpha = max(alpha, textAlpha);
    baseColor = mix(baseColor, vec3(0.8, 1.0, 0.6), textAlpha);

    return vec4(baseColor, alpha);
}

// ---- Main ------------------------------------------------------------------

void main() {
    vec2 uv      = gl_FragCoord.xy / u_resolution.xy;
    vec2 centered = uv - 0.5;
    centered.x  *= u_resolution.x / u_resolution.y;

    float time   = u_time * TIME_SCALE;

    // Render background scene
    vec3 color = sceneColor(uv, time);

    // --- Reticle definitions ---
    // Depths: 0 = near, 1 = far
    float depths[3];
    depths[0] = 0.1;   // Near-plane tracking reticle (follows mouse)
    depths[1] = 0.45;  // Mid-plane — slowly drifts
    depths[2] = 0.8;   // Far-plane — locked onto a target

    // Near reticle follows mouse with slight lag
    vec2 mouseUV = u_mouse / u_resolution;
    vec2 centers[3];
    centers[0] = mix(vec2(0.5), mouseUV, 0.85);
    centers[1] = vec2(0.5 + sin(time * 0.3) * 0.2, 0.5 + cos(time * 0.2) * 0.15);
    centers[2] = vec2(0.5 + sin(time * 0.1 + 1.0) * 0.1, 0.5 + cos(time * 0.12) * 0.08);

    // Lock state: near=tracking, mid=half-locked, far=fully locked
    float locks[3];
    locks[0] = 0.0;
    locks[1] = smoothstep(0.0, 1.0, sin(time * 0.5) * 0.5 + 0.5) * 0.6;
    locks[2] = 1.0;

    // Glitch phase evolves slowly
    float glitchPhase = floor(time * 4.0) * 0.1;

    // Composite reticles back-to-front (far first)
    for (int i = NUM_RETICLES - 1; i >= 0; i--) {
        float fi = float(i);
        vec4 ret = drawReticle(uv, centers[i], depths[i], locks[i],
                               glitchPhase + fi * 0.37, time);
        color = mix(color, ret.rgb, ret.a);
    }

    // --- Scanline / CRT overlay ---
    float scanline = sin(uv.y * u_resolution.y * 0.9) * 0.025 + 0.975;
    color *= scanline;

    // --- Global vignette ---
    float vig = 1.0 - dot(centered, centered) * 0.65;
    color *= clamp(vig, 0.25, 1.0);

    gl_FragColor = vec4(color, 1.0);
}
