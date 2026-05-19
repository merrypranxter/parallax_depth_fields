// BIOLOGICAL PARALLAX — Predator / Prey Eye Mode Morphing
// Predators: forward-facing eyes → binocular depth, narrow FOV, tunnel vision
// Prey: side-facing eyes → panoramic wrap, minimal depth, maximum coverage
//
// A "threat level" parameter morphs continuously between these two modes.
// Under threat: eyes move forward, depth snaps sharp, world compresses.
// At peace: eyes widen, panorama expands, depth becomes irrelevant.
// Everything gets chromatic coded differently per mode.
//
// "Evolution is a depth shader. Predators developed z-buffer. Prey developed
//  wraparound render texture. Neither can see what the other sees."

precision highp float;

uniform vec2  u_resolution;
uniform float u_time;
uniform vec2  u_mouse;

// PARAMETERS
const float THREAT_LEVEL        = 0.5;  // 0=peaceful prey, 1=apex predator
const float CHROMATIC_INTENSITY = 1.0;
const float PARALLAX_STRENGTH   = 0.12;
const float MAX_BLUR            = 18.0;
const float FOCAL_DEPTH_PREY    = 0.5;  // Prey: mid-focus
const float FOCAL_DEPTH_PRED    = 0.3;  // Predator: focuses near (threat is close)
const float TIME_SCALE          = 1.0;

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

// ---- Scene content ----------------------------------------------------------

vec3 sceneContent(vec2 uv, float depth, float time) {
    float n1 = noise(uv * 4.0  + time * 0.08);
    float n2 = noise(uv * 9.0  - time * 0.06);
    float n3 = noise(uv * 18.0 + time * 0.12);

    vec3 near = vec3(0.85, 0.70, 0.40);   // Warm golden foreground
    vec3 mid  = vec3(0.30, 0.65, 0.40);   // Lush green midground
    vec3 far  = vec3(0.50, 0.65, 0.80);   // Cool hazy background

    vec3 col = mix(near, mid, smoothstep(0.0, 0.5, depth));
    col      = mix(col, far, smoothstep(0.5, 1.0, depth));

    float detail = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;
    return col * (0.6 + 0.5 * detail);
}

// ---- PREDATOR EYE MODEL -----------------------------------------------------
// Forward-facing, binocular. Deep stereo depth. Sharp in center, fade at edges.
// Chromatic: warm near (prey body heat), cool far (foliage, sky).

vec3 predatorVision(vec2 uv, float focalDepth, float time) {
    vec2 centered = uv - 0.5;
    centered.x   *= u_resolution.x / u_resolution.y;

    // Binocular overlap zone — sharp in the center wedge, falls off laterally
    float lateralFade = 1.0 - smoothstep(0.3, 0.55, abs(centered.x));

    // Depth-encoded chromatic: predators see infra-red → chromatic aberration becomes
    // thermal. Warm = near = prey. Cool = far = background.
    // Red channel: displaced as per depth (heat-coded near)
    // Blue: farfield
    vec3 color = vec3(0.0);
    float totalW = 0.0;

    for (int i = 0; i < 5; i++) {
        float depth  = float(i) / 4.0;
        float disp   = (depth - focalDepth) * PARALLAX_STRENGTH * CHROMATIC_INTENSITY;

        // Warm near colors, cool far
        vec3 col;
        col.r = sceneContent(uv + vec2(disp * 1.4,  0.0 ), depth, time).r;
        col.g = sceneContent(uv + vec2(disp * 0.5,  0.0 ), depth, time).g;
        col.b = sceneContent(uv + vec2(disp * -1.0, 0.0 ), depth, time).b;

        // Focus weight
        float w = exp(-pow((depth - focalDepth) * 4.0, 2.0)) + 0.08;
        color  += col * w;
        totalW += w;
    }
    color /= totalW;

    // Binocular tunnel: sharp center, fade periphery
    float vig = lateralFade * lateralFade;
    color    *= mix(0.15, 1.0, vig);

    // Predator color palette: slight IR tint — reds enhanced, blues suppressed
    color.r  *= 1.15;
    color.g  *= 1.0;
    color.b  *= 0.8;

    // Target lock: high-contrast red tracking on detected movement
    vec2 targetPos = vec2(0.5 + sin(time * 0.7) * 0.12, 0.5 + cos(time * 0.5) * 0.08);
    float targetDist = length(centered - (targetPos - 0.5) * vec2(u_resolution.x / u_resolution.y, 1.0));
    float targetRing = smoothstep(0.005, 0.0, abs(targetDist - 0.07)) * 0.8;
    color = mix(color, vec3(1.0, 0.1, 0.05), targetRing);

    // Saccade tremor: involuntary eye movement during fixation
    float saccade = noise(vec2(time * 5.0, 1.7)) * 0.003;
    color        = mix(color, sceneContent(uv + saccade, 0.3, time) * vec3(1.1, 0.9, 0.7), 0.05);

    return color;
}

// ---- PREY EYE MODEL ---------------------------------------------------------
// Side-facing, panoramic. Wide FOV (180°+ simulated via warping).
// Almost no stereoscopic depth. Flat, alert, sensitive to motion at periphery.
// Chromatic: no depth separation — colors are uniform across field.
// Peripheral enhancement — edges are SHARPER than center (anti-predator).

vec3 preyVision(vec2 uv, float time) {
    vec2  centered = uv - 0.5;
    centered.x    *= u_resolution.x / u_resolution.y;

    // Panoramic wrap: expand horizontal FOV
    // Map x from [-0.5*aspect, 0.5*aspect] to a wider virtual angle
    float angle = atan(centered.x * 2.5);   // tan mapping simulates wide lens
    float y     = centered.y;
    vec2  warpedUV = vec2(angle / 3.14159 + 0.5, y * 0.8 + 0.5);

    // Minimal depth discrimination: everything at ~same depth (no parallax)
    float n1 = noise(warpedUV * 3.0  + time * 0.04);
    float n2 = noise(warpedUV * 7.0  - time * 0.03);
    float n3 = noise(warpedUV * 14.0 + time * 0.05);

    // Prey color palette: muted, natural — grass, sky, bark
    vec3 grass = vec3(0.38, 0.60, 0.25);
    vec3 sky   = vec3(0.55, 0.72, 0.88);
    vec3 bark  = vec3(0.40, 0.28, 0.15);

    float horizont = smoothstep(0.35, 0.50, warpedUV.y + n1 * 0.04);
    vec3 col       = mix(bark, grass, horizont);
    col            = mix(col, sky, smoothstep(0.50, 0.70, warpedUV.y));

    float detail = n1 * 0.4 + n2 * 0.35 + n3 * 0.25;
    col         *= 0.6 + 0.5 * detail;

    // Motion detection: peripheral movement highlighted in green
    float motionX = abs(cos(time * 1.3 + warpedUV.x * 10.0)) * 0.5;
    float motionY = abs(sin(time * 0.9 + warpedUV.y * 8.0)) * 0.5;
    float motion  = motionX * motionY * noise(warpedUV * 5.0 + time * 2.0);
    // Motion is brightest at periphery, not center
    float periph  = abs(centered.x);
    col          += motion * periph * vec3(0.1, 0.4, 0.1) * 0.5;

    // Prey chromatic: VERY little aberration — flat vision needs accurate edges
    // Tiny hint of yellow-blue axis (the non-opponent axis — safe for prey)
    float edgeSplit = 0.005;
    vec3  splitCol;
    splitCol.r = noise(warpedUV + vec2(edgeSplit, 0.0) + time * 0.04);
    splitCol.g = col.g;
    splitCol.b = noise(warpedUV - vec2(edgeSplit, 0.0) + time * 0.04);
    col = mix(col, col * 0.8 + splitCol * 0.2, 0.2);

    // Peripheral sharpness: enhance edges far from center
    float sharpFactor = smoothstep(0.15, 0.4, length(centered));
    float edgeH = abs(col.r - noise(warpedUV + vec2(0.002, 0.0) + time * 0.04)) * sharpFactor;
    col += edgeH * 0.15;

    // Wide-angle vignetting (circular, not tunneled — opposite of predator)
    float vig = 1.0 - smoothstep(0.6, 0.85, length(centered)) * 0.5;
    col *= vig;

    return col;
}

// ---- Main -------------------------------------------------------------------

void main() {
    vec2  uv      = gl_FragCoord.xy / u_resolution.xy;
    vec2  centered = uv - 0.5;
    centered.x   *= u_resolution.x / u_resolution.y;

    float time    = u_time * TIME_SCALE;
    vec2  mouseUV = u_mouse / u_resolution;

    // Mouse controls threat level: left = peaceful prey, right = alert predator
    float threat  = mix(THREAT_LEVEL, mouseUV.x, 0.6);
    threat        = clamp(threat, 0.0, 1.0);

    // Also: threat level pulses slightly (arousal state fluctuation)
    threat += sin(time * 0.4) * 0.05 * (1.0 - threat);
    threat  = clamp(threat, 0.0, 1.0);

    // Focal depth morphs: predator focuses near (threat), prey focuses mid
    float focalDepth = mix(FOCAL_DEPTH_PREY, FOCAL_DEPTH_PRED, threat);

    // ---- Sample both eye modes
    vec3 predColor = predatorVision(uv, focalDepth, time);
    vec3 preyColor = preyVision(uv, time);

    // ---- Blend based on threat
    // The transition isn't linear — there's a snapping quality to it
    // (like a camera lens rapidly changing aperture)
    float blendT = smoothstep(0.35, 0.65, threat);
    vec3  color  = mix(preyColor, predColor, blendT);

    // ---- Transition artifact: at the exact blend point, brief desaturation flash
    float transitionFlash = exp(-pow((threat - 0.5) * 6.0, 2.0)) * 0.15;
    float lum = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(color, vec3(lum), transitionFlash);

    // ---- Pupil dilation: high threat = narrow pupil (less light, more depth)
    // Simulated by vignetting that tightens with threat
    float pupilVig = 1.0 - dot(centered, centered) * mix(0.4, 1.5, threat);
    color *= clamp(pupilVig, 0.0, 1.0);

    // ---- Adrenaline chromatic shift: under high threat, peripheral chroma fringes
    float adrenChrom = threat * 0.012;
    vec3 adrenSplit;
    adrenSplit.r = mix(predatorVision(uv + vec2(adrenChrom,  0.0), focalDepth, time),
                       preyVision(uv + vec2(adrenChrom, 0.0), time), 1.0 - blendT).r;
    adrenSplit.g = color.g;
    adrenSplit.b = mix(predatorVision(uv - vec2(adrenChrom * 0.8, 0.0), focalDepth, time),
                       preyVision(uv - vec2(adrenChrom * 0.8, 0.0), time), 1.0 - blendT).b;
    float periph = length(centered) / 0.5;
    color = mix(color, adrenSplit, periph * threat * 0.4);

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
