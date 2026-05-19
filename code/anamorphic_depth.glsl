// ANAMORPHIC DEPTH — Horizontal Squeeze, Oval Bokeh, Lens Flares
// Simulates anamorphic lens optics: cylindrical elements squeeze horizontal FOV
// onto a standard sensor. Horizontal and vertical depth perception diverge.
// Depth exists in two axes, each with its own chromatic signature.
//
// Horizontal parallax: compressed, dreamlike, cinematic
// Vertical parallax: natural perspective
// Bokeh: oval (wider than tall) on background highlights
// Lens flares: horizontal anamorphic streaks across bright sources
//
// "Every wide-angle film was shot through a lens with an identity crisis.
//  Anamorphic says: the world is panoramic, but memory is wide and flat."

precision highp float;

uniform vec2  u_resolution;
uniform float u_time;
uniform vec2  u_mouse;

// PARAMETERS
const float SQUEEZE_FACTOR     = 1.6;    // Anamorphic squeeze ratio (typically 1.33–2.0×)
const float FOCAL_DEPTH        = 0.45;   // Focus distance [0,1]
const float CHROMATIC_INTENSITY = 0.9;
const float PARALLAX_H         = 0.14;   // Horizontal parallax strength
const float PARALLAX_V         = 0.06;   // Vertical parallax (less — anamorphic compresses H)
const float MAX_BLUR_H         = 30.0;   // Bokeh width (wider — oval)
const float MAX_BLUR_V         = 12.0;   // Bokeh height (narrower — oval)
const float FLARE_INTENSITY    = 0.6;
const int   NUM_PLANES         = 6;
const float TIME_SCALE         = 1.0;

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

// ---- Anamorphic UV transform ------------------------------------------------
// Squeeze the horizontal axis when sampling (as if through anamorphic glass)

vec2 anamorphicUV(vec2 uv) {
    // Center, squeeze horizontal, uncenter
    vec2 c = uv - 0.5;
    c.x   /= SQUEEZE_FACTOR;   // Horizontal is compressed
    return c + 0.5;
}

// Inverse transform (de-squeeze — as in projection)
vec2 deSqueezeUV(vec2 uv) {
    vec2 c = uv - 0.5;
    c.x   *= SQUEEZE_FACTOR;
    return c + 0.5;
}

// ---- Scene content ----------------------------------------------------------
// Wide cinematic landscape: warm foreground, cool midground, hazy background

vec3 sceneContent(vec2 uv, float depth, float time) {
    // De-squeezing the scene gives it the "wide anamorphic" look
    vec2 deuv = deSqueezeUV(uv);

    float n1 = noise(deuv * vec2(4.0, 6.0) + time * 0.07);
    float n2 = noise(deuv * vec2(8.0, 10.0) - time * 0.05);

    // Atmosphere: background gets bluish haze (atmospheric perspective)
    vec3 near = vec3(0.85, 0.65, 0.30);   // Warm amber (golden hour foreground)
    vec3 mid  = vec3(0.45, 0.60, 0.75);   // Dusty blue midground
    vec3 far  = vec3(0.55, 0.68, 0.85);   // Pale sky background (haze)

    vec3 col = mix(near, mid, smoothstep(0.0, 0.5, depth));
    col      = mix(col, far, smoothstep(0.5, 1.0, depth));

    // Landscape features: horizontal bands (hills, horizon lines)
    float horizon = smoothstep(0.45, 0.55, deuv.y + n1 * 0.05 - depth * 0.1) * 0.3;
    col = mix(col, vec3(0.3, 0.45, 0.25), horizon);  // Dark green hills

    // Bright sky: above the horizon at far depth
    float sky = smoothstep(0.50, 0.70, deuv.y) * smoothstep(0.0, 0.3, depth);
    col = mix(col, vec3(0.65, 0.78, 0.95), sky);

    // Atmospheric haze: reduce contrast and saturation at depth
    float hazeFactor = depth * 0.4;
    vec3  hazeColor  = vec3(0.7, 0.75, 0.85);
    col = mix(col, hazeColor, hazeFactor);

    return col * (0.7 + 0.3 * n1);
}

// ---- Anamorphic chromatic parallax ------------------------------------------
// Horizontal and vertical channels displace differently (the anamorphic signature)

vec3 anamorphicChromatic(vec2 uv, float depth, float time) {
    float depthOffset = depth - FOCAL_DEPTH;

    // Horizontal: large (horizontal world is compressed — less depth per pixel)
    float hR = depthOffset * PARALLAX_H * CHROMATIC_INTENSITY * 1.3;
    float hG = depthOffset * PARALLAX_H * CHROMATIC_INTENSITY * 0.4;
    float hB = depthOffset * PARALLAX_H * CHROMATIC_INTENSITY * -1.0;

    // Vertical: smaller
    float vR = depthOffset * PARALLAX_V * 0.4;
    float vB = depthOffset * PARALLAX_V * -0.3;

    vec3 col;
    col.r = sceneContent(uv + vec2(hR,  vR), depth, time);
    col.g = sceneContent(uv + vec2(hG,  0.0), depth, time);
    col.b = sceneContent(uv + vec2(hB,  vB), depth, time);

    return col;
}

// ---- Oval bokeh -------------------------------------------------------------
// Anamorphic lenses create oval out-of-focus highlights
// Wider than tall because horizontal is compressed

vec3 ovalBokeh(vec2 uv, float depth, float time) {
    float defocus  = abs(depth - FOCAL_DEPTH);
    float blurH    = defocus * defocus * MAX_BLUR_H;
    float blurV    = defocus * defocus * MAX_BLUR_V;

    if (blurH < 0.5) return anamorphicChromatic(uv, depth, time);

    vec3  sum      = vec3(0.0);
    float wTotal   = 0.0;
    int   samples  = 8;

    for (int i = 0; i < samples; i++) {
        // Oval distribution: more samples spread horizontally
        float angle = float(i) / float(samples) * 6.28318 + time * 0.05;
        // Oval sample disk
        vec2 offset = vec2(cos(angle) * blurH / u_resolution.x,
                            sin(angle) * blurV / u_resolution.y);
        // Jitter for smoother bokeh
        float r   = mix(0.6, 1.0, hash(uv * 100.0 + float(i)));
        float w   = 1.0;   // Uniform bokeh (film-like vs. Gaussian)
        sum      += anamorphicChromatic(uv + offset * r, depth, time) * w;
        wTotal   += w;
    }
    sum /= wTotal;

    float blend = clamp((blurH - 0.5) / MAX_BLUR_H, 0.0, 1.0);
    return mix(anamorphicChromatic(uv, depth, time), sum, blend);
}

// ---- Anamorphic lens flare --------------------------------------------------
// The signature anamorphic horizontal streak across bright sources

float anamorphicStreak(vec2 uv, vec2 sourcePos, float intensity, float time) {
    vec2  p   = uv - sourcePos;
    p.x      *= u_resolution.x / u_resolution.y;

    // Horizontal streak: thin vertical profile, extends across full width
    float streakH = abs(p.y) / (0.003 + abs(sourcePos.x - 0.5) * 0.002);
    float streak  = exp(-streakH * streakH * 800.0);

    // Falloff with horizontal distance from source
    float hFall   = exp(-abs(p.x) * 1.5);
    streak       *= hFall;

    // Chromatic fringe on the streak (blue edge on one side, red on other)
    return streak * intensity;
}

vec3 streakColor(vec2 uv, vec2 sourcePos, float intensity, float time) {
    vec2  p     = uv - sourcePos;
    p.x        *= u_resolution.x / u_resolution.y;

    // The streak is blue at ends, white at center
    float dist  = abs(p.x);
    float t     = clamp(dist * 3.0, 0.0, 1.0);
    vec3  streakCol = mix(vec3(0.9, 0.95, 1.0), vec3(0.2, 0.5, 1.0), t);

    return streakCol * anamorphicStreak(uv, sourcePos, intensity, time);
}

// Secondary elliptical ghosts (internal reflections)
float ellipseGhost(vec2 uv, vec2 center, float rx, float ry) {
    vec2 p = (uv - center) * vec2(1.0 / rx, 1.0 / ry);
    float r = length(p);
    return smoothstep(0.12, 0.0, abs(r - 1.0));
}

// ---- Main -------------------------------------------------------------------

void main() {
    vec2  uv      = gl_FragCoord.xy / u_resolution.xy;
    vec2  centered = uv - 0.5;
    centered.x   *= u_resolution.x / u_resolution.y;   // Pre-squeeze aspect
    // Re-correct for anamorphic frame (2.39:1 aspect)
    vec2  aCenter  = centered;
    aCenter.x     *= SQUEEZE_FACTOR;                     // De-squeezes the centered coords

    float time    = u_time * TIME_SCALE;
    vec2  mouseUV = u_mouse / u_resolution;

    // Mouse Y controls focal depth
    float focal   = mix(FOCAL_DEPTH, mouseUV.y, 0.4);

    // ---- Depth composite
    vec3  color      = vec3(0.0);
    float totalWeight = 0.0;

    for (int i = 0; i < NUM_PLANES; i++) {
        float depth  = float(i) / float(NUM_PLANES - 1);
        float weight = 1.0 - smoothstep(0.0, 0.35, abs(depth - focal));
        weight       = pow(weight, 2.0) + 0.08;

        vec3 planecol = ovalBokeh(uv, depth, time);
        color        += planecol * weight;
        totalWeight  += weight;
    }
    color /= totalWeight;

    // ---- Lens flares: two bright "sun" sources
    vec2 sunA = vec2(0.25 + sin(time * 0.07) * 0.05, 0.55 + cos(time * 0.05) * 0.03);
    vec2 sunB = vec2(0.78 + cos(time * 0.06) * 0.04, 0.48 + sin(time * 0.08) * 0.03);

    vec3 flareA = streakColor(uv, sunA, FLARE_INTENSITY, time);
    vec3 flareB = streakColor(uv, sunB, FLARE_INTENSITY * 0.6, time);

    color += flareA + flareB;

    // Ghost reflections (secondary images on the opposite side of frame center)
    vec2 ghostA = vec2(1.0 - sunA.x, 1.0 - sunA.y) * 0.7 + 0.15;
    float ghost = ellipseGhost(uv, ghostA, 0.04 * SQUEEZE_FACTOR, 0.025);
    color += ghost * vec3(0.1, 0.25, 0.5) * 0.3;

    // ---- Anamorphic lens distortion: slight barrel in H, pin in V
    // (already encoded in the de-squeeze above; here we add subtle edge softening)
    float edgeSoft = 1.0 - smoothstep(0.7, 1.0, abs(aCenter.x) / (0.5 * SQUEEZE_FACTOR));
    color *= mix(0.7, 1.0, edgeSoft);

    // ---- Vignette (anamorphic lenses have elliptical vignetting)
    float vig = 1.0 - (aCenter.x * aCenter.x * 0.6 + aCenter.y * aCenter.y * 1.2);
    color *= clamp(vig, 0.25, 1.0);

    // ---- Film grain (anamorphic is film aesthetic)
    float grain = (hash(uv * u_resolution + fract(time * 24.0) * 1000.0) - 0.5) * 0.04;
    color      += grain;

    // ---- Halation: bright areas bleed red into surroundings (film base fluorescence)
    float lum    = dot(color, vec3(0.299, 0.587, 0.114));
    float halation = smoothstep(0.7, 1.0, lum) * 0.12;
    color.r      += halation * (1.0 - lum * 0.5);   // Red bleed only

    gl_FragColor = vec4(clamp(color, 0.0, 1.5), 1.0);
}
