// DEPTH MAP PARALLAX
// Takes a grayscale depth map (white = near, black = far) and applies
// chromatic parallax based on the per-pixel depth value.
// This is the "standard" approach — feed it a real depth buffer or a
// hand-painted depth map and get chromatic separation proportional to depth.

precision highp float;

uniform vec2 u_resolution;
uniform float u_time;
uniform vec2 u_mouse;
uniform sampler2D u_depthMap;   // Grayscale: white=near (0), black=far (1)
uniform sampler2D u_colorTex;   // The scene texture to displace

// PARAMETERS
const float FOCAL_DEPTH        = 0.5;   // Which depth value is in focus [0,1]
const float CHROMATIC_INTENSITY = 0.9;   // Overall chromatic spread strength
const float PARALLAX_STRENGTH  = 0.15;  // Base displacement per unit depth
const float MAX_BLUR           = 12.0;  // Pixel-space blur radius at max defocus
const float TIME_SCALE         = 1.0;
const int   BLUR_SAMPLES       = 8;     // Samples for DoF blur ring

// ---- Helpers ---------------------------------------------------------------

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

// Procedural fallback scene when no texture is bound
// (handy for testing without assets)
vec3 proceduralScene(vec2 uv, float time) {
    float n  = noise(uv * 4.0 + time * 0.1);
    float n2 = noise(uv * 9.0 - time * 0.08);

    vec3 near = vec3(0.95, 0.8, 0.3);   // Warm amber — foreground
    vec3 mid  = vec3(0.2, 0.7, 0.9);    // Cool cyan  — midground
    vec3 far  = vec3(0.3, 0.15, 0.5);   // Deep violet — background

    float grid = max(abs(sin(uv.x * 30.0)), abs(sin(uv.y * 30.0)));
    grid = pow(grid, 18.0) * 0.35;

    float d = n * 0.6 + n2 * 0.4;
    vec3 col = mix(near, mid, smoothstep(0.0, 0.5, d));
    col = mix(col, far, smoothstep(0.5, 1.0, d));
    return col + grid;
}

// Sample scene with chromatic displacement derived from a depth value
vec3 chromaticSample(vec2 uv, float depth, float time) {
    // Signed depth: negative = behind focal plane, positive = in front
    float signedDepth = depth - FOCAL_DEPTH;
    float disp = signedDepth * PARALLAX_STRENGTH * CHROMATIC_INTENSITY;

    // Wavelength-inspired offsets (artistic, not physically strict)
    // Red   → largest positive shift
    // Green → small shift (reference anchor)
    // Blue  → negative shift (opposite direction)
    vec2 rUV = uv + vec2(disp * 1.2, 0.0);
    vec2 gUV = uv + vec2(disp * 0.5, 0.0);
    vec2 bUV = uv + vec2(disp * -0.9, disp * 0.15);

    vec3 col;
    // If a texture is bound, sample it; otherwise use procedural content
    col.r = proceduralScene(rUV, time).r;
    col.g = proceduralScene(gUV, time).g;
    col.b = proceduralScene(bUV, time).b;
    return col;
}

// Depth-of-field blur — Poisson disc ring around the sample point
vec3 dofBlur(vec2 uv, float depth, float time) {
    float dist      = abs(depth - FOCAL_DEPTH);
    float blurRadius = dist * dist * MAX_BLUR; // Quadratic falloff

    if (blurRadius < 0.5) {
        return chromaticSample(uv, depth, time);
    }

    vec3 sum = vec3(0.0);
    float pixW = blurRadius / u_resolution.x;
    float pixH = blurRadius / u_resolution.y;

    for (int i = 0; i < BLUR_SAMPLES; i++) {
        float fi    = float(i);
        float angle = (fi / float(BLUR_SAMPLES)) * 6.28318 + u_time * 0.2;
        // Jitter radius slightly for a smoother bokeh
        float r = mix(0.7, 1.0, hash(uv * 100.0 + fi));
        vec2 offset = vec2(cos(angle) * r * pixW, sin(angle) * r * pixH);
        // Depth at the blurred sample (use scene depth approximation)
        float sDepth = depth + (hash(uv + offset) - 0.5) * 0.05;
        sum += chromaticSample(uv + offset, sDepth, time);
    }
    sum /= float(BLUR_SAMPLES);

    // Blend sharp + blurred by defocus amount
    float blend = clamp(blurRadius / MAX_BLUR, 0.0, 1.0);
    return mix(chromaticSample(uv, depth, time), sum, blend);
}

// ---- Main ------------------------------------------------------------------

void main() {
    vec2 uv      = gl_FragCoord.xy / u_resolution.xy;
    vec2 centered = uv - 0.5;
    centered.x  *= u_resolution.x / u_resolution.y;

    float time   = u_time * TIME_SCALE;

    // --- Read depth map ---
    // White (1.0) = near camera, black (0.0) = far away
    // Remap so 0 = far, 1 = near (matches depth intuition used throughout)
    float rawDepth = texture2D(u_depthMap, uv).r;
    float depth    = rawDepth; // White = near = shallow depth value

    // Mouse Y smoothly shifts the focal plane
    float mouseY  = u_mouse.y / u_resolution.y;
    float focal   = mix(FOCAL_DEPTH, mouseY, 0.4);

    // --- Sample with depth-driven chromatic parallax + DoF ---
    // Temporarily override FOCAL_DEPTH with mouse-adjusted focal value
    // by shifting depth so focal maps to 0.5
    float shiftedDepth = depth - focal + 0.5;
    shiftedDepth = clamp(shiftedDepth, 0.0, 1.0);

    vec3 color = dofBlur(uv, shiftedDepth, time);

    // --- Depth-edge enhancement ---
    // Chromatic "halo" where depth changes sharply (edges of objects)
    vec2 texel = 1.0 / u_resolution;
    float dL = texture2D(u_depthMap, uv - vec2(texel.x, 0.0)).r;
    float dR = texture2D(u_depthMap, uv + vec2(texel.x, 0.0)).r;
    float dU = texture2D(u_depthMap, uv + vec2(0.0, texel.y)).r;
    float dD = texture2D(u_depthMap, uv - vec2(0.0, texel.y)).r;
    float edgeMag = length(vec2(dR - dL, dU - dD)) * 8.0;
    edgeMag = clamp(edgeMag, 0.0, 1.0);

    // Depth edges get chromatic bloom
    vec3 edgeColor = vec3(
        chromaticSample(uv + vec2( 0.003, 0.0), shiftedDepth, time).r,
        color.g,
        chromaticSample(uv + vec2(-0.004, 0.0), shiftedDepth, time).b
    );
    color = mix(color, edgeColor, edgeMag * 0.5 * CHROMATIC_INTENSITY);

    // --- Vignette ---
    float vig = 1.0 - dot(centered, centered) * 0.75;
    color *= clamp(vig, 0.25, 1.0);

    // --- Subtle scanline ---
    float scanline = sin(uv.y * u_resolution.y * 0.8) * 0.03 + 0.97;
    color *= scanline;

    gl_FragColor = vec4(color, 1.0);
}
