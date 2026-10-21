# Insta360 .insp and .insv

Dart: `readInsta360Trailer`, `calibrationOf`, `parseInsta360OffsetV1`, `parseInsta360OffsetV3`, `parseInsta360OffsetV6`,
`insta360TrackOrder`, `readInsta360PhotoHead`, `hasInsta360Trailer`, `splitPairOf` (lib/src/insta360_trailer.dart and
lib/src/raw_360_detection.dart).

## Structure

- A `.insp` photo is a JPEG holding both fisheye circles side by side, lens 0 in the left half. A `.insv` video is an
  MP4. Both end with the same trailer. Low resolution proxies (`.lrv`) carry it too.
- Lens 0 is the lens on the back of the camera (stream `00`), lens 1 the lens on the screen side (stream `10`).
- Videos come in three layouts: one video track with both lenses side by side (X3 and older at most resolutions); one
  video track per lens (X4 and later, two square tracks); one file per lens, a "split pair" (X3 at 5.7K):
  `VID_20250101_120000_00_001.insv` holds lens 0 and `VID_20250101_120000_10_001.insv` lens 1. The proxies of a pair
  are `LRV_..._01_...` and `LRV_..._11_...`.

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
| 26 | message {1 type, 2 index, 3 identity, 4 count} | the recording a file belongs to; both files of a split pair carry the same identity |
| 27 | message {1 srcW, 2 srcH, 3 dstW, 4 dstH, 5 offX, 6 offY} | window of the sensor the picture is cut from |
| 53 (55) | string | calibration string V2, not read |
| 54 (56) | string | calibration string V3 |
| 62 | varint | 1 when the IMU record holds raw 20 byte samples |
| 65 | message {1 accelerometer range in g, 2 gyroscope range in degrees per second} | full scale of the IMU; varints on the X3, floats in the schema |
| 79 | varint | file layout: 0 unknown, 1 one file per lens, 2 one track per lens |
| 80 | varint | track order: 0 unknown, 1 track 0 holds lens 1, 2 track 0 holds lens 0 |
| 111 (112) | string | calibration string V6 (X5, X6) |
| 129 | varint | image category: 2 double fisheye, 6 equirectangular picture stitched in the camera |
| 131 | varint | stream layout: 1 one stream, 2 separate files, 3 two tracks, 4 two tracks reversed |

Fields up to 65 follow the schema of telemetry-parser. Fields 26, 79, 80, 129 and 131 come from insta360-rs and GyroView.

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
(11904 x 5952 on the X3, two squares of 5952; 16000 x 6000 on the X4, two areas of 8000 x 6000). The cx of lens 1
includes the width of the area of lens 0. Angles are in degrees.

| String | Tokens per lens | Model |
|---|---|---|
| V1 (16 tokens) | radius cx cy yaw pitch roll; then canvas width, height, packed word | equidistant fisheye; the radius marks about 100 degrees off axis on the X3 |
| V3 (40 tokens) | xi fx fy cx cy yaw pitch roll tx ty tz k1 k2 k3 p1 p2 w h type | unified camera model of Mei with three radial and two tangential terms |
| V6 (56 tokens) | xi fx fy cx cy yaw pitch roll tx ty tz k1 k2 k3 k4 k5 p1 p2 p3 p4 s1 s2 s3 s4 w h type | Mei with five radial terms; p3, p4 and s1 to s4 are left unread |

tx, ty, tz are likely the offset of the lens from the centre of the camera in metres (lens 1 of an X3 has tz = -0.027,
about the distance between the lenses); the stitch neglects them. `calibrationOf` takes V3 first, then V6, then V1.

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
  calibration stays in canvas pixels.

## What is known, and what is guessed

| Point | Status |
|---|---|
| Tail, records walked backwards, metadata fields 1 to 65 | checked on X3 photos, an X3 proxy and an X3 split pair |
| Mei model of V3, lens pose, levelling by the accelerometer | checked on X3 photos against Insta360 Studio, within about a degree of yaw |
| Indexed trailer, field 80 = 1 meaning track 0 holds lens 1 | seen on two X4 files |
| The X4 writes an hvcC whose profile, tier and level bytes are zeros | seen on an X4 file: the probe reads the profile from the SPS instead |
| V6 with k4 and k5, indexed trailer of the X5 and X6 | from GyroView and insta360-rs, not checked here |
| Fields 26, 79, 129, 131 | from GyroView and insta360-rs, not checked here (GyroView marks 131 provisional) |
| Per unit radial scale on the X5 and X6 (GyroView: 1.008 to 1.045) | not applied |
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
