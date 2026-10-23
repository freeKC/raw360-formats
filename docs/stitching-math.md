# Stitching math: frames, lens models, blending

Dart: `viewToLens`, `lensPose`, `bodyFrame`, `downBodyFromAccelerometer`, `meiProject`, `equidistantProject`,
`kannalaBrandtProject`, `djiLensRotation`, `quaternionMatrix`, `blendWeight`, `FisheyePairSampler`, `GoProEacSampler`,
`stitchRawRgba` (lib/src/dual_fisheye_math.dart and lib/src/raw_sampler.dart).

The Dart code is a reference: `stitchRawRgba` stitches on the CPU, slowly, and a GPU shader can follow the same steps
for each output pixel. The tests draw synthetic lens pictures from a known pattern by inverse mapping, stitch them back
and compare with the pattern (test/raw_stitch_test.dart).

## Frames

- **View frame**: x right, y down, z forward. The centre column of an equirectangular picture looks along +z.
- **Output pixel** (i, j) of a W x H equirectangular picture: `lon = ((i+0.5)/W*2-1)*pi`, `lat = pi/2-(j+0.5)/H*pi`,
  direction `v = (cos lat sin lon, -sin lat, cos lat cos lon)`.
- **Pixels**: continuous coordinates from the top left corner, pixel (i, j) covers [i, i+1) x [j, j+1), its centre at
  (i+0.5, j+0.5). Bilinear sampling subtracts 0.5.
- **Lens frame**: x along the columns of the lens picture, y along its rows, z its optical axis. `d = viewToLens v`.
- **Insta360 body frame**: x right, y down, z along the axis of lens 0.
- **DJI world frame**: x forward along the front lens, y left, z up (docs/dji-osv.md).
- **GoPro camera frame**: x right, y up, z forward (docs/gopro-360.md).

## Insta360: lens pose and levelling

- Gravity: `downBodyFromAccelerometer` turns the mean accelerometer into the direction of gravity in the body frame
  (docs/insta360.md). Without IMU data the camera is taken as upright: gravity along body +x.
- `bodyFrame(down)`: the view is levelled by gravity and looks forward along the axis of lens 1 laid level, where
  Insta360 Studio opens a picture. Its columns are the right, down and forward axes of the view in the body frame:
  forward = normalize(axis of lens 1 minus its component along down), right = down cross forward.
- `lensPose(lens, i) = Rz(mirroredRoll(roll)) Rx(180° i) Rx(pitch) Ry(yaw)`, with
  `mirroredRoll(r) = 2 round(r/90) 90 minus r`: the strings give the roll mirrored about the nearest quarter turn, as
  GyroView measured against Insta360 Studio on the X3, X5 and X6; the seam of X3, X4 and X5 files agrees
  (docs/insta360.md).
- `viewToLens_i = lensPose(lens_i, i) bodyFrame(down)`.

DJI lenses carry their rotation whole (`DualFisheyeLens.viewToLens`, docs/dji-osv.md); GoPro tracks use
`goProViewToCamera` and the face table.

## Lens models

For a unit direction d in the lens frame, theta its angle off the optical axis:

| Model | Used by | Canvas pixel |
|---|---|---|
| Mei (unified camera model) | Insta360 V3 and V6 strings | `m = (dx, dy)/(dz+xi)`, `r2 = m.m`, `radial = 1+r2(k1+r2(k2+r2(k3+r2(k4+r2 k5))))`, then the tangential terms p1 and p2, then `(fx mx'+cx, fy my'+cy)` |
| Equidistant | Insta360 V1 strings | distance to the centre `radius theta/100°` |
| Kannala-Brandt | DJI Osmo 360 | `thetaD = theta(1+t2(k1+t2(k2+t2(k3+t2(k4+t2 k5)))))` with t2 = theta², then `(cx+fx thetaD ux, cy+fy thetaD uy)` |

A lens is read only below `maxTheta` off its axis (100° on Insta360 cameras, 94° on the Osmo 360) and only where the
pixel lands inside its own square of the canvas.

## Blending

Each lens weighs `1 minus smoothstep(blendStart, blendEnd, theta)`: 85° to 95° on Insta360 cameras, 87° to 93° on the
Osmo 360. The weights of a pixel are made to add up to 1. Where no lens has weight but one sees the direction, the lens
closer to its axis is taken alone. GoPro split faces blend their two halves linearly across the overlap.

## Where the lenses are

`FisheyePairSampler` reads each lens from a region of a texture:

- one side by side frame (Insta360 X3 and older): lens 0 in the left half, lens 1 in the right half of texture 0;
- two tracks or two files (Insta360 X4 and later, split pairs, DJI): lens i fills texture `textureOfLens[i]`. On the
  Insta360 X4 and X5, track 0 holds lens 1 (`insta360TrackOrder`).

The whole calibration square of a lens maps onto its whole region; samples are kept half a pixel inside the region so
that bilinear sampling never reads the other lens.

## Try it on a real file

```sh
# Frames of the two lenses of a two track file
ffmpeg -ss 5 -i CAM.OSV -map 0:v:0 -frames:v 1 lens0.png -map 0:v:1 -frames:v 1 lens1.png
```

Decode them to RGBA (with package:image, for example), build a sampler from the calibration the package reads
(`FisheyePairSampler(calibration, regions: FisheyePairSampler.wholeTextureRegions([0, 1]), textureSizes: ...)`) and
call `stitchRawRgba`. A 2048 x 1024 picture takes a few seconds on the CPU.

## References

- C. Mei and P. Rives, "Single View Point Omnidirectional Camera Calibration from Planar Grids", ICRA 2007.
- J. Kannala and S. S. Brandt, "A generic camera model and calibration method for conventional, wide-angle, and
  fish-eye lenses", IEEE TPAMI, 2006.
- GyroView (MIT): the Insta360 lens pose convention this package follows (see THIRD_PARTY_NOTICES.md).
  https://github.com/bubo-squared/GyroView
- OSVplat (MIT): the DJI lens pose. https://github.com/pgodlews/OSVplat
- max2-reframe-resolve (MIT): the GoPro EAC sampling. https://github.com/Sean-McConnachie/max2-reframe-resolve
- mpv360 (MIT): 360° projections as an mpv user shader, for stitched files. https://github.com/kasper93/mpv360
