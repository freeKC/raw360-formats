# Insta360 .insp and .insv

Dart: `readInsta360Trailer`, `calibrationOf`, `parseInsta360OffsetV1`, `parseInsta360OffsetV3`, `parseInsta360OffsetV6`,
`insta360TrackOrder`, `readInsta360PhotoHead`, `hasInsta360Trailer`, `splitPairOf` (lib/src/insta360_trailer.dart and
lib/src/raw_360_detection.dart).

## Structure

- A `.insp` photo is a JPEG holding both fisheye circles side by side, lens 0 in the left half. A `.insv` video is an
  MP4. Both end with the same trailer. Low resolution proxies (`.lrv`) carry it too.
- Lens 0 is the lens on the back of the camera (stream `00`), lens 1 the lens on the screen side (stream `10`). The
  calibration strings list lens 0 first, on the X3, the X4 and the X5 alike.
- Videos come in three layouts: one video track with both lenses side by side, lens 0 on the left (X3 and older at
  most resolutions, and the proxies); one video track per lens (X4 and later, two square tracks: track 0 holds lens 1
  on the X4 and the X5, see [Which track holds which lens](#which-track-holds-which-lens)); one file per lens, a "split
  pair" (X3 at 5.7K): `VID_20250101_120000_00_001.insv` holds lens 0 and `VID_20250101_120000_10_001.insv` lens 1. The
  proxies of a pair are `LRV_..._01_...` and `LRV_..._11_...`.

## The trailer

The last 72 bytes of the file:

| Offset from the end | Size | Content |
|---|---|---|
| 72 | 32 | reserved, zeros |
| 40 | 4 | u32 little endian: size of the trailer, these 72 bytes included |
| 36 | 4 | u32 little endian: version, 3 |
| 32 | 32 | ASCII magic `8db42d694ccc418790edff439fe026bf` |

The trailer payload starts at `fileSize` minus that size. It is a run of records. Each record is its payload followed by
a 6 byte footer: format (u8: 0 binary, 1 protobuf, 2 JSON), id (u8), payload length (u32 little endian).

Record ids seen on X3 files: 1 metadata (protobuf), 2 preview (a JPEG in a photo, an H.264 key frame in a proxy), 3 IMU
samples, 4 exposure time of each frame, 5 a copy of the preview, 9 and 11 auto exposure and white balance data, 10
highlights. Only 1 and 3 are read here.

Two ways to find the records:

- **Walked backwards** (X3 and older): start at `fileSize` minus 72, read the footer just before, skip the payload,
  repeat. On the X3 the metadata record comes last, so the calibration sits in the last 2 KB of the file.
- **Indexed** (X4 and later): the record right before the 72 byte tail has format 0 and id 0. It is a directory of 10
  byte entries: id (u8), format (u8), length (u32 LE), offset of the payload from the start of the trailer payload
  (u32 LE). The id comes first, unlike in a footer. All zero entries are padding. Records are padded (to 128 KiB
  boundaries according to insta360-rs and GyroView; 4 KiB alignment was seen on an X4 file), so they cannot be walked
  backwards. In a `.insv` the trailer may sit in a top level MP4 box of type `inst`, whose 8 byte header the trailer
  size leaves out.

The reader checks the footer of a record found through the directory against its directory entry.

## The metadata record (id 1, protobuf)

Read without a schema (lib/src/protobuf_reader.dart). The first occurrence of each field is kept.

| Field | Type | Meaning |
|---|---|---|
| 1 | string | serial number of the camera |
| 2 | string | camera model, "Insta360 X3" |
| 3 | string | firmware, "v1.0.93_build1" |
| 5 (17) | string | calibration string V1 (17: factory copy) |
| 19 | message {1 width, 2 height} | picture size: the whole side by side photo of a `.insp`, one lens square for a split pair |
| 26 | message {1 type, 2 index, 3 identity, 4 count} | the recording a file belongs to; both files of a split pair carry the same identity. Seen: index 0 in a video and 1 in its proxy; the identity empty on the X3, the path of the video on the card on the X4 and the X5 |
| 27 | message {1 srcW, 2 srcH, 3 dstW, 4 dstH, 5 offX, 6 offY} | window of the sensor the picture is cut from |
| 53 (55) | string | calibration string V2, not read |
| 54 (56) | string | calibration string V3 |
| 62 | varint | 1 when the IMU record holds raw 20 byte samples |
| 65 | message {1 accelerometer range in g, 2 gyroscope range in degrees per second} | full scale of the IMU; varints on the X3, floats in the schema |
| 68 | varint | lens guards, after insta360-rs: 4 plastic or 5 glass guards (X4), 6 automatic, field 104 then says which; not read. 0 or 6 on the files seen |
| 79 | varint | file layout: 0 unknown, 1 one file per lens, 2 one track per lens. 2 on every X4 and X5 video seen |
| 80 | varint | track order: 0 unknown, 1 track 0 holds lens 1, 2 track 0 holds lens 0. 1 on every X4 and X5 video seen |
| 104 | varint | lens guards when field 68 is 6, after insta360-rs: 1 plastic, 2 glass, 3 none; not read. 3 on the X4 and X5 files seen |
| 111 (112) | string | calibration string V6 (X5, X6) |
| 129 | varint | image category: 2 double fisheye, 6 equirectangular picture stitched in the camera. 2 on the X5 files seen |
| 131 | varint | stream layout: 1 one stream, 2 separate files, 3 two tracks, 4 two tracks with lens 1 in track 0. 4 on every X5 video seen, 1 on an X5 proxy |

Fields up to 65 follow the schema of telemetry-parser. Fields 26, 68, 79, 80, 104, 129 and 131 come from insta360-rs
and GyroView. The values seen come from X3, X4 (firmware v0.4.7) and X5 (v0.8.50 and v1.0.2) files, on which the
meaning of 80 and 131 was checked (see [Which track holds which lens](#which-track-holds-which-lens)). The X3 writes
none of 79, 80, 129 and 131; the X4 on v0.4.7 writes 79 and 80 but not 129 or 131. The X5 also writes 130 = 1 and
136 = 4 (after insta360-rs: no rotation, calibration of generation V6), not read.

## The IMU record (id 3)

- With field 62 set: 20 byte samples, u64 timestamp in microseconds, then accelerometer x, y, z and gyroscope x, y, z as
  u16 offset binary around 32768. Acceleration in g is `(v-32768) * range / 32768`, the range from field 65.
- Otherwise: 56 byte samples, i64 milliseconds, then six doubles, accelerometer in g first.
- At rest the accelerometer measures the reaction to gravity, which points up. The body frame of the camera has x to
  the right, y down and z along the axis of lens 0. On the X3 (and on the X4 Air, X5 and X6 as GyroView measured them)
  body x is IMU x, body y is IMU z and body z is IMU y negated. `downBodyFromAccelerometer` turns the mean of the
  samples into the direction of gravity in the body frame, which levels the picture.
- A `.insp` also holds one IMU sample in its EXIF MakerNote, as ASCII: six numbers joined by underscores, accelerometer
  then gyroscope, for example `-1.003906_-0.124023_0.082031_0.024501_0.007457_0.053263`. On the X3 it sits in the first
  4 KB of the file. The X3 writes no BodySerialNumber in its EXIF.

## The calibration strings

Numbers joined by underscores. The first one is the number of lenses (2), the last one a packed word whose high 16 bits
name the version (3 for V3, 6 for V6). Pixel values are in a calibration canvas of one area per lens side by side
(11904 x 5952 on the X3, two squares of 5952; 16000 x 6000 on the X4, two areas of 8000 x 6000; 10752 x 5376 on the
X5, two squares of 5376). Every string lists lens 0 first: its tx, ty and tz are zero and its cx falls in the left
area. The cx of lens 1 includes the width of the area of lens 0. Angles are in degrees.

| String | Tokens per lens | Model |
|---|---|---|
| V1 (16 tokens) | radius cx cy yaw pitch roll; then canvas width, height, packed word | equidistant fisheye; the radius marks about 100 degrees off axis on the X3 |
| V3 (40 tokens) | xi fx fy cx cy yaw pitch roll tx ty tz k1 k2 k3 p1 p2 w h type | unified camera model of Mei with three radial and two tangential terms |
| V6 (56 tokens) | xi fx fy cx cy yaw pitch roll tx ty tz k1 k2 k3 k4 k5 p1 p2 p3 p4 s1 s2 s3 s4 w h type | Mei with five radial terms; p3, p4 and s1 to s4 are left unread |

tx, ty, tz are likely the offset of the lens from lens 0 in metres: lens 1 has tz = -0.027 on the X3 and -0.032 on the
X4 and the X5, about the distance between the lenses mounted back to back. The stitch neglects them. `calibrationOf`
takes V3 first, then V6, then V1.

A real X3 string V3 (firmware v1.0.93), as the tests use it:

```
2_1.948170_4627.540_4627.460_2967.480_2999.850_-0.029_-0.038_89.510_0.000000_0.000000_0.000000_0.38808271_
1.29547262_-3.96876335_0.00178320_-0.00158561_11904_5952_71_1.948170_4615.530_4615.530_8933.200_2998.620_-0.030_
-0.086_89.487_-0.000275_0.000160_-0.026903_0.39306432_1.25673521_-3.90715361_-0.00147705_0.00090004_11904_5952_71_
199424
```

The roll near 90 degrees is how the sensors are mounted. The calibration is per unit: every file of the same camera
carries the same strings, so a cache keyed by the serial number can serve the files that have none (the members of an
X3 HDR group without trailer).

## From canvas pixels to frame pixels

- Photos: frame pixel = canvas pixel times `frameHeight / canvasSquare` (`canvasToFrameScale`, `calibrationForFrame`).
  Checked against exports of Insta360 Studio on X3 photos.
- Videos: the frames show the window of field 27, centred in the area of each lens on the canvas. Measured on an X3
  proxy, an X3 split pair and an X4 two track file: frame = (canvas minus the origin of the area of the lens minus
  ((srcW-dstW)/2, (srcH-dstH)/2)) times `frameSide / dstW`. The reader gives the window (`Insta360Trailer.crop`); the
  calibration stays in canvas pixels. On X5 two track files the seam is sharpest at that window (5312 of the 5376
  square) and much worse with the whole square (12.49 against 28.34 in the seam test below).

## Which track holds which lens

Checked on 23 October 2026 ([issue 1](https://github.com/freeKC/raw360-formats/issues/1)). On the X4 and the X5,
video track 0 holds lens 1, the second lens of the calibration strings, and track 1 holds lens 0, the first. Field
80 = 1 says so on both cameras and field 131 = 4 says the same on the X5; `insta360TrackOrder` reads them that way.

The files: X3 photos, proxies and a split pair, whose lens order is known, as a reference; two X4 videos (firmware
v0.4.7, one unit) and the proxy of one; two X5 videos from two units (firmware v0.8.50 and v1.0.2) and the proxy of
one. The X4 and X5 files are sample clips published with camera reviews; they are not part of this repository.

| Camera, file | 26: type, index | 79 | 80 | 129 | 131 | Track 0 holds |
|---|---|---|---|---|---|---|
| X3 split pair, `_00_` file | 0, 0 | | | | | one lens per file, lens 0 in `_00_` |
| X3 proxy | 0, 1 | | | | | both lenses, lens 0 on the left |
| X4 videos, v0.4.7 | 0, 0 | 2 | 1 | | | lens 1 |
| X4 proxy | 0, 1 | | | | | both lenses, lens 0 on the left |
| X5 videos, v0.8.50 and v1.0.2 | 0, 0 | 2 | 1 | 2 | 4 | lens 1 |
| X5 proxy | 0, 1 | | | 2 | 1 | both lenses, lens 0 on the left |

An empty cell is a field the file does not have. What shows the lens order:

- **The order of the strings.** In every V1, V3 and V6 string of every file, the first lens has tx = ty = tz = 0 and
  its cx in the left area of the canvas, the second tz = -0.027 (X3) or -0.032 (X4, X5). A proxy carries the same
  strings, in the same order, as its video.
- **Not the MP4.** Both video tracks have the handler `INS.HVC` and the size 3840 x 3840; nothing in the container
  names the lens. Track 0 here is the first video track (track_ID 1, ffmpeg `0:v:0`), whose first sample comes first
  in the `mdat`.
- **The proxies.** The left half of an X3 proxy matches the `_00_` file (correlation of the grey values 0.988, against
  0.145 for the `_10_` file). The left half of the X4 and X5 proxies matches track 1 (0.990 and 0.987) and the right
  half track 0 (0.967 and 0.942); the crossed pairs stay below 0.11.
- **The seam.** Each frame is stitched both ways, with the lens pose of this package, the V3 model and the window of
  field 27, and the two lenses are compared in the band 86 to 94 degrees off both axes: mean absolute difference of
  the grey values where both are lit, over a few frames, lower is better. Pairing A gives track 0 (or the `_00_` file,
  or the left half) the first lens of the strings, pairing B the second.

Three readings of the pose: the one of this package (`lensPose`, docs/stitching-math.md); the best of 32 for each
pairing (each sign of the yaw and the pitch of each lens, the roll mirrored or as written); and a turn of the second
lens fitted freely within 2 degrees, which leaves only the intrinsics to decide. Values A / B, then B/A for the
package pose:

| File | Known order | Package pose | B/A | Best of 32 | Free turn |
|---|---|---|---|---|---|
| X3 split pair | A | 17.00 / 18.58 | 1.093 | 16.52 / 17.22 | 15.87 / 16.00 |
| X3 two track file built from a proxy | A | 9.85 / 11.51 | 1.169 | 9.76 / 11.38 | 9.00 / 9.53 |
| X3 photo, halves | A | 5.85 / 6.11 | 1.044 | 5.79 / 6.07 | 5.71 / 5.90 |
| X3 proxy, halves | A | 14.87 / 16.20 | 1.089 | 14.87 / 15.23 | 14.46 / 14.46 |
| X4 video, daylight | | 26.26 / 25.93 | 0.987 | 22.66 / 22.16 | 22.50 / 21.05 |
| X4 video, night | | 29.86 / 29.37 | 0.984 | 21.25 / 19.71 | 21.03 / 19.01 |
| X4 proxy, halves | | 23.32 / 23.64 | 1.014 | 19.91 / 20.27 | 19.34 / 19.78 |
| X5 video, handlebar mount | | 33.13 / 31.72 | 0.957 | 32.07 / 31.68 | 31.42 / 30.22 |
| X5 video, selfie stick | | 15.03 / 12.49 | 0.831 | 14.83 / 11.85 | 14.72 / 11.45 |
| X5 proxy, halves | | 10.03 / 11.50 | 1.147 | 10.03 / 11.32 | 9.92 / 11.07 |

The test finds the known pairing on all four X3 files (the free turn only ties on the X3 proxy). On every X4 and X5
video B wins under all three readings, and on both proxies the left half, which is track 1, fits the first lens: track
0 holds the second lens. The V6 strings agree (X5 handlebar 33.60 / 32.11, selfie stick 15.33 / 14.13). The margins
are small where something close crosses the seam: an arm and a stick on the X4 clips, the bike within a metre of the
lenses on the handlebar clip.

**Why the margin is easy to miss.** Swapping the lenses is close to a half turn of the whole sphere: only the small
differences between the two lenses tell the pairings apart (here 0.6 to 1.2 degrees of yaw or roll, and principal
points up to 14 canvas pixels apart). The margin shows only at the right radial scale and with the roll mirrored. On
the selfie stick clip the seam is lowest at the window of field 27, and only there do the pairings differ:

| Side of the window on the canvas | 5250 | 5290 | 5312 (field 27) | 5335 | 5376 (whole square) |
|---|---|---|---|---|---|
| A | 27.44 | 20.10 | 15.05 | 21.19 | 28.26 |
| B | 27.99 | 20.08 | 12.49 | 20.77 | 28.34 |

A radial scale 0.4 % off makes the two pairings look alike. With the roll as written instead of mirrored, the same
clip prefers A (16.41 against 16.91), but two X3 references then pick the wrong pairing too (split pair 22.51 against
22.29, proxy 19.76 against 19.43). A stitcher that fits its scale per file, or reads the roll another way, can thus see
a small margin the other way round.

### Confirmed on a library of 44 X5 clips

Checked again by golblick (AkshayRao27) on 31 October 2026 on the 44 X5 videos of one library, firmware 1.7.43 to
1.11.10 ([pulsejet/memories#1739](https://github.com/pulsejet/memories/issues/1739#issuecomment-6546198600),
[golblick's format notes](https://github.com/AkshayRao27/golblick/blob/main/docs/formats/insta360-agent-notes.md#which-track-holds-which-lens-x5-video),
commit [2330a4f](https://github.com/AkshayRao27/golblick/commit/2330a4f)): field 80 = 1 and field 131 = 4 on all 44;
on the 32 proxies still beside their video, the left half matches track 1 and the right half track 0 (grey correlation
0.987 to 1.000, the crossed pairs at most 0.86); the fit of either pairing to the camera's own stitch of the opening
frame cannot tell them apart (the file's pairing scores better on 26 of 44 clips, the first six all favoured it), as
the paragraph above expects for a stitcher that fits its scale per file. The swap had shown in golblick as two half
turns, a separate inertial axis map for videos and a video opening the other way round from the photos; both went
away with the tracks paired by field 80, and one axis map now serves the X5's photos and videos. No two track file
has yet shown field 80 with a value other than 1.

### Lens guards and the radial scale

Found by golblick (AkshayRao27) and reported in
[pulsejet/memories#1739](https://github.com/pulsejet/memories/issues/1739#issuecomment-6360996662): on the X5, the
exports of Insta360 Studio with the standard lens guards and without them differ by a pure radial scale of 2.25 %.
That may account for part of the per unit scale GyroView found on the X5 and the X6 (1.008 to 1.045). Fields 68 and
104 tell whether guards were on; none of the files here had guards, so it could not be checked here.

## What is known, and what is guessed

| Point | Status |
|---|---|
| Tail, records walked backwards, metadata fields 1 to 65 | checked on X3 photos, an X3 proxy and an X3 split pair |
| Mei model of V3, lens pose, levelling by the accelerometer | checked on X3 photos against Insta360 Studio, within about a degree of yaw |
| Indexed trailer | seen on X4 and X5 files; on the X6, from GyroView and insta360-rs |
| Order of the calibration strings: lens 0 first | seen on X3, X4 and X5 files |
| Field 80 = 1, and field 131 = 4 on the X5: track 0 holds lens 1 | checked at the seam and on the proxies, on two X4 files of one unit and two X5 units (23 October 2026) |
| Field 80 = 2 and field 131 = 3: track 0 holds lens 0 | not seen |
| Fields 26, 79, 129 | seen on X4 and X5 files, 26 on the X3 too |
| The X4 writes an hvcC whose profile, tier and level bytes are zeros | seen on an X4 file: the probe reads the profile from the SPS instead |
| V6 strings | seen on two X5 units, with the same seam verdict as V3; k4 and k5 after GyroView; the X6 not seen |
| Window of field 27 on the X5 | the seam is lowest at the window, not at the whole square |
| Per unit radial scale on the X5 and X6 (GyroView: 1.008 to 1.045) | not applied; the lens guards change the scale by 2.25 % (golblick) |
| Lens pose on the X4 | open: on both X4 clips the seam is much lower with the yaw of one lens negated (22.16 against 25.93 by day, 19.71 against 29.37 at night), as if the pose were about a degree off on the X4; the gain is small or none on the X3 and the X5 |
| The `_10_` file of a split pair has no trailer on the X3 | seen on one pair; the reader reads the `_00_` file first |

## Inspect a file

```sh
# The tail: size, version and magic
tail -c 72 IMG_20250101_120000_00_001.insp | xxd

# exiftool reads the trailer of X3 and older files (group Insta360), including the V1 string as "Parameters"
exiftool -a -G1 -ee -Insta360:all IMG_20250101_120000_00_001.insp

# The tracks of a video, and one frame of each lens of a two track file
ffprobe -v error -show_entries stream=index,codec_type,codec_name,width,height:stream_tags=handler_name -of compact VID.insv
ffmpeg -ss 5 -i VID.insv -map 0:v:0 -frames:v 1 track0.png -map 0:v:1 -frames:v 1 track1.png

# What this package reads
dart run example/inspect.dart IMG_20250101_120000_00_001.insp
```

`dart run tool/write_samples.dart` writes small synthetic files to try these commands on.

## References

- telemetry-parser (MIT or Apache-2.0), `src/insta360/`: record types and the metadata schema. https://github.com/AdrianEddy/telemetry-parser
- insta360-rs (Apache-2.0), `docs/INSV_FORMAT.md`: indexed records, newer fields, file naming. https://github.com/OpenSpeleo/insta360-rs
- GyroView (MIT), `docs/FORMAT.md` and its ADRs: lens pose convention measured against Insta360 Studio, IMU axes, V6. https://github.com/bubo-squared/GyroView
- orbis-reframe (GPL-3.0): real time stitching of X5 files on Linux. https://github.com/Schabo/orbis-reframe
- ExifTool reads the trailer as its Insta360 group. https://exiftool.org/TagNames/QuickTime.html
