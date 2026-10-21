# Stereo layout and sphere coverage

Dart: `guessStereoLayout`, `guessSphereCoverage`, `resolveSphereView`, `sphereCrop`, `isPartialSphere`
(lib/src/stereo_layout.dart and lib/src/sphere_coverage.dart).

Many 3D and VR180 files carry no metadata that says so: a photo without GPano tags, a video re-encoded without its
`st3d` and `sv3d` boxes. These rules guess from what is left. They are rules of this package, not of a specification;
a viewer should let the user correct them.

## Stereo layout

Each eye of a full sphere is a 2:1 equirectangular image; each eye of a half sphere (VR180) is a square 180° image.

| Frame | Full sphere | Half sphere |
|---|---|---|
| 1:1 | two eyes stacked, left on top | |
| 4:1 | two eyes side by side, left on the left | |
| 1:2 | | two eyes stacked |
| 2:1 | mono | two eyes side by side |

Within 10 percent of those ratios. Anything else is mono, as are unknown sizes and partial panoramas (a GPano crop
gives the image any aspect ratio).

## Sphere coverage

A media is a half sphere when any of these says so, in this order; else it is a full sphere:

1. the file's spherical metadata: an `equi` projection cropped to about half the width, or a `mshp` mesh (a file that
   declares a full sphere stops here: a side by side 360° video squeezed into 2:1 has square eyes too);
2. a GPano crop 0.45 to 0.55 of the full width and more than 0.9 of its height;
3. square eyes (aspect ratio 0.9 to 1.1) in a 3D layout;
4. the file name: `vr180`, `180x180`, `180_3d`, or `180` on its own after an underscore, a dash, a dot or a space
   (`trip_180.mp4`), but not as the start of a longer number (`IMG_1801.JPG`).

`resolveSphereView` puts both together: the coverage the user chose, else the guess; the layout the user chose, else
the one the file declares, else the guess for that coverage. `sphereCrop` gives the part of the full sphere to map the
image (or each eye) on: the GPano crop of a partial panorama, the front half (longitudes from -90° to +90°) for a half
sphere, else the whole sphere.

## Try it

```sh
dart test test/stereo_layout_test.dart test/sphere_coverage_test.dart
```

## References

- VR180 Video Format, for the half sphere projection. https://github.com/google/spatial-media/blob/master/docs/vr180.md
- The tests of these rules list the sizes and names they were written for: test/stereo_layout_test.dart and
  test/sphere_coverage_test.dart.
