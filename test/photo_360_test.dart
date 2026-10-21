import 'dart:typed_data';

import 'package:raw360_formats/raw360_formats.dart';
import 'package:test/test.dart';

import 'fixtures/insta360.stub.dart';
import 'fixtures/readers.dart';
import 'fixtures/xmp.dart';

// A crop over the whole sphere, as many cameras write on full spheres
const _fullSphereCropTags =
    'GPano:FullPanoWidthPixels="8000" GPano:FullPanoHeightPixels="4000" GPano:CroppedAreaLeftPixels="0" '
    'GPano:CroppedAreaTopPixels="0" GPano:CroppedAreaImageWidthPixels="8000" GPano:CroppedAreaImageHeightPixels="4000"';

void main() {
  group('isPanoramaCandidate', () {
    test('takes 2:1 frames within 2 percent', () {
      expect(isPanoramaCandidate(name: 'a.jpg', width: 5760, height: 2880), isTrue);
      expect(isPanoramaCandidate(name: 'b.jpg', width: 4000, height: 1961), isTrue, reason: '2.04:1');
      expect(isPanoramaCandidate(name: 'c.mp4', width: 3840, height: 1920), isTrue);
      expect(isPanoramaCandidate(name: 'd.jpg', width: 4000, height: 3000), isFalse);
      expect(isPanoramaCandidate(name: 'e.jpg', width: 2400, height: 1080), isFalse, reason: '2.22:1');
      expect(isPanoramaCandidate(name: 'f.jpg', width: 1080, height: 2160), isFalse, reason: '1:2, no 3D name');
    });

    test('takes the names that say 360°, whatever the frame', () {
      for (final name in [
        'trip_360.jpg',
        '360_0001.JPG',
        'GS010001.360',
        'PANO_20240101.jpg',
        'PXL_20240101_PANO.jpg',
        'beach panorama.jpg',
        'IMG_VR180.jpg',
        'IMG_20240101_120000_00_001.insp',
        'VID_20240101_120000_00_001.INSV',
        'CAM_20250101120000_0001_D.OSV',
        'GS__0001.36P',
      ]) {
        expect(isPanoramaCandidate(name: name, width: 4000, height: 3000), isTrue, reason: name);
      }
    });

    test('does not take 360 within a longer number', () {
      for (final name in ['IMG_1360.JPG', '20240613_103600.jpg', 'IMG_3601.jpg']) {
        expect(isPanoramaCandidate(name: name, width: 4000, height: 3000), isFalse, reason: name);
      }
    });

    test('takes square and 1:2 frames only with a 3D or VR180 name', () {
      expect(isPanoramaCandidate(name: 'trip_3D.jpg', width: 4000, height: 4000), isTrue);
      expect(isPanoramaCandidate(name: 'trip-180x180.mp4', width: 2000, height: 4000), isTrue);
      expect(isPanoramaCandidate(name: 'IMG_3D41.JPG', width: 4000, height: 4000), isFalse);
      expect(isPanoramaCandidate(name: 'IMG_0001.JPG', width: 4000, height: 4000), isFalse);
      expect(isPanoramaCandidate(name: 'trip_3D.jpg', width: 4000, height: 3000), isFalse);
    });

    test('needs the dimensions when the name does not tell', () {
      expect(isPanoramaCandidate(name: 'a.jpg'), isFalse);
      expect(isPanoramaCandidate(name: 'b.jpg', width: 4000, height: 0), isFalse);
    });
  });

  group('probe360Photo', () {
    Future<Photo360Probe> probe(Uint8List bytes) => probe360Photo(bytesReader(bytes), bytes.length);

    test('takes an equirectangular projection for 360°, in any case', () async {
      expect(await probe(photoWithXmp(cameraXmp())), (isPanorama: true, halfSphere: null, raw360: false));
      expect(await probe(photoWithXmp(cameraXmp(projection: 'Equirectangular'))), (
        isPanorama: true,
        halfSphere: null,
        raw360: false,
      ));
    });

    test('tells the half sphere from the crop', () async {
      expect(await probe(photoWithXmp(cameraXmp(crop: halfSphereCropTags))), (
        isPanorama: true,
        halfSphere: true,
        raw360: false,
      ));
      expect(await probe(photoWithXmp(cameraXmp(crop: _fullSphereCropTags))), (
        isPanorama: true,
        halfSphere: false,
        raw360: false,
      ));
    });

    test('takes other projections, and no GPano tags, for no 360°', () async {
      expect(await probe(photoWithXmp(cameraXmp(projection: 'cylindrical'))), (
        isPanorama: false,
        halfSphere: null,
        raw360: false,
      ));
      expect(await probe(photoWithXmp('<GPano:CroppedAreaLeftPixels>0</GPano:CroppedAreaLeftPixels>')), (
        isPanorama: false,
        halfSphere: null,
        raw360: false,
      ));
      expect(await probe(photoWithXmp('')), (isPanorama: false, halfSphere: null, raw360: false));
    });

    test('takes a photo that ends with the trailer of an Insta360 camera for a raw dual fisheye one', () async {
      final raw = insta360File([insta360Record(1, x3Metadata(), format: 1)], body: photoWithXmp('', length: 200000));

      expect(await probe(raw), (isPanorama: true, halfSphere: null, raw360: true));
    });

    test('takes a photo whose trailer says the camera stitched it for an equirect one, unless named .insp', () async {
      // Field 129 of the metadata: 6 an equirect picture stitched in the camera, 2 a double fisheye
      Uint8List photo(int? imageCategory) => insta360File([
        insta360Record(1, x5Metadata(imageCategory: imageCategory), format: 1),
      ], body: photoWithXmp('', length: 200000));
      Future<Photo360Probe> read(Uint8List bytes, String name) =>
          probe360Photo(bytesReader(bytes), bytes.length, name: name);

      expect(await read(photo(6), 'IMG_20240101_120000_00_001.jpg'), (
        isPanorama: true,
        halfSphere: false,
        raw360: false,
      ));
      expect(await read(photo(2), 'IMG_20240101_120000_00_001.jpg'), (
        isPanorama: true,
        halfSphere: null,
        raw360: true,
      ));
      expect(await read(photo(null), 'IMG.jpg'), (isPanorama: true, halfSphere: null, raw360: true));
      expect(await read(photo(6), 'IMG_20240101_120000_00_001.insp'), (
        isPanorama: true,
        halfSphere: null,
        raw360: true,
      ));
    });

    test('takes a 2:1 photo of a 360° camera without GPano tags for a 360° one, by its EXIF and its size', () async {
      // The fixture writes every text out of its EXIF entry: a make of more than 3 letters ("DJI" fits in the entry)
      Uint8List photo(String make, String model, {int? width, int? height}) =>
          Uint8List.fromList([...insta360PhotoHead(make: make, model: model, pixelWidth: width, pixelHeight: height)]);
      const equirect = (isPanorama: true, halfSphere: false, raw360: false);
      const flat = (isPanorama: false, halfSphere: null, raw360: false);
      Future<Photo360Probe> read(Uint8List bytes, {int? width, int? height}) =>
          probe360Photo(bytesReader(bytes), bytes.length, name: 'DJI_0001.JPG', width: width, height: height);

      expect(await read(photo('DJI Ltd', 'Osmo 360', width: 15520, height: 7760)), equirect);
      expect(await read(photo('GoPro', 'GoPro Max'), width: 5760, height: 2880), equirect, reason: 'the size given');
      expect(await read(photo('DJI Ltd', 'Osmo 360', width: 6400, height: 4800)), flat, reason: 'a single lens');
      expect(await read(photo('Apple', 'iPhone 15', width: 8000, height: 4000)), flat, reason: 'no 360° camera');
      expect(await read(photo('GoPro', 'GoPro Max')), flat, reason: 'no size known');
    });
  });
}
