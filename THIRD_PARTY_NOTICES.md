# Third party notices

raw360_formats is under the MIT licence (LICENSE). Parts of it follow the work of other projects, whose licences ask
that their notice travels with it.

## max2-reframe-resolve

lib/src/gopro_eac.dart: the face table of the GoPro EAC tracks and the formulas that sample them are ported from
`proto/eac.py` of https://github.com/Sean-McConnachie/max2-reframe-resolve (written in Python there, in Dart here, with
pixel centres at half pixels).

```
MIT License

Copyright (c) 2026 Sean McConnachie

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## OSVplat

lib/src/dual_fisheye_math.dart, `djiLensRotation`: the pose of a DJI Osmo 360 lens from its yaw, pitch and roll is ported
from `world_to_cam` in `scripts/osmo_fisheye.py` of https://github.com/pgodlews/OSVplat (without its final mirroring).
The layout of the camd records read in lib/src/dji_osv.dart follows its `docs/osmo360-telemetry.md` and
`scripts/osv_meta.py`.

```
MIT License

Copyright (c) 2026 Piotr Godlewski

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## GyroView

lib/src/dual_fisheye_math.dart, `lensPose`, `mirroredRoll`, `bodyFrame` and `downBodyFromAccelerometer`: the Insta360
lens pose convention, the forward direction of Insta360 Studio and the axes of the IMU follow what GyroView measured
and documented (`docs/FORMAT.md`, `docs/adr/`) at https://github.com/bubo-squared/GyroView.

```
MIT License

Copyright (c) 2026 Bubo²

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Facts taken from other projects, without code

- The protobuf field numbers of the Insta360 metadata come from telemetry-parser
  (https://github.com/AdrianEddy/telemetry-parser, MIT or Apache-2.0), and those of the newer cameras and the indexed
  trailer from insta360-rs (https://github.com/OpenSpeleo/insta360-rs, Apache-2.0) and GyroView. No code of those
  projects is in this package.
