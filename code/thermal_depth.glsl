// THERMAL DEPTH — FLIR / Predator Vision
// Temperature IS depth. Heat = proximity. Cold = distance.
// The chromatic separation isn't wavelength-based — it's thermal gradient:
// each channel carries a different temperature band, creating false-color depth.
//
// Near-hot objects: white → yellow → orange → red
// Mid-temperature: cyan → green
// Far-cold background: blue → violet → black
//
// "The predator doesn't see you. It sees the 98.6°F irregularity
//  in an otherwise 72° world. You are a heat signature.
//  Everything else is just atmosphere."

precision highp float;

uniform vec2  u_resolution;
uniform float u_time;
uniform vec2  u_mouse;

// PARAMETERS
const float FOCAL_TEMP    = 0.5;    // "Temperature" in focus (0=cold/far, 1=hot/near)
const float THERMAL_NOISE = 0.04;   // Sensor noise level (FLIR cameras are noisy)
const float HEAT_SHIMMER  = 0.008;  // Atmospheric distortion above hot surfaces
const float SCAN_SPEED    = 0.5;    // FLIR scan artifact speed
const float MAX_BLUR      = 8.0;    // Thermal cameras have less resolution = softer
const float TIME_SCALE    = 1.0;

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

float fbm(vec2 p, int octaves) {
    float v = 0.0, amp = 0.5, freq = 1.0;
    for (int i = 0; i < octaves; i++) {
        v += noise(p * freq) * amp;
        amp  *= 0.5;
        freq *= 2.0;
    }
    return v;
}

// ---- FLIR iron palette ------------------------------------------------------
// Maps [0,1] thermal value to the standard FLIR "iron" false-color palette.
// 0.0 = cold (black → purple → blue)
// 0.5 = medium (cyan → green → yellow)
// 1.0 = hot (orange → red → white)

vec3 flirIron(float t) {
    t = clamp(t, 0.0, 1.0);

    vec3 cold  = vec3(0.00, 0.00, 0.00);   // 0.0
    vec3 cool  = vec3(0.25, 0.00, 0.50);   // 0.15
    vec3 blue  = vec3(0.00, 0.20, 0.80);   // 0.25
    vec3 cyan  = vec3(0.00, 0.75, 0.80);   // 0.40
    vec3 green = vec3(0.20, 0.80, 0.20);   // 0.50
    vec3 yell  = vec3(0.90, 0.85, 0.10);   // 0.65
    vec3 orang = vec3(0.95, 0.45, 0.05);   // 0.80
    vec3 red   = vec3(0.90, 0.05, 0.05);   // 0.90
    vec3 white = vec3(1.00, 1.00, 1.00);   // 1.0

    vec3 col;
    col =              mix(cold,  cool,  smoothstep(0.00, 0.15, t));
    col = mix(col,     blue,              smoothstep(0.15, 0.25, t));
    col = mix(col,     cyan,              smoothstep(0.25, 0.40, t));
    col = mix(col,     green,             smoothstep(0.40, 0.50, t));
    col = mix(col,     yell,              smoothstep(0.50, 0.65, t));
    col = mix(col,     orang,             smoothstep(0.65, 0.80, t));
    col = mix(col,     red,               smoothstep(0.80, 0.90, t));
    col = mix(col,     white,             smoothstep(0.90, 1.00, t));
    return col;
}

// ---- Thermal scene generator ------------------------------------------------
// Simulates a thermal scene: hot bodies, cool atmosphere, heat plumes

float thermalScene(vec2 uv, float time) {
    // Base ambient temperature (the room)
    float ambient = 0.18 + noise(uv * 2.0 + time * 0.03) * 0.05;

    // Heat sources: three "bodies" with different temperatures
    vec2 src0 = vec2(0.5 + sin(time * 0.12) * 0.25, 0.5 + cos(time * 0.09) * 0.18);
    vec2 src1 = vec2(0.3 + cos(time * 0.15) * 0.10, 0.7 + sin(time * 0.11) * 0.12);
    vec2 src2 = vec2(0.7 + sin(time * 0.08) * 0.12, 0.3 + cos(time * 0.13) * 0.10);

    float h0 = 0.82 * exp(-length(uv - src0) * length(uv - src0) * 18.0);
    float h1 = 0.65 * exp(-length(uv - src1) * length(uv - src1) * 25.0);
    float h2 = 0.75 * exp(-length(uv - src2) * length(uv - src2) * 22.0);

    // Heat plume: warm air rises above each source (upward distortion)
    float plumeY0 = smoothstep(src0.y + 0.05, src0.y + 0.25, uv.y);
    float plumeX0 = exp(-pow((uv.x - src0.x) * 8.0, 2.0));
    float plume0  = plumeX0 * plumeY0 * 0.25
                   * (0.7 + noise(uv * 8.0 - vec2(0.0, time * 0.4)) * 0.3);

    // Combine heat contributions
    float temp = ambient + h0 + h1 + h2 + plume0;
    return clamp(temp, 0.0, 1.0);
}

// Heat shimmer distortion: hot surfaces bend light like a mirage
vec2 heatDistortion(vec2 uv, float temp, float time) {
    // Shimmer is stronger above hot areas and oscillates upward
    float shimStr = HEAT_SHIMMER * temp * temp;
    float dx = noise(uv * 15.0 + vec2(time * 1.2, 0.0))  * 2.0 - 1.0;
    float dy = noise(uv * 15.0 + vec2(0.0, time * 0.8)) * 2.0 - 1.0;
    // Distortion is primarily horizontal (mirage effect)
    return uv + vec2(dx * shimStr, dy * shimStr * 0.3);
}

// ---- Chromatic thermal separation -------------------------------------------
// Each temperature band corresponds to a different spectral channel
// This is the "chromatic parallax" equivalent for thermal imaging

vec3 thermalChromatic(vec2 uv, float focalTemp, float time) {
    // Distort uv by heat shimmer first
    float rawTemp = thermalScene(uv, time);
    vec2  distUV  = heatDistortion(uv, rawTemp, time);

    float temp    = thermalScene(distUV, time);

    // Focal offset: temperature = depth analog
    float depthOffset = temp - focalTemp;

    // Each band has a slightly different spatial origin (thermal parallax)
    // Hot band (red): displaced by depth
    // Neutral band (green): reference
    // Cold band (blue): displaced opposite direction
    float hotDisp  = depthOffset * 0.06;
    float coldDisp = depthOffset * -0.04;

    float hotTemp  = thermalScene(distUV + vec2(hotDisp,  0.0),           time);
    float midTemp  = thermalScene(distUV,                                  time);
    float coldTemp = thermalScene(distUV + vec2(coldDisp, coldDisp * 0.2), time);

    // Convert each to its thermal color band, then extract channels for false-color split
    vec3 hotCol  = flirIron(hotTemp);
    vec3 midCol  = flirIron(midTemp);
    vec3 coldCol = flirIron(coldTemp);

    // Combine as chromatic separation: hot → red channel, cold → blue channel
    vec3 col = vec3(
        hotCol.r  * 0.6 + midCol.r * 0.4,
        midCol.g,
        coldCol.b * 0.6 + midCol.b * 0.4
    );

    return col;
}

// ---- FLIR sensor artifacts --------------------------------------------------
// Real FLIR cameras have characteristic noise and scan artifacts

vec3 flirArtifacts(vec2 uv, vec3 color, float time) {
    // Sensor noise (shot noise — each pixel independently varies)
    float sensorNoise = (hash(uv * u_resolution + floor(time * 30.0) * 7.13) - 0.5)
                        * THERMAL_NOISE * 2.0;
    color += sensorNoise;

    // Fixed-pattern noise: faint column/row nonuniformity (common in uncooled FPAs)
    float columnNoise = (hash(vec2(uv.x * u_resolution.x, floor(time * 0.5))) - 0.5) * 0.015;
    color += columnNoise;

    // Scan artifact: faint horizontal "scan line" rolls up the frame
    float scanPos   = fract(time * SCAN_SPEED);
    float scanLine  = smoothstep(0.005, 0.0, abs(uv.y - scanPos)) * 0.08;
    color          += scanLine * vec3(0.5, 0.8, 0.6);

    // Bad pixel: one stuck hot pixel, position jittered by time
    vec2 badPx = vec2(
        hash(vec2(floor(time * 0.1), 1.0)),
        hash(vec2(floor(time * 0.1), 2.0))
    );
    float bpDist = length(uv - badPx) * u_resolution.x;
    if (bpDist < 1.5) color = mix(color, vec3(1.0, 1.0, 1.0), 0.8);

    return color;
}

// ---- Targeting reticle ------------------------------------------------------
// Minimal thermal-style targeting box

float thermalReticle(vec2 uv, vec2 center, float size, float time) {
    vec2 p = uv - center;
    p.x *= u_resolution.x / u_resolution.y;

    // Corner brackets only — thermal imagers don't draw full boxes
    vec2 q    = abs(p) - vec2(size, size * 0.75);
    float bLen = size * 0.25;

    // L-shape at each corner
    float hArm = max(abs(q.y) - 0.001, 0.0);
    float vArm = max(abs(q.x) - 0.001, 0.0);
    float h    = length(vec2(max(-q.x - bLen, 0.0), hArm)) - 0.001;
    float v    = length(vec2(vArm, max(-q.y - bLen, 0.0))) - 0.001;

    return smoothstep(0.003, 0.0, min(h, v));
}

// ---- Main -------------------------------------------------------------------

void main() {
    vec2  uv      = gl_FragCoord.xy / u_resolution.xy;
    vec2  centered = uv - 0.5;
    centered.x   *= u_resolution.x / u_resolution.y;

    float time    = u_time * TIME_SCALE;
    vec2  mouseUV = u_mouse / u_resolution;

    // Mouse Y shifts focal temperature (what temperature is "in focus")
    float focalTemp = mix(FOCAL_TEMP, mouseUV.y, 0.5);

    // ---- Thermal image with chromatic separation
    vec3 color = thermalChromatic(uv, focalTemp, time);

    // ---- Depth-of-field: off-focal-temp regions are softer (sensor pixel blur)
    float rawTemp = thermalScene(uv, time);
    float tempDist = abs(rawTemp - focalTemp);
    float blurR   = tempDist * tempDist * MAX_BLUR;
    if (blurR > 0.5) {
        vec3 blurred = vec3(0.0);
        for (int i = 0; i < 6; i++) {
            float ang = float(i) / 6.0 * 6.28318 + time * 0.1;
            float r   = blurR / u_resolution.x;
            blurred  += thermalChromatic(uv + vec2(cos(ang), sin(ang)) * r, focalTemp, time);
        }
        blurred /= 6.0;
        color = mix(color, blurred, clamp(blurR / MAX_BLUR, 0.0, 0.85));
    }

    // ---- FLIR sensor artifacts
    color = flirArtifacts(uv, color, time);

    // ---- Targeting reticle on the hottest detected target
    vec2 hotTarget = vec2(0.5 + sin(time * 0.12) * 0.25, 0.5 + cos(time * 0.09) * 0.18);
    float ret = thermalReticle(uv, hotTarget, 0.07, time);
    vec3 retColor = mix(vec3(0.2, 1.0, 0.4), vec3(1.0, 0.3, 0.1), sin(time * 8.0) * 0.5 + 0.5);
    color = mix(color, retColor, ret * 0.85);

    // ---- Vignette (thermal cameras have heavy vignetting)
    float vig = 1.0 - dot(centered, centered) * 0.9;
    color *= clamp(vig, 0.2, 1.0);

    gl_FragColor = vec4(color, 1.0);
}
