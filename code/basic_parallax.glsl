// PARALLAX DEPTH FIELDS — Basic 3-Layer Depth Composition
// Inside-the-box fundamentals. Clean. Predictable. Powerful.

precision highp float;

uniform vec2 u_resolution;
uniform float u_time;
uniform vec2 u_mouse;

// PARAMETERS — adjust these
const int NUM_PLANES = 5;
const float FOCAL_DEPTH = 0.5;
const float CHROMATIC_INTENSITY = 0.8;
const float PARALLAX_STRENGTH = 0.12;
const float MAX_BLUR = 15.0;
const float TIME_SCALE = 1.0;

// Simple pseudo-random
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Simple noise
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

// Content generation for a depth plane
// In practice, you'd sample a texture or raymarch a scene
vec3 planeContent(vec2 uv, float depth, float time) {
    // Procedural pattern that changes per depth plane
    float scale = 3.0 + depth * 5.0;
    float n = noise(uv * scale + time * 0.2);
    
    // Different "worlds" at different depths
    vec3 nearColor = vec3(0.9, 0.2, 0.5);   // Hot pink
    vec3 midColor  = vec3(0.1, 0.8, 0.9);   // Neon teal
    vec3 farColor  = vec3(0.4, 0.1, 0.8);   // Electric purple
    
    vec3 color = mix(nearColor, midColor, smoothstep(0.0, 0.5, depth));
    color = mix(color, farColor, smoothstep(0.5, 1.0, depth));
    
    // Grid lines that get finer with depth
    float grid = max(
        abs(sin(uv.x * scale * 10.0)),
        abs(sin(uv.y * scale * 10.0))
    );
    grid = pow(grid, 20.0);
    
    return color * (0.5 + 0.5 * n) + grid * 0.3;
}

// Chromatic parallax sampling
vec3 chromaticSample(vec2 uv, float depth) {
    float displacement = depth * PARALLAX_STRENGTH * CHROMATIC_INTENSITY;
    
    // Wavelength factors: red bends most, blue bends least (or vice versa depending on optic)
    // Here we do artistic chromatic separation, not physically accurate
    float rOffset = displacement * 1.2;
    float gOffset = displacement * 0.6;
    float bOffset = displacement * -0.9;
    
    float t = u_time * TIME_SCALE;
    
    vec3 col;
    col.r = planeContent(uv + vec2(rOffset, 0.0), depth, t).r;
    col.g = planeContent(uv + vec2(gOffset, 0.0), depth, t).g;
    col.b = planeContent(uv + vec2(bOffset, 0.0), depth, t).b;
    
    return col;
}

// Blur approximation (very cheap)
vec3 cheapBlur(vec2 uv, float radius) {
    if (radius < 0.5) return chromaticSample(uv, 0.5);
    
    vec3 sum = vec3(0.0);
    float samples = 4.0;
    for (float i = 0.0; i < samples; i++) {
        float angle = (i / samples) * 6.28318;
        vec2 offset = vec2(cos(angle), sin(angle)) * radius * 0.01;
        sum += chromaticSample(uv + offset, 0.5);
    }
    return sum / samples;
}

// Depth blur based on distance from focal plane
float depthBlur(float depth) {
    float dist = abs(depth - FOCAL_DEPTH);
    return dist * dist * MAX_BLUR; // Quadratic falloff
}

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution.xy;
    vec2 centered = uv - 0.5;
    centered.x *= u_resolution.x / u_resolution.y;
    
    // Mouse interaction — mouse Y controls focal depth
    float mouseDepth = u_mouse.y / u_resolution.y;
    float focal = mix(FOCAL_DEPTH, mouseDepth, 0.5);
    
    // Accumulate depth planes
    vec3 finalColor = vec3(0.0);
    float totalWeight = 0.0;
    
    for (int i = 0; i < NUM_PLANES; i++) {
        float fi = float(i);
        float depth = fi / float(NUM_PLANES - 1);
        
        // Weight by how close to focal plane
        float weight = 1.0 - smoothstep(0.0, 0.3, abs(depth - focal));
        weight = pow(weight, 2.0) + 0.1; // Ensure no plane is completely invisible
        
        // Get color with chromatic displacement
        vec3 col = chromaticSample(uv, depth);
        
        // Apply depth-of-field blur
        float blur = depthBlur(depth);
        if (blur > 0.5) {
            col = mix(col, cheapBlur(uv, blur), clamp(blur / MAX_BLUR, 0.0, 1.0));
        }
        
        finalColor += col * weight;
        totalWeight += weight;
    }
    
    finalColor /= totalWeight;
    
    // Vignette
    float vig = 1.0 - dot(centered, centered) * 0.8;
    finalColor *= clamp(vig, 0.3, 1.0);
    
    // CRT scanline effect (subtle)
    float scanline = sin(uv.y * u_resolution.y * 0.7) * 0.04 + 0.96;
    finalColor *= scanline;
    
    // Output
    gl_FragColor = vec4(finalColor, 1.0);
}
