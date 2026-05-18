// PARADOXICAL DEPTH
// Recursive depth layers containing each other.
// Plane A shows Plane B. Plane B contains a reflection of Plane A.
// Chromatic separation compounds with each recursion.
// "The room contains a picture of the room containing a picture of the room..."

precision highp float;

uniform vec2 u_resolution;
uniform float u_time;
uniform vec2 u_mouse;

// PARAMETERS
const float RECURSION_DEPTH = 3.0;      // How many levels deep (keep low for performance)
const float CHROMATIC_INTENSITY = 1.5;   // Amped up — recursion will compound this
const float PARALLAX_STRENGTH = 0.08;
const float GLITCH_AMOUNT = 0.3;         // Intentional corruption between layers

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

// Content for a specific depth level
vec3 levelContent(vec2 uv, float level, float time) {
    float scale = 2.0 + level * 3.0;
    float n = noise(uv * scale + vec2(time * 0.1, time * 0.15));
    
    // Each recursion level gets a different color temperature
    // Levels cycle: hot → cold → hot as we go deeper
    float cycle = sin(level * 1.57); // pi/2 phase per level
    
    vec3 hot = vec3(0.95, 0.3, 0.6);    // Pink-orange
    vec3 cold = vec3(0.1, 0.7, 0.95);    // Cyan-blue
    vec3 weird = vec3(0.7, 0.9, 0.2);     // Acid green
    
    vec3 col = mix(hot, cold, smoothstep(-1.0, 0.0, cycle));
    col = mix(col, weird, smoothstep(0.0, 1.0, cycle));
    
    // Grid that gets progressively more corrupted
    float grid = max(
        abs(sin(uv.x * scale * 8.0)),
        abs(sin(uv.y * scale * 8.0))
    );
    grid = pow(grid, 10.0 + level * 5.0); // Sharper at deeper levels
    
    // "Window" into next level — a rectangle that shows the next recursion
    float windowSize = 0.3 - level * 0.05;
    vec2 windowCenter = vec2(0.5 + sin(time + level) * 0.2, 0.5 + cos(time * 0.7 + level) * 0.15);
    vec2 windowUV = abs(uv - windowCenter);
    float inWindow = step(windowUV.x, windowSize) * step(windowUV.y, windowSize * 0.75);
    
    // Corruption: sometimes the window shows the WRONG level
    float glitchSwap = step(hash(vec2(level, floor(time * 2.0))), GLITCH_AMOUNT);
    float displayedLevel = level + 1.0 + glitchSwap * 2.0;
    
    // The "portal" effect — inside the window we sample the NEXT level
    // But we also apply chromatic separation PER level
    vec3 portalColor = col * (0.6 + 0.4 * n);
    portalColor += grid * 0.4;
    
    // Add chromatic edge to the window boundary
    float edge = inWindow * (1.0 - inWindow); // Not quite right but creates a glow
    edge = smoothstep(0.0, 0.1, edge);
    
    return portalColor + edge * vec3(1.0, 0.5, 0.8) * 0.5;
}

// Recursive chromatic sampling
// Each level applies its own displacement, compounding the effect
vec3 recursiveSample(vec2 uv, float targetLevel, float currentLevel, float time) {
    if (currentLevel >= RECURSION_DEPTH) {
        // Base case: just return content at this level
        return levelContent(uv, targetLevel, time);
    }
    
    // Chromatic displacement increases with each recursion
    float displacement = (currentLevel + 1.0) * PARALLAX_STRENGTH * CHROMATIC_INTENSITY;
    
    // Compound the offsets
    vec2 rUV = uv + vec2(displacement * 1.3, 0.0);
    vec2 gUV = uv + vec2(displacement * 0.5, 0.0);
    vec2 bUV = uv + vec2(displacement * -0.8, displacement * 0.3); // Slight vertical too
    
    vec3 col;
    col.r = recursiveSample(rUV, targetLevel, currentLevel + 1.0, time).r;
    col.g = recursiveSample(gUV, targetLevel, currentLevel + 1.0, time).g;
    col.b = recursiveSample(bUV, targetLevel, currentLevel + 1.0, time).b;
    
    // At each recursion level, add the "local" content as an overlay
    vec3 local = levelContent(uv, currentLevel, time);
    float localMix = 0.3; // How much the local level shows through
    
    return mix(col, local, localMix);
}

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution.xy;
    vec2 centered = uv - 0.5;
    centered.x *= u_resolution.x / u_resolution.y;
    
    float time = u_time;
    
    // Mouse controls which level we "focus" on
    float mouseLevel = floor((u_mouse.y / u_resolution.y) * RECURSION_DEPTH);
    mouseLevel = clamp(mouseLevel, 0.0, RECURSION_DEPTH - 1.0);
    
    // Start recursion from level 0
    vec3 color = recursiveSample(uv, mouseLevel, 0.0, time);
    
    // Global chromatic separation on the final output
    // This makes the ENTIRE recursive structure feel like it's splitting apart
    float globalSplit = sin(time * 0.5) * 0.02 * CHROMATIC_INTENSITY;
    vec3 finalSplit;
    finalSplit.r = recursiveSample(uv + vec2(globalSplit, 0.0), mouseLevel, 0.0, time).r;
    finalSplit.g = color.g;
    finalSplit.b = recursiveSample(uv + vec2(-globalSplit * 1.5, 0.0), mouseLevel, 0.0, time).b;
    
    color = mix(color, finalSplit, 0.4);
    
    // Vignette
    float vig = 1.0 - dot(centered, centered) * 0.7;
    color *= clamp(vig, 0.2, 1.0);
    
    // "Data corruption" noise
    float corruption = hash(uv * 100.0 + fract(time) * 10.0);
    if (corruption > 0.97) {
        color = vec3(1.0, 0.9, 0.2); // Flash of acid yellow
    }
    
    gl_FragColor = vec4(color, 1.0);
}
