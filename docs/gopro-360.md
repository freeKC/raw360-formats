# GoPro MAX and MAX 2 .360

Dart: `goProEacGeometryOf`, `GoProEacGeometry`, `goProViewToCamera`, `goProEacSamples`, `GoProEacSampler`
(lib/src/gopro_eac.dart and lib/src/raw_sampler.dart).

## Structure

A `.360` file is an MP4 with two HEVC video tracks of equi-angular cube map (EAC) faces, three faces per track. On a
real GoPro MAX file (firmware H19.03.01.30.00) the moov box comes last and holds seven tracks:

| Track | Handler | Sample entry | Content |
|---|---|---|---|
| 1 | vide "GoPro H.265" | hvc1 4096 x 1344 | left, front and right faces |
| 2 | soun "GoPro AAC" | mp4a | stereo sound |
| 3 | tmcd "GoPro TCD" | tmcd | timecode |
| 4 | meta "GoPro MET" | gpmd | GPMF telemetry (accelerometer, gyroscope, gravity) |
| 5 | meta "GoPro SOS" | fdsc | |
| 6 | vide "GoPro H.265" | hvc1 4096 x 1344 | bottom, back and top faces |
| 7 | soun "GoPro AMB" | in32 | ambisonic sound |

The handler names are counted (QuickTime) strings without a NUL. ffprobe numbers the video streams 0 and 5 (0 and 4 in
TimeWarp files): take the video tracks in moov order, not by stream index.

## The faces

Each track is W x H pixels with faces of side F = H: a split face, the whole middle face, then another split face. The
two halves of a split face repeat `overlap = (W-3H)/2` columns, which blend into each other.

| | MAX | MAX 2 (8 bit) | MAX 2 (10 bit) |
|---|---|---|---|
| Track size | 4096 x 1344 | 5888 x 1920 | 5952 x 1920 |
| Face F | 1344 | 1920 | 1920 |
| Overlap | 32 | 64 | 96 |
| Half slot `F/2 + (W-3H)/4` | 688 | 992 | 1008 |
| Middle face starts at `2 half` | 1376 | 1984 | 2016 |
| Right slot starts at `middle + F` | 2720 | 3904 | 3936 |

`GoProEacGeometry.fits` takes tracks whose width is at least three times the height, with W-3H a multiple of 4 and at
most 256, and an even height.

The face table, in the camera frame of max2-reframe-resolve (x right, y up, z forward along the front lens): for each
face, the track, the slot (0 left split, 1 middle, 2 right split), the direction it faces, and the directions of its
columns and rows.

| Face | Track | Slot | Forward | Columns | Rows |
|---|---|---|---|---|---|
| left | 0 | 0 | (-1, 0, 0) | (0, 0, 1) | (0, -1, 0) |
| front | 0 | 1 | (0, 0, 1) | (1, 0, 0) | (0, -1, 0) |
| right | 0 | 2 | (1, 0, 0) | (0, 0, -1) | (0, -1, 0) |
| bottom | 1 | 0 | (0, -1, 0) | (0, 0, -1) | (-1, 0, 0) |
| back | 1 | 1 | (0, 0, -1) | (0, 1, 0) | (-1, 0, 0) |
| top | 1 | 2 | (0, 1, 0) | (0, 0, 1) | (-1, 0, 0) |

For a direction c of the camera frame: pick the face with the largest `dot(c, forward)`; then
`col = (atan(dot(c, columns) / dot(c, forward)) * 4/pi + 1) / 2 * F` and the same for the row. A middle face is read at
column `middle + col`. A split face is read at `base + col` in its first half and at `base + half + col-(F-half)` in
its second half, the second half weighing `clamp((col-0.5-(F-half)) / overlap, 0, 1)` (base 0 or `right`).
docs/stitching-math.md gives the view frame these directions come from.

## Orientation

The view frame of this package has x right, y down, z forward. `goProViewToCamera` turns it into the camera frame of the
table:

- MAX (faces of 1344): `[[0, 1, 0], [1, 0, 0], [0, 0, 1]]`, a quarter turn about the front axis times diag(1, -1, 1).
  Checked on a real MAX file: with the table as it is, the picture is rolled by 90 degrees; with this matrix the sky is
  up, and the accelerometer of the GPMF stream agrees with an upright camera.
- MAX 2 (faces of 1920): diag(1, -1, 1), as max2-reframe-resolve fits its model to GoPro Player exports.

There is no lens calibration in the file: the geometry comes from the size of the tracks. No levelling is applied: the
GPMF gravity stream could level a tilted clip.

## What is known, and what is guessed

| Point | Status |
|---|---|
| Track list, handler names, 4096 x 1344 geometry, face table, overlap blend | checked on one real MAX file: every face joins its neighbours |
| Quarter turn of the MAX | checked on that file |
| MAX 2 track sizes and orientation | from max2-reframe-resolve, no MAX 2 file checked here |
| TimeWarp files | not checked |
| `.36P` photos of the MAX 2 | plain equirectangular JPEGs, see camera-equirect-photos.md |

## Inspect a file

```sh
# The tracks and their handler names
ffprobe -v error -show_entries stream=index,codec_type,codec_name,width,height:stream_tags=handler_name -of compact GS010001.360

# One frame of each EAC track
ffmpeg -ss 5 -i GS010001.360 -map 0:v:0 -frames:v 1 eac0.png -map 0:v:1 -frames:v 1 eac1.png

# The GPMF telemetry (accelerometer, gyroscope, gravity)
exiftool -a -G1 -ee -api LargeFileSupport=1 GS010001.360

# What this package reads
dart run example/inspect.dart GS010001.360
```

FFmpeg builds with OpenCL have a `gopromax_opencl` filter made for the two tracks of a GoPro MAX file.

## References

- max2-reframe-resolve (MIT), `proto/eac.py`: the face table and the EAC formulas this package follows (see
  THIRD_PARTY_NOTICES.md). https://github.com/Sean-McConnachie/max2-reframe-resolve
- GoPro GPMF parser and format notes. https://github.com/gopro/gpmf-parser
- FFmpeg filters `v360` and `gopromax_opencl`. https://ffmpeg.org/ffmpeg-filters.html
- ExifTool, GoPro tags. https://exiftool.org/TagNames/GoPro.html
