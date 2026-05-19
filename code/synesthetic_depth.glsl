// SYNESTHETIC DEPTH — Depth as Visual Pitch
// Each depth plane vibrates at a different spatial frequency (visual "pitch").
// Close objects: high frequency, fast strobe — like high musical notes.
// Far objects: low frequency, slow breath — like bass notes.
// The entire scene is a visual chord. Move the mouse to bend the pitch.
//
// "The room is an organ. Each wall is a different octave.
//  The air between things resonates. You are moving through music."

precision highp float;

uniform vec2  u_resolution;
uniform float u_time;
uniform vec2  u_mouse;

// PARAMETERS
const int   NUM_PLANES     = 7;       // Depth planes = notes in the chord
const float CHROMATIC_INTENSITY = 1.0;
const float PARALLAX_STRENGTH   = 0.10;
const float TIME_SCALE          = 1.0;

// Pitch mapping: plane index → spatial frequency (cycles/frame)
// Matches a just-intonation C major chord: 1, 5/4, 3/2, 2, 5/2, 3, 4
const float PITCH_RATIOS[7] = float[7](1.0, 1.25, 1.5, 2.0, 2.5, 3.0, 4.0);

// Tempo: how fast each plane "breathes" (Hz equivalent)
const float BASE_TEMPO = 0.8;   // Slowest breath per second

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

// ---- Harmonic color mapping -------------------------------------------------
// Maps note index to a color — like a color organ (Scriabin / Rimington)
vec3 noteColor(int noteIdx) {
    // Based loosely on Scriabin's "color of sound" synesthesia table
    // C=red, D=yellow, E=pearlwhite, F=red-dark, G=orange, A=green, B=blue
    vec3 colors[7];
    colors[0] = vec3(0.90, 0.12, 0.10);   // C  — red
    colors[1] = vec3(0.95, 0.80, 0.15);   // D  — yellow
    colors[2] = vec3(0.85, 0.90, 0.95);   // E  — pearl-white
    colors[3] = vec3(0.60, 0.05, 0.20);   // F  — dark red-violet
    colors[4] = vec3(0.95, 0.55, 0.10);   // G  — orange
    colors[5] = vec3(0.15, 0.75, 0.35);   // A  — green
    colors[6] = vec3(0.10, 0.30, 0.90);   // B  — blue
    return colors[clamp(noteIdx, 0, 6)];
}

// ---- Plane content ----------------------------------------------------------
// Each plane vibrates at its pitch frequency — spatial Moiré and temporal pulsing

vec3 planeContent(vec2 uv, int planeIdx, float depth, float time) {
    float pitch   = PITCH_RATIOS[clamp(planeIdx, 0, 6)];
    float tempo   = BASE_TEMPO * pitch;   // Higher note = faster beat

    // Spatial frequency: higher pitch = finer pattern
    float spatFreq = 8.0 * pitch;

    // Temporal oscillation — the "note playing"
    float beat = sin(time * tempo * 6.28318) * 0.5 + 0.5;  // [0,1] pulsing

    // Moiré / standing wave pattern
    float wave1 = sin(uv.x * spatFreq + time * tempo * 3.0) * 0.5 + 0.5;
    float wave2 = sin(uv.y * spatFreq * 0.866 - time * tempo * 2.0) * 0.5 + 0.5;
    float moire = wave1 * wave2;

    // Harmonic overtone (2nd harmonic creates richer texture)
    float overtone = sin(uv.x * spatFreq * 2.0 + uv.y * spatFreq * 1.414 + time * tempo * 5.0)
                     * 0.3 + 0.7;

    // Background noise at the plane's spatial scale
    float bg = noise(uv * pitch * 3.0 + time * 0.1 * pitch);

    // Combine: standing wave modulated by beat, with noise substrate
    float intensity = moire * beat * 0.7 + overtone * 0.2 + bg * 0.1;

    vec3 noteCol = noteColor(planeIdx);
    return noteCol * intensity;
}

// Chromatic parallax sampling for a plane
vec3 planeChromatic(vec2 uv, int planeIdx, float depth, float time) {
    float disp = (depth - 0.5) * PARALLAX_STRENGTH * CHROMATIC_INTENSITY;

    vec3 col;
    col.r = planeContent(uv + vec2(disp * 1.2,  0.0 ),        planeIdx, depth, time);
    col.g = planeContent(uv + vec2(disp * 0.4,  0.0 ),        planeIdx, depth, time);
    col.b = planeContent(uv + vec2(disp * -0.9, disp * 0.1),  planeIdx, depth, time);

    return col;
}

// ---- Resonance envelope -----------------------------------------------------
// Planes closer to the "focal note" (mouse-controlled) sound louder

float resonanceWeight(int planeIdx, float focalNote, float time) {
    float note = float(planeIdx) / float(NUM_PLANES - 1);
    float dist = abs(note - focalNote);

    // Sharp resonance peak — like a filter Q
    float q = 2.5;
    float weight = exp(-dist * dist * q * q * 4.0);

    // Beating: when two notes are close, they interfere and create amplitude modulation
    float beatFreq = abs(PITCH_RATIOS[planeIdx] - PITCH_RATIOS[int(clamp(focalNote * float(NUM_PLANES - 1), 0.0, float(NUM_PLANES - 1)))]);
    float beating  = cos(time * beatFreq * BASE_TEMPO * 3.14159) * 0.15 + 0.85;

    return weight * beating;
}

// ---- Chord background -------------------------------------------------------
// The "silence" between notes — a deep resonance chamber texture
vec3 resonanceChamber(vec2 uv, float time, float focalNote) {
    // Standing waves in a rectangular room (simplification)
    // Room modes at harmonic frequencies
    float mode1 = sin(uv.x * 6.28318 * 2.0 + time * 0.5) * sin(uv.y * 6.28318 * 1.5 + time * 0.4);
    float mode2 = sin(uv.x * 6.28318 * 3.0 - time * 0.7) * sin(uv.y * 6.28318 * 2.0 - time * 0.5);
    float mode3 = sin(uv.x * 6.28318 * 5.0 + time * 0.9) * sin(uv.y * 6.28318 * 3.5 + time * 0.6);

    float pressure = (mode1 * 0.5 + mode2 * 0.3 + mode3 * 0.2) * 0.5 + 0.5;

    // Color the pressure field: compression (high pressure) = warm, rarefaction = cool
    vec3 warm = vec3(0.08, 0.04, 0.12);  // Deep violet-black
    vec3 cool = vec3(0.02, 0.06, 0.10);  // Dark navy
    return mix(cool, warm, pressure) + pressure * 0.03;
}

// ---- Main -------------------------------------------------------------------

void main() {
    vec2  uv      = gl_FragCoord.xy / u_resolution.xy;
    vec2  centered = uv - 0.5;
    centered.x   *= u_resolution.x / u_resolution.y;

    float time    = u_time * TIME_SCALE;
    vec2  mouseUV = u_mouse / u_resolution;

    // Mouse Y selects the "focal note" — which depth plane is loudest
    float focalNote = clamp(mouseUV.y, 0.0, 1.0);

    // Mouse X bends pitch (like a vinyl scratch or pitch wheel)
    float pitchBend = (mouseUV.x - 0.5) * 0.4;

    // ---- Resonance chamber background
    vec3 color = resonanceChamber(uv, time, focalNote);

    // ---- Composite depth planes (back to front)
    float totalWeight = 0.0;
    vec3  accumulated = vec3(0.0);

    for (int i = 0; i < NUM_PLANES; i++) {
        float depth = float(i) / float(NUM_PLANES - 1);

        // Pitch bend shifts the spatial frequency of all planes
        float bentDepth = depth + pitchBend * (depth - 0.5);
        bentDepth = clamp(bentDepth, 0.0, 1.0);

        vec3  planecol = planeChromatic(uv, i, bentDepth, time);

        // Resonance weighting — focal note plays loudest
        float w = resonanceWeight(i, focalNote, time);
        // All planes contribute at minimum level (no plane is silent)
        w = w * 0.8 + 0.1;

        // Depth-of-field: blur off-note planes (blending in accumulated for simplicity)
        float noteDist = abs(float(i) / float(NUM_PLANES - 1) - focalNote);
        float blur     = noteDist * noteDist * 0.4;

        // Simple blur: lerp toward average of nearby offsets
        vec3 blurred = planecol;
        if (blur > 0.05) {
            vec3 b = vec3(0.0);
            for (int k = 0; k < 4; k++) {
                float ang = float(k) * 1.5708 + time * 0.2;
                vec2 off  = vec2(cos(ang), sin(ang)) * blur * 0.02;
                b += planeChromatic(uv + off, i, bentDepth, time);
            }
            blurred = mix(planecol, b / 4.0, clamp(blur * 2.0, 0.0, 1.0));
        }

        accumulated += blurred * w;
        totalWeight += w;
    }

    accumulated /= totalWeight;
    color = mix(color, accumulated, 0.95);

    // ---- Synesthetic pulse overlay
    // When a strong beat fires across all notes simultaneously (musical "bar"):
    float barTime = mod(time * BASE_TEMPO, 4.0);
    float barFlash = exp(-barTime * 3.0) * 0.15 * (1.0 - focalNote);
    color += barFlash * noteColor(int(focalNote * float(NUM_PLANES - 1)));

    // ---- Vignette (deeper at high notes — tunnel-hearing effect)
    float vigStr = 0.5 + focalNote * 0.4;
    float vig = 1.0 - dot(centered, centered) * vigStr;
    color *= clamp(vig, 0.15, 1.0);

    // ---- Subtle scanline
    float scanline = sin(uv.y * u_resolution.y * 0.7) * 0.025 + 0.975;
    color *= scanline;

    gl_FragColor = vec4(color, 1.0);
}
