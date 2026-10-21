# Spherical and stereo metadata of MP4 and MOV videos

Dart: `probeSphericalMetadata`, `SphericalProbe`, `ProbedTrack`, `MultiviewInfo`, `listTopLevelBoxes`
(lib/src/spherical_probe.dart).

## Structure

The metadata sits in the sample entry of the video track (`moov/trak/mdia/minf/stbl/stsd/<entry>`), which is in the
moov box: at the head of a file written for streaming, at its end in a file a camera recorded. The probe walks the top
level boxes a header at a time, reads at most 4 MiB of the moov box, and one more read of at most 256 KiB for each
trak box past that.

### Spherical Video V2 (google/spatial-media)

| Box | Content |
|---|---|
| `st3d` | full box, then stereo_mode (u8): 0 mono, 1 top and bottom (left eye on top), 2 left and right (left eye on the left) |
| `sv3d/svhd` | full box, then the name of the tool that wrote the metadata |
| `sv3d/proj/prhd` | full box, then yaw, pitch and roll of the pose (16.16 fixed point) |
| `sv3d/proj/equi` | full box, then the bounds cropped from the top, bottom, left and right edges (u32 each, 0.32 fixed point) |
| `sv3d/proj/cbmp` | cube map |
| `sv3d/proj/mshp` | mesh projection, which VR180 cameras write |

A half sphere (VR180) is an `equi` projection whose left and right bounds add up to 0.4 to 0.6 of the width, or a
`mshp` mesh. A cube map or a full `equi` is a full sphere.

### Spherical Video V1

A `uuid` box of type `ffcc8263-f855-4a93-8814-587a02521fdd` in the video track, holding XML: `GSpherical:Spherical`
(true), `GSpherical:StereoMode` (mono, top-bottom, left-right) and optional crop tags named like the GPano ones
(`CroppedAreaImageWidthPixels`, `FullPanoWidthPixels`). A cropped width of 0.4 to 0.6 of the full width is a half
sphere.

### Apple spatial video (MV-HEVC)

An HEVC track with a second layer: an `lhvC` box next to `hvcC`, and a `vexu` box. `vexu/eyes/stri` (full box, one
byte: 4 reserved bits, eyes reversed, more views, right eye, left eye) says both eyes are there; `hero` gives the eye to
show in 2D (0 none, 1 left, 2 right); `cams/blin` the baseline in micrometres; `cmfy/dadj` the disparity adjustment,
signed, in 1/10000 of the width of an eye; `hfov` the horizontal field of view. The probe gives `MultiviewInfo` only
when `stri` has both eyes and no reserved bit set, as Media3 1.10 does. A plain HEVC decoder plays the base layer, one
eye.

### Tracks and decoder needs

The same walk lists every track (up to 16): track ID (`tkhd`), handler type and name (`hdlr`, QuickTime counted strings
included), first sample entry, coded size, frame rate (`stts`), duration (`mdhd`), bit depth (`hvcC`, `av1C`, `vpcC`,
`avcC`), colour (`colr` nclx or nclc: primaries, transfer, so HLG and PQ), the RFC 6381 codecs string
(`hvc1.2.4.L153`, `avc1.640033`, `av01.0.13M.10`, `dvh1.08.06`) and bit rates. Raw 360° videos hold one lens per
video track (Insta360 X4 and later, DJI Osmo 360) or six cube faces in two tracks (GoPro): `SphericalProbe.videoTracks`
lists them in moov order. The Insta360 X4 writes an `hvcC` whose profile, tier and level bytes are zeros; the probe
then reads the profile_tier_level of the SPS carried in the `hvcC`.

## What is known, and what is guessed

| Point | Status |
|---|---|
| st3d, sv3d with equi, V1 XML | read on an equirectangular export of Insta360 Studio and on files whose metadata exiftool wrote |
| mshp, cbmp | from the specification, tested on synthetic files only |
| MV-HEVC vexu | from Apple's specification of the HEVC stereo video format (v1.0), tested on synthetic files |
| Half sphere from equi bounds between 0.4 and 0.6 | a rule of this package: VR180 files crop 0.25 on each side |
| Stereo modes 3 (custom) and 4 (right and left) | not mapped: the probe gives no layout for them |

## Inspect a file

```sh
# ffprobe shows the projection and the stereo mode as side data of the stream
ffprobe -v error -show_entries stream=index:stream_side_data -of json clip.mp4

# exiftool shows the V1 XML and the V2 boxes
exiftool -a -G1 -XMP-GSpherical:all -Stereoscopic3D -ProjectionBounds* clip.mp4

# What this package reads
dart run example/inspect.dart clip.mp4
```

To play such a file with a 360° view, mpv360 adds an interactive projection to mpv.

## References

- Spherical Video V1 and V2 RFCs, and the Spatial Media Metadata Injector. https://github.com/google/spatial-media
- VR180 Video Format. https://github.com/google/spatial-media/blob/master/docs/vr180.md
- Apple, the HEVC stereo video format for ISO base media files, on the AV Foundation page. https://developer.apple.com/av-foundation/
- mpv360 (MIT): interactive 360° view for mpv. https://github.com/kasper93/mpv360
- ExifTool, QuickTime and XMP GSpherical tags. https://exiftool.org/TagNames/QuickTime.html
