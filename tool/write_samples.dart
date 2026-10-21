// Writes small synthetic files built by the test fixtures, so that the commands of docs/ can be tried without a
// camera: dart run tool/write_samples.dart [directory]
//
// They hold the boxes, the trailers and the metadata of the real formats, but no picture: the video tracks have no
// samples and the photo has no image data. exiftool and example/inspect.dart read them; ffprobe, ffmpeg and players
// need real files.

import 'dart:io';
import 'dart:typed_data';

import '../test/fixtures/dji_osv.stub.dart';
import '../test/fixtures/gopro.stub.dart';
import '../test/fixtures/heif_builder.dart';
import '../test/fixtures/insta360.stub.dart';
import '../test/fixtures/mp4_builder.dart';

void main(List<String> arguments) {
  final directory = Directory(arguments.isEmpty ? 'samples' : arguments.first)..createSync(recursive: true);
  void write(String name, List<int> bytes) {
    File('${directory.path}/$name').writeAsBytesSync(bytes);
    print('${directory.path}/$name (${bytes.length} bytes)');
  }

  // An Insta360 X3 photo: EXIF head, then the trailer with its metadata and a few raw IMU samples
  write(
    'IMG_20250101_120000_00_001.insp',
    insta360File([
      insta360Record(3, rawImuSamples([(32768 - 1024, 32768, 32768 + 64)]), format: 0),
      insta360Record(1, x3Metadata(), format: 1),
    ], body: insta360PhotoHead()),
  );
  // An Insta360 X5 style video whose two lenses are two video tracks, with an indexed trailer in an inst box
  write(
    'VID_20250101_120000_00_002.insv',
    mp4File(
      mp4Moov([
        mp4VideoTrack([], width: 3840, height: 3840, trackId: 1, handlerType: 'vide', handlerName: 'Lens 0'),
        mp4VideoTrack([], width: 3840, height: 3840, trackId: 2, handlerType: 'vide', handlerName: 'Lens 1'),
      ]),
      trailing: insta360IndexedTail(metadata: x5Metadata()),
    ),
  );
  // A DJI Osmo 360 video: two square HEVC tracks, metadata tracks, then the camd box with the calibration
  write('CAM_20250101120000_0001_D.OSV', djiOsvFile());
  // A GoPro MAX video: two EAC tracks of 4096 x 1344
  write('GS010001.360', goProFile());
  // A VR180 video: side by side eyes, an equirectangular projection cropped to the front half
  write(
    'clip_vr180.mp4',
    mp4File(
      mp4Moov([
        mp4VideoTrack(
          [mp4St3d(2), mp4Sv3dEquirectangular(left: 0.25, right: 0.25)],
          width: 5760,
          height: 2880,
          trackId: 1,
          handlerType: 'vide',
        ),
      ]),
    ),
  );
  // An Apple style spatial photo: a HEIF whose two images make a stereo pair
  write('spatial.heic', spatialPhotoBuilder().build());
  // A photo with GPano XMP: an equirectangular panorama covering the front half of the sphere
  write(
    'pano_vr180.jpg',
    Uint8List.fromList([
      0xff, 0xd8, //
      0xff, 0xe1, ..._u16(2 + _xmp.length), ..._xmp,
      0xff, 0xd9,
    ]),
  );
}

List<int> _u16(int value) => [value >> 8 & 0xff, value & 0xff];

final _xmp = [
  ...'http://ns.adobe.com/xap/1.0/\u0000'.codeUnits,
  ...('<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">'
          '<rdf:Description rdf:about="" xmlns:GPano="http://ns.google.com/photos/1.0/panorama/" '
          'GPano:ProjectionType="equirectangular" GPano:FullPanoWidthPixels="8000" GPano:FullPanoHeightPixels="4000" '
          'GPano:CroppedAreaLeftPixels="2000" GPano:CroppedAreaTopPixels="0" GPano:CroppedAreaImageWidthPixels="4000" '
          'GPano:CroppedAreaImageHeightPixels="4000"/></rdf:RDF></x:xmpmeta>')
      .codeUnits,
];
