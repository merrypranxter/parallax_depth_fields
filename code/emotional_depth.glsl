// EMOTIONAL DEPTH
// Depth isn't spatial — it's emotional.
// Recent memories = close, sharp, painful.
// Old memories = far, blurred, rose-tinted.
// Time = depth. Grief = chromatic aberration.

precision highp float;

uniform vec2 u_resolution;
uniform float u_time;
uniform vec2 u_mouse;

// EMOTION PARAMETERS (these are the "emotion map")
const float EMOTION_INTENSITY = 1.0;     // How strongly emotions affect the visual
const float CHROMATIC_GRIEF = 1.2;       // Grief = chromatic separation
const float BLUR_NOSTALGIA = 8.0;        // Nostalgia = soft focus
const float SHARP_ANGER = 0.0;           // Anger = razor sharp (no blur)
const float TREMBLE_ANXIETY = 2.0;       // Anxiety = temporal tremble

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

// Generate an "emotion" value for a spatial position
// This is the "emotion map" — could be fed from external data
float emotionAt(vec2 uv, float time) {
    // Simulated emotion field:
    // 0.0 = calm/peace (old, far)
    // 0.5 = neutral
    // 1.0 = intense emotion (recent, close)
    
    float n1 = noise(uv * 2.0 + time * 0.1);
    float n2 = noise(uv * 5.0 - time * 0.15);
    float n3 = noise(uv * 10.0 + vec2(time * 0.2, -time * 0.1));
    
    // Mouse position = "current emotional focus"
    vec2 mouseUV = u_mouse / u_resolution;
    float mouseDist = length(uv - mouseUV);
    float mouseInfluence = smoothstep(0.5, 0.0, mouseDist);
    
    float emotion = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;
    emotion = emotion * 0.7 + mouseInfluence * 0.3;
    
    // Pulsing — emotions breathe
    emotion += sin(time * 0.5) * 0.1;
    
    return clamp(emotion, 0.0, 1.0);
}

// Memory content at a position and emotional depth
vec3 memoryContent(vec2 uv, float emotion, float time) {
    // Memories look different based on emotion
    float sharpness = mix(BLUR_NOSTALGIA, SHARP_ANGER, emotion);
    
    // Spatial frequency = how "detailed" the memory is
    float freq = mix(3.0, 12.0, emotion);
    
    float n = noise(uv * freq + time * 0.05);
    float n2 = noise(uv * freq * 2.0 - time * 0.03);
    
    // Colors shift with emotion
    // Peace: cool, muted, pastel
    // Anguish: hot, saturated, piercing
    vec3 peace = vec3(0.7, 0.8, 0.9);      // Soft blue-grey
    vec3 joy = vec3(1.0, 0.9, 0.4);        // Warm gold
    vec3 sorrow = vec3(0.6, 0.3, 0.7);    // Bruised purple
    vec3 anger = vec3(0.9, 0.1, 0.2);     // Blood red
    vec3 fear = vec3(0.2, 0.8, 0.6);      // Sickly teal
    
    vec3 col = mix(peace, joy, smoothstep(0.0, 0.3, emotion));
    col = mix(col, sorrow, smoothstep(0.3, 0.6, emotion));
    col = mix(col, anger, smoothstep(0.6, 0.8, emotion));
    col = mix(col, fear, smoothstep(0.8, 1.0, emotion));
    
    // Detail level
    float detail = n * 0.6 + n2 * 0.4;
    col *= 0.5 + 0.5 * detail;
    
    // Memory "fog" — the farther back, the more washed out
    float fog = 1.0 - emotion * 0.5;
    col = mix(vec3(0.1, 0.1, 0.15), col, fog);
    
    return col;
}

// Chromatic separation based on grief
vec3 griefChromatic(vec2 uv, float emotion, float time) {
    float grief = emotion * CHROMATIC_GRIEF;
    
    // Grief pulls colors apart
    float rOff = grief * 0.05 * (1.0 + sin(time * 3.0) * 0.5);
    float gOff = grief * 0.02;
    float bOff = -grief * 0.04;
    
    // Also vertical displacement for "tears"
    float tearDrop = sin(time * 5.0) * emotion * 0.02;
    
    vec3 col;
    col.r = memoryContent(uv + vec2(rOff, tearDrop), emotion, time).r;
    col.g = memoryContent(uv + vec2(gOff, tearDrop * 0.5), emotion, time).g;
    col.b = memoryContent(uv + vec2(bOff, -tearDrop * 0.3), emotion, time).b;
    
    return col;
}

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution.xy;
    vec2 centered = uv - 0.5;
    centered.x *= u_resolution.x / u_resolution.y;
    
    float time = u_time;
    
    // Sample the emotion at this position
    float emotion = emotionAt(uv, time);
    
    // The emotional depth field
    vec3 color = griefChromatic(uv, emotion, time);
    
    // Temporal tremble for anxiety
    float anxiety = emotion * TREMBLE_ANXIETY;
    float tremble = sin(time * 20.0) * anxiety * 0.01;
    color += griefChromatic(uv + vec2(tremble, tremble * 0.7), emotion, time) * 0.1;
    
    // "Heartbeat" when emotion is high
    float heartbeat = pow(sin(time * 4.0), 20.0) * emotion * 0.3;
    color += vec3(heartbeat * 0.5, heartbeat * 0.1, heartbeat * 0.2);
    
    // Vignette = "tunnel vision" under stress
    float vig = 1.0 - dot(centered, centered) * (0.5 + emotion * 0.5);
    color *= clamp(vig, 0.1, 1.0);
    
    // Grain = film memory texture
    float grain = hash(uv * 500.0 + fract(time) * 10.0) * 0.05;
    color += grain;
    
    // "Rose tint" for nostalgia (low emotion, warm)
    float nostalgia = (1.0 - emotion) * 0.3;
    color = mix(color, color * vec3(1.1, 0.9, 0.8), nostalgia);
    
    gl_FragColor = vec4(color, 1.0);
}
