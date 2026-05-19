# DEPTH MAP CREATION
## How to Make, Bake, and Integrate Depth Maps

> *"The depth map is the score. The shader is the orchestra. The image is just what happens when they play together."*

---

## WHAT IS A DEPTH MAP?

A depth map is a grayscale image where each pixel's brightness encodes the distance from the camera to the corresponding scene point.

**Convention used in this repo** (matching OpenGL / most photo tools):
```
White (1.0) = near the camera (small z value)
Black (0.0) = far from the camera (large z value)
```

*Direct3D / Unity reverse this: black = near, white = far.*  
*To convert: `depth = 1.0 - rawDepth`*

---

## METHOD 1: BLENDER (3D Scene Bake)

The most powerful method. Use for any 3D scene — architectural, character, abstract.

### Setup

1. **Create your scene** with proper camera positioning
2. **Enable compositor nodes:** Properties → Render → Enable "Compositing"
3. **Open Compositor** (Node Editor → Compositor)

### Node setup

```
Render Layers → Z (depth output)
                ↓
            Normalize Node   ← converts raw Z (world units) to [0,1]
                ↓
            Invert Node      ← white=near, black=far (our convention)
                ↓
            Composite (or File Output)
```

**Normalize:** in the Add menu → Vector → Normalize
**Invert:** Add → Color → Invert. Set mode to "Value" only.

### GLSL conversion for Blender's Z output

Blender's raw Z is in world-space meters. The normalize node maps it to [0,1] over the visible depth range. After normalization:
```
normalized = (Z - Z_min) / (Z_max - Z_min)
```

This maps near=1 (white), far=0 (black) — matching our shader convention already.

### Render settings for clean depth maps
- **Anti-aliasing:** OFF for depth maps (smoothed depth edges create incorrect intermediate values)
- **Render passes:** Enable "Z" under View Layer → Passes → Data
- **Format:** 16-bit or 32-bit EXR for maximum precision (don't use JPEG — it destroys depth gradients)

---

## METHOD 2: STABLE DIFFUSION (AI-Generated Depth)

For photographic or painterly images, you can extract a depth map using ML models.

### Using MiDaS (Most Accurate)

```bash
# Install
pip install transformers timm

python3 << 'EOF'
from transformers import DPTImageProcessor, DPTForDepthEstimation
import torch
from PIL import Image
import numpy as np

processor = DPTImageProcessor.from_pretrained("Intel/dpt-large")
model     = DPTForDepthEstimation.from_pretrained("Intel/dpt-large")

img    = Image.open("your_image.jpg")
inputs = processor(images=img, return_tensors="pt")

with torch.no_grad():
    outputs = model(**inputs)
    depth   = outputs.predicted_depth

# Resize to original image size and normalize
depth_resized = torch.nn.functional.interpolate(
    depth.unsqueeze(1),
    size=img.size[::-1],
    mode="bicubic",
    align_corners=False,
).squeeze()

# Normalize to [0,1]
d = depth_resized.numpy()
d = (d - d.min()) / (d.max() - d.min())

# MiDaS is inverse depth (bright = near) — already matches our convention
depth_img = Image.fromarray((d * 65535).astype(np.uint16), mode='I;16')
depth_img.save("depth_map.png")
EOF
```

**Note:** MiDaS outputs inverse depth (disparity) — larger values mean closer objects — which already matches our convention (white=near). No inversion is needed.

### Using SD ControlNet (for artistic/painted images)

If you're using Stable Diffusion, the ControlNet preprocessors can estimate depth:
```
SD WebUI → ControlNet → Preprocessor: depth_midas or depth_zoe
Set to "Preprocess Only" → generates depth map as side output
```

---

## METHOD 3: HAND-PAINTED DEPTH MAPS

The most creative method. Paint directly in Photoshop, Krita, or GIMP.

### Workflow

1. **Start with your scene image**
2. **Create a new grayscale layer** (Mode → Grayscale, or just desaturate)
3. **Rough pass:** use large, soft brushes
   - White for foreground elements
   - 50% grey for midground
   - Black for background sky
4. **Refine edges:** use the pen tool / selection tools to paint clean transitions
5. **Add gradients:** for objects with depth variation (floors, walls receding)
6. **Soften with Gaussian blur:** 2-4px softening gives natural depth transitions
7. **Export as 16-bit PNG** (File → Export → PNG, 16-bit)

### Brush technique for organic depth

- For foliage or organic shapes: use the original photo as a mask, fill with gradient
- For architecture: use linear gradients at vanishing point
- For people: hand > wrist > forearm > shoulder > body (white to grey)

### Photoshop automation

```
Image → Adjustments → Gradient Map
  Map: black to white over distance gradient
  Then paint corrections on top
```

---

## METHOD 4: REAL DEPTH SENSORS

If you have access to depth cameras (RealSense, Azure Kinect, iPhone LiDAR):

### iPhone LiDAR (iOS 15+)

```swift
// ARKit depth capture
import ARKit
let config = ARWorldTrackingConfiguration()
config.frameSemantics = .sceneDepth
session.run(config)

// In ARSessionDelegate:
func session(_ session: ARSession, didUpdate frame: ARFrame) {
    guard let depth = frame.sceneDepth else { return }
    let depthMap = depth.depthMap  // CVPixelBuffer — 32-bit float, meters
    // Convert to PNG: normalize from 0...max_range to 0...1
}
```

### RealSense (Python)

```python
import pyrealsense2 as rs
import numpy as np
from PIL import Image

pipe    = rs.pipeline()
config  = rs.config()
config.enable_stream(rs.stream.depth, 640, 480, rs.format.z16, 30)
pipe.start(config)

try:
    frames    = pipe.wait_for_frames()
    depth_frame = frames.get_depth_frame()
    depth_image = np.asanyarray(depth_frame.get_data())

    # Normalize: max range ~10 meters, near=bright
    d = depth_image.astype(float)
    d = (d.max() - d) / d.max()   # Invert: near = high value
    d = (d * 65535).astype(np.uint16)
    Image.fromarray(d, mode='I;16').save('realtime_depth.png')
finally:
    pipe.stop()
```

---

## METHOD 5: PHOTOGRAMMETRY PIPELINE

For real-world scenes captured with a regular camera:

1. **Capture 30–100 overlapping photos** of the scene (same lighting)
2. **Run COLMAP** (free) or Meshroom to generate point cloud + depth maps
3. Export depth maps from COLMAP:
   ```bash
   colmap dense_stereo \
     --workspace_path /path/to/project \
     --DenseStereo.geom_consistency 1
   # Depth maps are in /project/stereo/depth_maps/
   ```
4. **Convert .bin depth maps to PNG:**
   ```python
   import numpy as np
   from PIL import Image

   def read_colmap_depth(path):
       with open(path, 'rb') as f:
           width, height, channels = np.frombuffer(f.read(12), dtype=np.int32)
           data = np.frombuffer(f.read(), dtype=np.float32)
           return data.reshape((height, width, channels))[:,:,0]

   d = read_colmap_depth('image.jpg.geometric.bin')
   d = np.nan_to_num(d, nan=d[~np.isnan(d)].max())  # Fill sky gaps
   d = (d.max() - d) / d.max()  # Invert: near=bright
   d = (d * 65535).astype(np.uint16)
   Image.fromarray(d, 'I;16').save('depth.png')
   ```

---

## QUALITY CHECKLIST

Before using a depth map with `depth_map_parallax.glsl`:

- [ ] **Range:** does it use the full 0–1 range? (check histogram — avoid washed-out or very dark maps)
- [ ] **Convention:** white = near, black = far? (flip if needed)
- [ ] **Edge sharpness:** are object edges clean or mushy? (mushy edges create chromatic blur at wrong places)
- [ ] **Resolution:** at least as large as your canvas? (bilinear filtering saves you if slightly smaller)
- [ ] **Format:** PNG or EXR, NOT JPEG (JPEG quantization destroys subtle depth gradients)
- [ ] **Sky/holes:** background infinity should be black (0.0), not grey or white

### Quick Photoshop quality check

1. Open depth map in Photoshop
2. Image → Adjustments → Levels → look at histogram
3. Should be spread across the full 0–255 range
4. Apply a gradient map (black to rainbow) to visually verify depth ordering

---

## DEPTH MAP FORMATS AND PRECISION

| Format | Precision | Notes |
|--------|-----------|-------|
| 8-bit PNG (grayscale) | 256 steps | Fine for artistic use |
| 16-bit PNG | 65536 steps | Better for subtle gradients |
| 32-bit EXR (float) | ~16M steps | Best for technical accuracy |
| JPEG | ~200 effective steps | **Avoid** — compression artifacts corrupt depth |
| WebP | ~256 steps | Acceptable but less universal |

**In WebGL:** load 16-bit PNGs as `gl.LUMINANCE` or `gl.RED` textures. For EXR, you need the `OES_texture_float` extension:
```javascript
gl.getExtension('OES_texture_float');
gl.getExtension('OES_texture_float_linear');
// Then bind as gl.FLOAT texture
```

---

## ARTISTICALLY DESIGNING DEPTH MAPS

Don't think of depth maps as technical measurements. Think of them as **compositions**.

### "What do you want to be sharp?"

The focal plane is where the viewer's eye rests. Design depth around your visual hierarchy:
- Hero element → mid-grey (0.45–0.55) so it sits at the natural focal depth
- Background → dark (0.0–0.3)
- Foreground overlay → bright (0.7–1.0)

### The three-zone rule (reprise)

```
NEAR (0.7–1.0):  Props, hands, reticles — the present, the tangible
MID  (0.4–0.6):  Characters, focal objects — the subject of attention  
FAR  (0.0–0.3):  Background, atmosphere — history, context, scale
```

### Gradient vs. binary depth maps

**Gradient:** natural, photographic. Soft focus transitions. Best for realistic imagery.

**Binary / sharp-edged:** cut-paper aesthetic. Objects pop without intermediate blur.  
Also: better HUD aesthetics — the machine sees crisp boundaries, not gradients.

To create binary depth maps: use selection tools and fill with flat values. Soften edges by 1–2px only.

### Emotional depth maps

For use with `emotional_depth.glsl`, the depth map IS an emotion map. Design it based on feeling:
- What is the most painful thing in the frame? → Brightest (near, sharp, immediate)
- What is oldest? → Darkest (far, soft, faded)
- Use organic shapes, not architectural outlines

---

## EXAMPLE PIPELINE: PHOTO TO SHADER

Given: a photograph you want to apply the parallax effect to.

1. **Run MiDaS on the photo** → `depth_map.png`
2. **Check conventions:** MiDaS outputs inverse disparity (bright=near) ✓
3. **Refine in Photoshop:** paint corrections, adjust levels
4. **Load into WebGL:**
   ```javascript
   uniforms.u_depthMap = await loadTexture(gl, 'depth_map.png');
   uniforms.u_colorTex = await loadTexture(gl, 'photo.jpg');
   ```
5. **Run `depth_map_parallax.glsl`**
6. **Tune:**
   - `CHROMATIC_INTENSITY`: 0.4 for subtle, 1.2 for dramatic
   - `FOCAL_DEPTH`: 0.5 to focus mid-scene, or match whatever's important
   - Move mouse to shift focus

Total pipeline time: ~10 minutes for a single photograph.

---

*See also: `implementation_guide.md` for WebGL texture binding syntax.*
*See also: `shader_reference.md` for depth map shader parameters.*
