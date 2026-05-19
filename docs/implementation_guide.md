# IMPLEMENTATION GUIDE
## Wiring Parallax Depth Field Shaders into Real Projects

> *"A shader without a canvas is a score without an orchestra. Beautiful on paper. Inaudible."*

---

## OPTION A: SHADERTOY (Fastest Prototype)

ShaderToy maps its uniforms differently. Here's the translation layer:

```glsl
// At the TOP of any shader from this repo, add:
#define u_resolution  iResolution.xy
#define u_time        iTime
#define u_mouse       iMouse.xy

// ShaderToy entry point:
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Replace gl_FragCoord.xy with fragCoord
    // Replace gl_FragColor with fragColor
    // ... paste shader body here ...
}
```

**Important ShaderToy notes:**
- Remove `precision highp float;` — ShaderToy sets this automatically
- Replace `gl_FragColor = ...` with `fragColor = ...`
- Replace `gl_FragCoord` with `fragCoord`
- Texture uniforms: `u_depthMap` → `iChannel0`, `u_colorTex` → `iChannel1`

---

## OPTION B: VANILLA WEBGL

### Minimal WebGL boilerplate

```javascript
// Setup
const canvas = document.createElement('canvas');
document.body.appendChild(canvas);
const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');

// Vertex shader: fullscreen quad
const vertSource = `
  attribute vec2 a_position;
  void main() { gl_Position = vec4(a_position, 0.0, 1.0); }
`;

// Load your fragment shader source
async function loadShader(url) {
  const resp = await fetch(url);
  return resp.text();
}

// Compile program
function makeProgram(gl, vertSrc, fragSrc) {
  const vert = gl.createShader(gl.VERTEX_SHADER);
  gl.shaderSource(vert, vertSrc);
  gl.compileShader(vert);
  if (!gl.getShaderParameter(vert, gl.COMPILE_STATUS))
    throw new Error('Vert: ' + gl.getShaderInfoLog(vert));

  const frag = gl.createShader(gl.FRAGMENT_SHADER);
  gl.shaderSource(frag, fragSrc);
  gl.compileShader(frag);
  if (!gl.getShaderParameter(frag, gl.COMPILE_STATUS))
    throw new Error('Frag: ' + gl.getShaderInfoLog(frag));

  const prog = gl.createProgram();
  gl.attachShader(prog, vert);
  gl.attachShader(prog, frag);
  gl.linkProgram(prog);
  return prog;
}

// Fullscreen triangle (covers NDC with one triangle)
function makeFullscreenTriangle(gl) {
  const buf = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, buf);
  gl.bufferData(gl.ARRAY_BUFFER,
    new Float32Array([-1,-1,  3,-1,  -1,3]),
    gl.STATIC_DRAW);
  return buf;
}

// Main render loop
async function main() {
  const fragSource = await loadShader('code/basic_parallax.glsl');
  const program    = makeProgram(gl, vertSource, fragSource);
  const triBuffer  = makeFullscreenTriangle(gl);

  const posLoc      = gl.getAttribLocation(program, 'a_position');
  const resLoc      = gl.getUniformLocation(program, 'u_resolution');
  const timeLoc     = gl.getUniformLocation(program, 'u_time');
  const mouseLoc    = gl.getUniformLocation(program, 'u_mouse');

  let mouseX = 0, mouseY = 0;
  canvas.addEventListener('mousemove', e => {
    const r = canvas.getBoundingClientRect();
    mouseX = e.clientX - r.left;
    // Flip Y: WebGL origin is bottom-left
    mouseY = canvas.height - (e.clientY - r.top);
  });

  function resize() {
    canvas.width  = window.innerWidth;
    canvas.height = window.innerHeight;
    gl.viewport(0, 0, canvas.width, canvas.height);
  }
  window.addEventListener('resize', resize);
  resize();

  let startTime = performance.now();
  function render() {
    const t = (performance.now() - startTime) / 1000;

    gl.useProgram(program);

    // Bind fullscreen triangle
    gl.bindBuffer(gl.ARRAY_BUFFER, triBuffer);
    gl.enableVertexAttribArray(posLoc);
    gl.vertexAttribPointer(posLoc, 2, gl.FLOAT, false, 0, 0);

    // Set uniforms
    gl.uniform2f(resLoc,   canvas.width, canvas.height);
    gl.uniform1f(timeLoc,  t);
    gl.uniform2f(mouseLoc, mouseX, mouseY);

    gl.drawArrays(gl.TRIANGLES, 0, 3);
    requestAnimationFrame(render);
  }
  render();
}

main();
```

### Binding texture uniforms (for `depth_map_parallax.glsl`)

```javascript
function loadTexture(gl, url) {
  return new Promise(resolve => {
    const tex = gl.createTexture();
    const img = new Image();
    img.onload = () => {
      gl.bindTexture(gl.TEXTURE_2D, tex);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, img);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
      gl.generateMipmap(gl.TEXTURE_2D);   // Required for LINEAR_MIPMAP_LINEAR
      resolve(tex);
    };
    img.src = url;
  });
}

// In your setup code:
const depthMapTex = await loadTexture(gl, 'images/my_depth_map.png');
const colorTex    = await loadTexture(gl, 'images/my_scene.png');

const depthMapLoc = gl.getUniformLocation(program, 'u_depthMap');
const colorTexLoc = gl.getUniformLocation(program, 'u_colorTex');

// In render loop:
gl.activeTexture(gl.TEXTURE0);
gl.bindTexture(gl.TEXTURE_2D, depthMapTex);
gl.uniform1i(depthMapLoc, 0);

gl.activeTexture(gl.TEXTURE1);
gl.bindTexture(gl.TEXTURE_2D, colorTex);
gl.uniform1i(colorTexLoc, 1);
```

---

## OPTION C: THREE.JS

Three.js makes texture binding and screen-space effects straightforward.

### Basic setup with `ShaderMaterial`

```javascript
import * as THREE from 'three';

// Load shader source
const fragSource = await fetch('code/basic_parallax.glsl').then(r => r.text());

const uniforms = {
  u_resolution: { value: new THREE.Vector2(window.innerWidth, window.innerHeight) },
  u_time:       { value: 0.0 },
  u_mouse:      { value: new THREE.Vector2(0, 0) },
};

const material = new THREE.ShaderMaterial({
  vertexShader: `
    varying vec2 vUv;
    void main() { vUv = uv; gl_Position = vec4(position, 1.0); }
  `,
  fragmentShader: fragSource,
  uniforms,
});

// Fullscreen quad
const geometry = new THREE.PlaneGeometry(2, 2);
const mesh     = new THREE.Mesh(geometry, material);

const scene    = new THREE.Scene();
scene.add(mesh);

const camera   = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 10);
camera.position.z = 1;

const renderer = new THREE.WebGLRenderer();
renderer.setSize(window.innerWidth, window.innerHeight);
document.body.appendChild(renderer.domElement);

// Mouse tracking
window.addEventListener('mousemove', e => {
  uniforms.u_mouse.value.set(
    e.clientX,
    window.innerHeight - e.clientY   // flip Y
  );
});

window.addEventListener('resize', () => {
  renderer.setSize(window.innerWidth, window.innerHeight);
  uniforms.u_resolution.value.set(window.innerWidth, window.innerHeight);
});

// Render loop
const clock = new THREE.Clock();
function animate() {
  uniforms.u_time.value = clock.getElapsedTime();
  renderer.render(scene, camera);
  requestAnimationFrame(animate);
}
animate();
```

### Using depth map textures in Three.js

```javascript
const textureLoader = new THREE.TextureLoader();

const depthMap = textureLoader.load('images/depth_map.png');
depthMap.wrapS = depthMap.wrapT = THREE.ClampToEdgeWrapping;
depthMap.minFilter = THREE.LinearFilter;

const colorTex = textureLoader.load('images/scene.png');

// Add to uniforms object:
uniforms.u_depthMap = { value: depthMap };
uniforms.u_colorTex = { value: colorTex };
```

### Post-processing with `EffectComposer`

For integrating parallax depth as a post-processing pass over a rendered Three.js scene:

```javascript
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass }     from 'three/examples/jsm/postprocessing/RenderPass.js';
import { ShaderPass }     from 'three/examples/jsm/postprocessing/ShaderPass.js';

const composer = new EffectComposer(renderer);
composer.addPass(new RenderPass(scene, camera));

// Grab the depth render target from Three.js
renderer.shadowMap.enabled = true;
const depthTarget = new THREE.WebGLRenderTarget(
  window.innerWidth, window.innerHeight,
  { depthBuffer: true, depthTexture: new THREE.DepthTexture() }
);

const parallaxPass = new ShaderPass({
  uniforms: {
    tDiffuse:     { value: null },         // Set by ShaderPass automatically
    u_depthMap:   { value: depthTarget.depthTexture },
    u_resolution: { value: new THREE.Vector2(window.innerWidth, window.innerHeight) },
    u_time:       { value: 0.0 },
    u_mouse:      { value: new THREE.Vector2(0, 0) },
  },
  vertexShader: `
    varying vec2 vUv;
    void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }
  `,
  fragmentShader: fragSource.replace('u_colorTex', 'tDiffuse'),
});

composer.addPass(parallaxPass);

// In animate():
renderer.render(scene, camera, depthTarget);
parallaxPass.uniforms.u_time.value = clock.getElapsedTime();
composer.render();
```

---

## OPTION D: p5.js (GLSL Shaders)

p5.js supports GLSL fragment shaders via `createShader()`.

```javascript
let parallaxShader;
let fragSrc;

async function preload() {
  fragSrc = await loadStrings('code/basic_parallax.glsl').then(lines => lines.join('\n'));
}

function setup() {
  createCanvas(windowWidth, windowHeight, WEBGL);
  // p5 WEBGL doesn't support loading from string directly, use a .frag file:
  parallaxShader = loadShader('passthrough.vert', 'code/basic_parallax.glsl');
  noStroke();
}

function draw() {
  shader(parallaxShader);
  parallaxShader.setUniform('u_resolution', [width, height]);
  parallaxShader.setUniform('u_time', millis() / 1000.0);
  // p5 mouse: flip Y
  parallaxShader.setUniform('u_mouse', [mouseX, height - mouseY]);
  rect(-width/2, -height/2, width, height);
}
```

**Vertex shader (`passthrough.vert`):**
```glsl
attribute vec3 aPosition;
void main() {
  gl_Position = vec4(aPosition * 2.0 - 1.0, 1.0);
}
```

---

## OPTION E: GLSL VIEWER (CLI)

For local development, `glslViewer` (https://github.com/patriciogonzalezvivo/glslViewer) runs any shader from the command line:

```bash
glslViewer code/basic_parallax.glsl --headless false
```

It automatically binds `u_resolution`, `u_time`, `u_mouse`, and handles mouse events. Pass textures as CLI arguments:

```bash
glslViewer code/depth_map_parallax.glsl images/depth.png images/scene.png
```

The textures are auto-bound as `u_tex0`, `u_tex1`. Rename inside the shader or use `--define`:
```bash
glslViewer code/depth_map_parallax.glsl images/depth.png images/scene.png \
  --define "u_depthMap=u_tex0" --define "u_colorTex=u_tex1"
```

---

## COMMON ISSUES AND FIXES

### "Shader compiles but is black"
1. Check `u_resolution` — if it's `vec2(0,0)`, all `uv` calculations divide by zero
2. Check time — if `u_time` never increments, animated shaders may start at a dark keyframe
3. In WebGL: verify the uniform location with `console.log(gl.getUniformLocation(prog, 'u_resolution'))`

### "Shader gives compile error about arrays"
GLSL ES 1.0 (WebGL 1) doesn't support:
- `float arr[n] = float[n](...)` syntax → use `float arr[n]; arr[0] = ...; arr[1] = ...;`
- Variable array indexing with a non-constant index → use `if (i == 0)` chains or `for` loops

GLSL ES 3.0 (WebGL 2, `#version 300 es`) lifts many of these restrictions.

### "Works on desktop, breaks on mobile"
Mobile GPUs often:
- Limit loop iterations to compile-time constants — ensure all loop bounds are `const`
- Have stricter mediump precision — add `precision highp float;` at the top
- Don't support `gl.FLOAT` texture filtering without extension — use `gl.UNSIGNED_BYTE` depth maps

### "Performance drops with NUM_PLANES > 6"
Each depth plane multiplies the texture samples. Options:
- Reduce `BLUR_SAMPLES` first — blur is the most expensive operation
- Use a lower resolution depth map (256×256 is often enough)
- Consider temporal reprojection: render every other plane on alternate frames

### "Mouse Y is inverted"
WebGL's Y axis is bottom-up; browser mouse events are top-down. Always flip:
```javascript
mouseY = canvas.height - event.clientY;
```
The shaders assume Y=0 is at the bottom.

---

## PERFORMANCE BENCHMARKS (approximate)

Tested on a 1920×1080 canvas, mid-range GPU (RTX 3060):

| Shader | FPS | Notes |
|--------|-----|-------|
| `basic_parallax` | 120+ | 5 planes, 4 blur samples |
| `depth_map_parallax` | 90–120 | 8 blur samples |
| `hud_reticle` | 120+ | SDF-based, very fast |
| `paradoxical_depth` | 60–90 | Recursion depth 3 |
| `emotional_depth` | 120+ | No heavy loops |
| `quantum_depth` | 80–100 | 4 objects × 4 states |
| `synesthetic_depth` | 60–80 | 7 planes × blur |
| `thermal_depth` | 90–110 | Heat shimmer distortion |
| `anamorphic_depth` | 70–90 | 6 planes + bokeh |
| `biological_parallax` | 80–100 | Two full modes |
| `ufo_temporal` | 50–70 | 6 epochs × blur |
| `apocalyptic_hud` | 80–100 | Many glitch layers |

Reduce `BLUR_SAMPLES` or `NUM_PLANES` by half to roughly double performance.

---

*See also: `shader_reference.md` for complete parameter documentation.*
*See also: `depth_map_creation.md` for generating depth maps to use with `depth_map_parallax.glsl`.*
