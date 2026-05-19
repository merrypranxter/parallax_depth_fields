// QUANTUM DEPTH — Schrödinger's Parallax
// Objects exist in MULTIPLE depth planes simultaneously until "observed."
// Mouse hover collapses the wave function: the object snaps to a single depth.
// Uncertainty principle in action: the more precisely you locate something in depth,
// the more its chromatic signature smears across the spectrum.
//
// "The tree is both near and far. Both sharp and blurred.
//  Until you look at it. Then it has to decide."

precision highp float;

uniform vec2  u_resolution;
uniform float u_time;
uniform vec2  u_mouse;

// PARAMETERS
const int   NUM_STATES          = 4;     // Superposition states per object
const float COLLAPSE_RADIUS     = 0.18;  // How close mouse must be to collapse (UV)
const float CHROMATIC_INTENSITY = 1.6;   // Uncertainty = spread. High = more smear.
const float PARALLAX_STRENGTH   = 0.12;
const float TIME_SCALE          = 1.0;

// ---- Noise / hash ------------------------------------------------------------

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash1(float f) {
    return fract(sin(f * 27.3921) * 43758.5453);
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

// ---- Object content ---------------------------------------------------------
// Radial content for one "quantum object" at a specific depth eigenstate

vec3 objectContent(vec2 uv, vec2 objPos, float depth, float time, float objPhase) {
    vec2  local = uv - objPos;
    float r     = length(local);

    float n  = noise(local * (3.0 + depth * 6.0) + time * 0.15 + objPhase);

    // Interference rings — different phase per channel (120° spacing)
    float wR = sin(r * 30.0 + time * 2.0 + objPhase        ) * 0.5 + 0.5;
    float wG = sin(r * 30.0 + time * 2.0 + objPhase + 2.094) * 0.5 + 0.5;
    float wB = sin(r * 30.0 + time * 2.0 + objPhase + 4.189) * 0.5 + 0.5;

    float core = exp(-r * r / 0.004) * 2.0;   // Bright central spike

    vec3 col;
    col.r = (n * 0.6 + wR * 0.4 + core) * mix(0.8, 0.3, depth);
    col.g = (n * 0.5 + wG * 0.3 + core) * mix(0.4, 0.8, depth);
    col.b = (n * 0.4 + wB * 0.5 + core) * mix(0.3, 0.9, depth);

    return col * exp(-r * r / 0.03);    // Gaussian spatial envelope
}

// Chromatic parallax sample for one object at one depth
vec3 quantumChromatic(vec2 uv, vec2 objPos, float depth, float time, float objPhase) {
    float disp = (depth - 0.5) * PARALLAX_STRENGTH * CHROMATIC_INTENSITY;
    vec3 col;
    col.r = objectContent(uv + vec2(disp * 1.3,  0.0         ), objPos, depth, time, objPhase);
    col.g = objectContent(uv + vec2(disp * 0.4,  disp * 0.1  ), objPos, depth, time, objPhase);
    col.b = objectContent(uv + vec2(disp * -1.0, disp * -0.15), objPos, depth, time, objPhase);
    return col;
}

// ---- Superposed object (unobserved) -----------------------------------------
// Blends NUM_STATES depth eigenstates with Born-rule amplitude weighting
// and interference phase shifts between them.

vec3 superposedObject(vec2 uv, vec2 pos, float baseDepth, float spread,
                       float phase, float time) {
    vec3  acc = vec3(0.0);
    float tot = 0.0;

    for (int i = 0; i < NUM_STATES; i++) {
        float fi = float(i);
        // Eigenstate depth: spread around baseDepth
        float ed = clamp(baseDepth + (fi / float(NUM_STATES - 1) - 0.5) * spread * 2.0,
                         0.0, 1.0);

        // Born rule: amplitude ∝ Gaussian envelope around mean depth
        float amp = exp(-pow((ed - baseDepth) / (spread + 0.001), 2.0));

        // Interference term: π/2 phase between adjacent states
        float ph  = phase + fi * 1.5708 + time * 0.8;
        float itr = cos(ph) * 0.3 + 0.7;   // keeps in [0.4, 1.0]

        acc += quantumChromatic(uv, pos, ed, time, phase) * amp * itr;
        tot += amp * itr;
    }

    return (tot > 0.001) ? acc / tot : vec3(0.0);
}

// ---- Collapsed object (observed) --------------------------------------------
// Snaps to a single chosen eigenstate when mouse is near

vec3 collapsedObject(vec2 uv, vec2 pos, float baseDepth, float spread,
                      float phase, float collapseFlash, float time) {
    // Chosen eigenstate: slightly offset from base to feel non-trivial
    float chosenDepth = clamp(baseDepth + (hash1(phase) - 0.5) * spread * 0.4, 0.0, 1.0);

    vec3 col = quantumChromatic(uv, pos, chosenDepth, time, phase);

    // Flash at moment of measurement
    col += exp(-collapseFlash * 8.0) * vec3(1.0, 0.95, 0.85) * 2.0;

    return col;
}

// ---- Quantum vacuum background ----------------------------------------------
vec3 vacuumBackground(vec2 uv, float time) {
    float zp1 = noise(uv * 8.0  + vec2( time * 0.20,  time * 0.15));
    float zp2 = noise(uv * 20.0 - vec2( time * 0.17,  time * 0.10));
    float zp3 = noise(uv * 45.0 + vec2( time * 0.30, -time * 0.25));

    vec3 vac = vec3(0.02, 0.03, 0.06);
    vac += vec3(0.00, 0.04, 0.08) * zp1 * 0.4;
    vac += vec3(0.05, 0.00, 0.06) * zp2 * 0.2;
    vac += zp3 * 0.015;

    // Virtual particle flashes — brief random bright flecks
    float virt = step(0.998, hash(uv * 300.0 + fract(time * 7.0) * 100.0));
    vac += virt * vec3(0.6, 0.8, 1.0);

    return vac;
}

// ---- Main -------------------------------------------------------------------

void main() {
    vec2  uv      = gl_FragCoord.xy / u_resolution.xy;
    vec2  centered = uv - 0.5;
    centered.x   *= u_resolution.x / u_resolution.y;

    float time    = u_time * TIME_SCALE;
    vec2  mouseUV = u_mouse / u_resolution;

    // ---- Define quantum objects (position drifts slowly for dreamlike motion)
    // Layout: pos, baseDepth, spread, phase
    vec2  pos[4];
    float baseD[4];
    float sprd[4];
    float ph[4];

    pos[0]   = vec2(0.5 + sin(time * 0.11) * 0.20, 0.5 + cos(time * 0.09) * 0.18);
    baseD[0] = 0.30; sprd[0] = 0.25; ph[0] = 0.000;

    pos[1]   = vec2(0.3 + cos(time * 0.13) * 0.12, 0.4 + sin(time * 0.15) * 0.12);
    baseD[1] = 0.65; sprd[1] = 0.18; ph[1] = 2.094;

    pos[2]   = vec2(0.7 + sin(time * 0.08 + 1.0) * 0.10, 0.6 + cos(time * 0.12) * 0.10);
    baseD[2] = 0.15; sprd[2] = 0.30; ph[2] = 4.189;

    pos[3]   = vec2(0.5 + cos(time * 0.17 + 2.0) * 0.25, 0.5 + sin(time * 0.14) * 0.22);
    baseD[3] = 0.80; sprd[3] = 0.12; ph[3] = 1.047;

    // ---- Vacuum background
    vec3 color = vacuumBackground(uv, time);

    // ---- Composite quantum objects
    for (int i = 0; i < 4; i++) {
        vec2  aspect     = vec2(u_resolution.x / u_resolution.y, 1.0);
        float mdist      = length((uv - pos[i]) * aspect);

        // Collapse intensity: 0 = superposed, 1 = fully collapsed
        float collapseT  = smoothstep(COLLAPSE_RADIUS, COLLAPSE_RADIUS * 0.25, mdist);

        vec3 superposed  = superposedObject(uv, pos[i], baseD[i], sprd[i], ph[i], time);
        vec3 collapsed   = collapsedObject (uv, pos[i], baseD[i], sprd[i], ph[i],
                                            max(0.0, (1.0 - collapseT) * 3.0), time);

        vec3 objColor    = mix(superposed, collapsed, collapseT);

        // Alpha: superposed objects have wider, fainter presence
        float objAlpha   = clamp(
            length(superposed) * (1.0 - collapseT) * 0.9 +
            length(collapsed)  *        collapseT  * 1.2,
            0.0, 0.92);

        // Collapse ring — visible "wave function boundary" as mouse approaches
        float ringR  = COLLAPSE_RADIUS * 0.6;
        float ring   = smoothstep(0.006, 0.0, abs(mdist - ringR)) * collapseT;
        objColor    += ring * vec3(0.5, 1.0, 0.7);

        color = mix(color, objColor, objAlpha);
    }

    // ---- Decoherence field — low-level quantum shimmer across the whole frame
    float decohere = noise(uv * 5.0 + vec2(time * 0.4, -time * 0.3)) * 0.04;
    color += vec3(decohere * 0.5, decohere * 0.2, decohere);

    // ---- Vignette
    float vig = 1.0 - dot(centered, centered) * 0.7;
    color *= clamp(vig, 0.2, 1.0);

    // ---- Scanline
    float scanline = sin(uv.y * u_resolution.y * 0.9) * 0.02 + 0.98;
    color *= scanline;

    gl_FragColor = vec4(color, 1.0);
}
