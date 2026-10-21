# DJI Osmo 360 .osv

Dart: `readDjiOsvCalibration`, `parseDjiCamdRecords`, `nominalOsmo360`, `listTopLevelBoxes`, `djiLensRotation`
(lib/src/dji_osv.dart, lib/src/spherical_probe.dart and lib/src/dual_fisheye_math.dart).

## Structure

An `.osv` file is an MP4 followed by a top level box of type `camd`. On a real Osmo 360 file (firmware 10.00.05.06):

- top level boxes: `ftyp`, `free`, `free`, `mdat`, `moov` (130 KB), `camd` (714 KB);
- tracks: 1 and 2 `hvc1` 3840 x 3840 Main 10, handler `vide` "VideoHandler", one lens each; 3 `mp4a` "SoundHandler";
  4 and 5 `djmd`, handler `meta` "CAM meta"; 6 and 7 `dbgi` "CAM dbgi";
- video track 1 (stream 0) holds the rear lens, track 2 (stream 1) the front lens.

The `camd` box is itself a complete MP4 (`ftyp`, `free`, `mdat`, `moov`). Its `mdat` is a flat run of length delimited
protobuf fields: 1 a header, 2 a config, 3 a record per frame, then again a header and a config for the second djmd
track. The first header (166 bytes) and config (5,520 bytes) come first, so the first 256 KiB are enough.

## Header and config

Paths are protobuf field numbers from the start of the camd records.

| Path | Content |
|---|---|
| 1-1-1 | schema, "dvtm_oq101.proto" |
| 1-1-5 | serial number |
| 1-1-6 | firmware |
| 1-1-10 | model, "Osmo 360" |
| 2-6-n | calibration slot n (a DewarpParams message) |

Slots 1 and 2 are the lenses of video streams 0 (rear) and 1 (front); slots 3 to 10 are zero filled; 11 to 24 hold
other recording modes. The Avata 360 keeps its calibration in field 5 of the config instead of 6, according to
OSVplat, so the reader looks for the first two populated slots in field 6, then in any other field. A slot is taken
when its sub-fields 1 to 8 are floats and fx is positive.

DewarpParams sub-fields (names from telemetry-parser's `dvtm_library.proto`, as OSVplat quotes it):

| Sub-field | Meaning |
|---|---|
| 1, 2 | fx, fy (pixels) |
| 3, 4 | cx, cy (pixels, in the square of the lens) |
| 5 to 8 | k1 to k4 |
| 9 | xi, unused |
| 10, 11 | width and height of the lens square (3840) |
| 12, 13, 14 | yaw, pitch, roll (degrees) |
| 15 | k5 |
| 16 to 19 | k6 to k9 (zeros on the files seen) |
| 20 | tangential terms, packed floats (about one pixel at the rim, left out) |
| 21 | a packed quaternion, equal to 28 on the file seen |
| 24 | lens model, 8.0 on the file seen |
| 28 | cam_extri_q: a message of four floats w (1), x (2), y (3), z (4) |

## Lens model and pose

- Kannala-Brandt fisheye: with theta the angle off the optical axis in radians,
  `r = theta (1 + k1 theta^2 + k2 theta^4 + k3 theta^6 + k4 theta^8 + k5 theta^10)` and the pixel is
  `(cx + fx r ux, cy + fy r uy)`, u the unit direction of the ray in the image plane. A lens is read up to 94 degrees
  off axis; the two lenses blend between 87 and 93 degrees.
- The calibration's world frame has x forward (axis of the front lens), y left, z up. The view frame of this package
  (x right, y down, z forward) maps to it by `[[0, 0, 1], [-1, 0, 0], [0, -1, 0]]`.
- World to lens: rows x, y and the optical axis z of the lens, with az = yaw and el = 90-pitch:
  `z = (cos el cos az, cos el sin az, sin el)`, `x = normalize(sin az, -cos az, 0)`, `y = z cross x`, then x and y turned
  by the roll about z. This is OSVplat's `world_to_cam` without its final mirroring of x, which flips the picture in a
  right handed view frame.
- Lens 1 is placed relative to lens 0 by the two quaternions: `Q1 Q0^T M0`, where M0 is the pose of lens 0. On two units
  the quaternions agree with the yaw, pitch and roll reading within 0.3 to 1.5 degrees, and on the real file they give
  continuous seams where the yaw, pitch and roll of lens 1 do not.
- `nominalOsmo360` gives mean values of two units for a file without a readable camd box.

## What is known, and what is guessed

| Point | Status |
|---|---|
| camd box, header and config order, paths 1-1-x and 2-6-n | checked on one real file, and documented by OSVplat on another unit and firmware |
| Slots 1 and 2 are streams 0 and 1, rear and front | checked: stream 0 shows the rider, stream 1 the road ahead |
| k5 is sub-field 15 | checked twice: radii match OSVplat's bundle adjusted ones within 0.5 percent from 60 to 95 degrees |
| Quaternion order w, x, y, z, relative rotation Q1 Q0^T | checked on two units |
| No mirroring; no levelling needed for an upright camera | checked on one file, a camera mounted on a bike |
| Other recording modes (slots 11 to 24), Osmo 360 II, Avata 360 | not checked |
| Levelling from the IMU of the djmd records | not done |

## Inspect a file

```sh
# The top level boxes, camd last
python3 -c "
import struct,sys
f=open(sys.argv[1],'rb'); o=0
while True:
    f.seek(o); h=f.read(16)
    if len(h)<8: break
    s,t=struct.unpack('>I4s',h[:8])
    if s==1: s=struct.unpack('>Q',h[8:16])[0]
    print(o,t.decode('latin1'),s)
    if s==0: break
    o+=s
" CAM_20250101120000_0001_D.OSV

# The tracks, and one frame of each lens
ffprobe -v error -show_entries stream=index,codec_type,codec_name,width,height:stream_tags=handler_name -of compact CAM.OSV
ffmpeg -ss 5 -i CAM.OSV -map 0:v:0 -frames:v 1 rear.png -map 0:v:1 -frames:v 1 front.png

# What this package reads, the calibration of both lenses included
dart run example/inspect.dart CAM_20250101120000_0001_D.OSV
```

## References

- OSVplat (MIT), `docs/osmo360-telemetry.md`, `scripts/osv_meta.py`, `scripts/osmo_fisheye.py`: the camd records and the
  lens pose this package follows (see THIRD_PARTY_NOTICES.md). https://github.com/pgodlews/OSVplat
- telemetry-parser: the DJI protobuf schemas. https://github.com/AdrianEddy/telemetry-parser
- Kannala and Brandt, "A generic camera model and calibration method for conventional, wide-angle, and fish-eye
  lenses", IEEE TPAMI 28(8), 2006.
