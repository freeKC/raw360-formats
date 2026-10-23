## Unreleased

Notes only, no change to the API. Which video track holds which lens on the Insta360 X4 and X5, checked at the seam on
real files ([issue 1](https://github.com/freeKC/raw360-formats/issues/1)): field 80 = 1, and field 131 = 4 on the X5,
mean that track 0 holds lens 1, the second lens of the calibration strings, as `insta360TrackOrder` already read them.
The values of fields 26, 79, 129 and 131 seen on X4 and X5 files, and the radial scale of the X5 lens guards.

## 0.1.0

First version: readers of the Insta360 trailer, the DJI Osmo 360 camd box, the GoPro .360 EAC tracks, the spherical
and stereo metadata of MP4 files and HEIC photos, the GPano XMP of photos, the rules for photos stitched in the camera,
the stereo layout and the half sphere, and the reference stitching math.
