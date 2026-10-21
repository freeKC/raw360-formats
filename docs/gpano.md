# GPano XMP of panoramas

Dart: `readGPanoTags`, `parseGPanoTags`, `parseGPanoProjectionType`, `parseGPanoCrop`, `parseGPanoInitialView`,
`isEquirectangularGPano`, `isHalfSphereGPano`, `initialViewDirection` (lib/src/gpano.dart).

## Structure

Photo sphere metadata is an XMP packet in the namespace `http://ns.google.com/photos/1.0/panorama/`, prefix `GPano`.
In a JPEG it is an APP1 segment that starts with `http://ns.adobe.com/xap/1.0/` and a NUL, near the head of the file.
Cameras write the tags as attributes of `rdf:Description` (`GPano:ProjectionType="equirectangular"`); exiftool writes
them as elements (`<GPano:ProjectionType>equirectangular</GPano:ProjectionType>`) when it copies them. Both are read,
with a regular expression rather than an XML parser, in the first 128 KiB of the file, else in the last 128 KiB (where
a WebP may carry them).

| Tag | Use here |
|---|---|
| ProjectionType | "equirectangular" makes a 360° panorama (in any case); "cylindrical" a flat one |
| FullPanoWidthPixels, FullPanoHeightPixels | the size of the full sphere |
| CroppedAreaLeftPixels, CroppedAreaTopPixels, CroppedAreaImageWidthPixels, CroppedAreaImageHeightPixels | the part of the full sphere the image covers |
| InitialViewHeadingDegrees, InitialViewPitchDegrees | the view to open on, read only when both are set (as Photo Sphere Viewer does) |
| PoseHeadingDegrees | the compass heading of the centre of the image, 0 when missing |

The crop is given normalised to the full sphere (`NormalizedRect`). Many cameras write crop tags on full spheres too:
`isPartialSphere` takes a crop within 1 percent of the whole sphere for no crop. A crop about half as wide as the full
panorama (0.45 to 0.55) and nearly as high (more than 0.9) is a VR180 photo (`isHalfSphereGPano`).

The initial view becomes a direction with `initialViewDirection`: the longitude is how far clockwise the initial heading
is from the pose heading (0 at the centre column of the full panorama), the latitude is the pitch, clamped to the poles.

## What is known, and what is guessed

| Point | Status |
|---|---|
| Attribute and element forms, crop, initial view | read on camera photos and on previews whose tags exiftool copied |
| Half sphere from a crop of 0.45 to 0.55 of the width | a rule of this package |
| Tags past the first and the last 128 KiB of a file | not read |

## Inspect a file

```sh
exiftool -XMP-GPano:all photo.jpg
dart run example/inspect.dart photo.jpg
```

## References

- Photo Sphere XMP metadata. https://developers.google.com/streetview/spherical-metadata
- Photo Sphere Viewer, which reads the same tags on the web. https://photo-sphere-viewer.js.org/
- ExifTool, XMP GPano tags. https://exiftool.org/TagNames/XMP.html#GPano
