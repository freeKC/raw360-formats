# raw360-formats

Notes on how 360° cameras store their raw files, lens calibration and spherical metadata, with a pure Dart package
that reads them.

- **Raw camera files**: Insta360 `.insp` and `.insv` (the trailer, its calibration strings V1, V3 and V6, the IMU, split
  pairs, two track files), GoPro MAX and MAX 2 `.360` (the two EAC tracks), DJI Osmo 360 `.osv` (the `camd` box and its
  Kannala-Brandt calibration).
- **Spherical and stereo metadata**: GPano XMP of photos, Spherical Video V1 and V2 (`st3d`, `sv3d`), VR180, Apple
  spatial photos (HEIC stereo pairs) and videos (MV-HEVC).
- **Rules** for files that say nothing: equirectangular photos stitched in the camera, stereo layout and half sphere
  guessed from the frame and the name.
- **Reference math** to stitch the raw files: lens models of Mei, equidistant and Kannala-Brandt, lens poses, levelling
  by the accelerometer, blending, GoPro EAC sampling, and a CPU stitch to check a shader against.

## Who it is for

- Authors of viewers, players, galleries and converters, in any language: the notes in docs/ give offsets, field
  numbers and formulas, say what was checked on real files and what was not, and show commands to inspect a file.
- Dart and Flutter apps: the package reads all of it from a file, from memory or over HTTP range requests, without
  Flutter and without native code.

## The notes

| Page | Content |
|---|---|
| [docs/insta360.md](docs/insta360.md) | Insta360 `.insp` and `.insv`: trailer, records, metadata fields, IMU, calibration strings, split pairs |
| [docs/gopro-360.md](docs/gopro-360.md) | GoPro MAX and MAX 2 `.360`: tracks, EAC faces, orientation |
| [docs/dji-osv.md](docs/dji-osv.md) | DJI Osmo 360 `.osv`: the `camd` box, calibration slots, lens pose |
| [docs/spherical-video-metadata.md](docs/spherical-video-metadata.md) | MP4 and MOV: Spherical Video V1 and V2, VR180, MV-HEVC, tracks and codecs |
| [docs/gpano.md](docs/gpano.md) | GPano XMP of photos: projection, crop, initial view |
| [docs/apple-spatial.md](docs/apple-spatial.md) | Apple spatial photos: HEIC stereo pairs |
| [docs/camera-equirect-photos.md](docs/camera-equirect-photos.md) | Photos stitched in the camera, and how to tell a 360° photo |
| [docs/stereo-and-coverage.md](docs/stereo-and-coverage.md) | Guessing the stereo layout and the half sphere |
| [docs/stitching-math.md](docs/stitching-math.md) | Frames, lens models, poses, blending |

What was checked on real files: Insta360 X3 photos, proxies and a split pair, Insta360 X4 and X5 two track files and
their proxies (the X5 for the trailer and the lens order), a GoPro MAX `.360`, a DJI Osmo 360 `.osv`, and a public
sample of an Apple spatial photo. What was not: Insta360 X4 Air and X6, GoPro MAX 2, other DJI models and recording
modes. Each page says which statement rests on what. Reports from other cameras and
firmware are welcome as issues, with the metadata only (the output of the commands of the page) rather than the file.

## Use the package

It is not on pub.dev yet. Add it from git:

```yaml
dependencies:
  raw360_formats:
    git:
      url: https://github.com/freeKC/raw360-formats.git
      ref: main
```

Dart 3.8 or later. Dependencies: `collection` and `logging`.

Every reader takes a `ByteRangeReader`, a function that returns the bytes of a range of the file:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:raw360_formats/raw360_formats.dart';

Future<void> main() async {
  final file = await File('VID_20250101_120000_00_001.insv').open();
  Future<Uint8List> read(int offset, int length) async {
    await file.setPosition(offset);
    return file.read(length);
  }

  final trailer = await readInsta360Trailer(read, await file.length());
  final calibration = trailer == null ? null : calibrationOf(trailer);
  print('${trailer?.cameraModel}: ${calibration?.model}, lens 0 centre ${calibration?.lenses[0].cx}');

  final probe = await probeSphericalMetadata(read);
  print('video tracks: ${probe.videoTracks.length}, stereo: ${probe.stereo}, half sphere: ${probe.halfSphere}');
  await file.close();
}
```

Over HTTP, the reader sends a `Range: bytes=offset-end` header and returns the body. The readers never load a whole
file: a few reads at the head and at the tail, a few hundred KB at most.

`example/inspect.dart` prints what the package reads in any file:

```sh
dart run example/inspect.dart IMG_20250101_120000_00_001.insp GS010001.360 clip.mp4
```

`tool/write_samples.dart` writes small synthetic files of each format, to try the commands of the notes without a
camera.

## How it was tested

- 241 unit tests on synthetic data: MP4 boxes, trailers, protobuf records, EXIF and HEIF written byte by byte by the
  builders of test/fixtures/, and a stitch test that draws lens pictures from a known pattern and stitches them back.
- The calibration values in the fixtures are those of a real Insta360 X3 and a real Osmo 360; serial numbers are made
  up. No photo or video is in the repository.
- The real files listed above were checked privately; they are not shipped.
- Every push runs `dart analyze` and `dart test` in GitHub Actions.

The code comes from [Immuch360](https://github.com/freeKC/Immuch360), an unofficial fork of the Immich mobile app,
where it reads raw 360° files from phones, NAS shares and servers. It is published here on its own, without anything of
the app, so that other projects can use it. Problems with this package go to the issues of this repository; problems
with the app go to https://github.com/freeKC/Immuch360/issues.

## Credits

- telemetry-parser by Adrian Eddy, for the Insta360 and DJI metadata schemas. https://github.com/AdrianEddy/telemetry-parser
- insta360-rs, for the indexed trailer and the fields of the newer Insta360 cameras. https://github.com/OpenSpeleo/insta360-rs
- GyroView, for the Insta360 lens pose convention, the IMU axes and V6. https://github.com/bubo-squared/GyroView
- OSVplat by Piotr Godlewski, for the Osmo 360 `camd` records and lens pose. https://github.com/pgodlews/OSVplat
- max2-reframe-resolve by Sean McConnachie, for the GoPro EAC layout. https://github.com/Sean-McConnachie/max2-reframe-resolve
- orbis-reframe, mpv360 and ExifTool, which do related work and are cited in the notes.

## Licence

MIT, see LICENSE. Some files follow MIT licensed code of other projects; their notices are in THIRD_PARTY_NOTICES.md.
