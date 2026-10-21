# 360° photos stitched in the camera, and how to tell a 360° photo

Dart: `probe360Photo`, `isEquirectCameraPhoto`, `isInsta360StitchedPhoto`, `isPanoramaCandidate`, `parseExifHead`
(lib/src/raw_360_detection.dart and lib/src/exif_head.dart).

## Structure

360° cameras stitch photos themselves too, and do not always say so in GPano XMP:

| Camera | Photo | How to tell |
|---|---|---|
| GoPro MAX | `.JPG`, 5760 x 2880 | GPano XMP |
| GoPro MAX 2 | `.36P`, a plain JPEG, 7680 x 3840 | the extension |
| DJI Osmo 360 | `.JPG` up to 15520 x 7760 | GPano XMP (`ProjectionType=equirectangular`) |
| Insta360, stitched in the camera | JPEG with the Insta360 trailer | field 129 of the trailer is 6 |
| Insta360, raw | `.insp`, two fisheye circles | the extension, or the trailer when renamed |
| DJI single lens photos | 4:3, 6400 x 4800 | not 2:1: flat |

When the GPano tags are missing, a 2:1 photo (within 1 percent) is taken as equirectangular when its EXIF names a 360°
camera: Make contains "gopro" and Model contains "max"; Make contains "dji" and Model contains "360" or "oq" (as in the name of
its metadata schema, dvtm_oq101); or Make is "Arashi Vision" (Insta360). Case aside. The EXIF is read from the first 4 KB of the
file: Make (0x010F), Model (0x0110), then in the Exif IFD the MakerNote (0x927C), PixelXDimension and PixelYDimension
(0xA002, 0xA003) and BodySerialNumber (0xA431).

## How `probe360Photo` decides

1. GPano XMP with an equirectangular projection: 360°, half sphere when the crop says so.
2. Else the trailer of an Insta360 camera at the end of the file: a raw dual fisheye photo, unless the file is not named
   `.insp` and field 129 of the trailer is 6 (stitched in the camera): then an equirectangular photo.
3. Else the EXIF and 2:1 rule above.
4. Else flat.

`isPanoramaCandidate` tells which files of a large gallery are worth reading at all: a 2:1 frame (within 2 percent); a
name with `360` on its own (not `IMG_1360.JPG`), `pano`, `vr180`, or a raw or `.36p` extension; or a square or 1:2
frame whose name says `3d` or `vr180` (two eyes stacked).

## What is known, and what is guessed

| Point | Status |
|---|---|
| Insta360 X3 photos, raw and stitched | checked on real files |
| GoPro MAX JPG with GPano, DJI Osmo 360 JPG with GPano, MAX 2 `.36P` sizes | from public reports, not checked here |
| Make and Model values ("GoPro", "GoPro Max", "DJI", "Osmo 360", "Arashi Vision") | from real files and public reports; other firmware may write others |

## Inspect a file

```sh
exiftool -Make -Model -ImageSize -XMP-GPano:ProjectionType photo.jpg
dart run example/inspect.dart photo.jpg
```

## References

- ExifTool, EXIF tags. https://exiftool.org/TagNames/EXIF.html
- Photo Sphere XMP metadata. https://developers.google.com/streetview/spherical-metadata
