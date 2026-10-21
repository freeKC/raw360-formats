# Apple spatial photos (HEIC stereo pairs)

Dart: `probeHeicStereoPair`, `HeicStereoPair` (lib/src/heic_stereo_probe.dart). Spatial videos (MV-HEVC) are in
spherical-video-metadata.md.

## Structure

A spatial photo is a HEIF file (brands `heic`, `heix`, `mif1` or `msf1`) whose `meta` box holds two visible images
grouped as a stereo pair:

| Box | Content |
|---|---|
| `meta/pitm` | the primary item, which every decoder shows: the left eye in the files seen |
| `meta/iinf/infe` | the items and their types (`hvc1`, `grid`, `iovl`, `iden`, `av01`, `jpeg`) |
| `meta/iprp/ipco`, `ipma` | the properties and which item has which (`ispe` size, `irot` rotation, ...) |
| `meta/grpl/ster` | an entity group: entity 0 is the left eye, entity 1 the right eye |
| `meta/grpl/altr` | a group of alternatives; an eye may be such a group, which stands for its first picture |

Properties of an eye or of the `ster` group, as uuid boxes written by Apple ImageIO:

| uuid | Content |
|---|---|
| `de225085-36cb-4365-8743-2f8705e7c78a` | disparity adjustment, int32, in 1/10000 of the width of an eye |
| `22cc04c7-d6d9-4e07-9d90-4eb6ecbaf3a3` | intrinsics; the second u32 is the focal length in 1/65536 pixel, which gives the horizontal field of view |
| `4363e914-5b7d-4aab-97ae-bea69803b434` | extrinsics (position of the camera, the baseline for the right eye) |

The meta box sits at the head of the file, ahead of the image data: one read of 64 KiB is enough for nearly every file.
`HeicStereoPair.pitmIdOffset` gives where the item ID of `pitm` is in the file: a viewer that writes the right eye's ID
there, in a copy of the head of the file, makes any HEIF decoder decode the right eye.

## What is known, and what is guessed

| Point | Status |
|---|---|
| ster group, eyes, size, rotation, disparity, field of view | read on one public sample made with Apple ImageIO, and on synthetic files |
| Properties of eyes from other iPhone models | unknown ones are listed in `HeicStereoPair.unknownProperties` |

## Inspect a file

```sh
exiftool -a -G1 spatial.heic
dart run example/inspect.dart spatial.heic
```

## References

- HEIF, ISO/IEC 23008-12 (entity groups, `ster`, `altr`).
- libheif, a HEIF decoder. https://github.com/strukturag/libheif
- Apple developer documentation, Image I/O: "Creating spatial photos and videos with spatial metadata".
