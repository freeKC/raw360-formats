import 'package:raw360_formats/raw360_formats.dart';
import 'package:test/test.dart';

import 'fixtures/readers.dart';
import 'fixtures/xmp.dart';

void main() {
  group('parseGPanoProjectionType', () {
    test('reads the projection in both tag styles', () {
      expect(parseGPanoProjectionType(cameraXmp()), 'equirectangular');
      expect(parseGPanoProjectionType('<GPano:ProjectionType>cylindrical</GPano:ProjectionType>'), 'cylindrical');
      expect(parseGPanoProjectionType("GPano:ProjectionType = 'EQUIRECTANGULAR'"), 'EQUIRECTANGULAR');
    });

    test('is null without the tag', () {
      expect(parseGPanoProjectionType(''), isNull);
      expect(parseGPanoProjectionType('GPano:UsePanoramaViewer="True" ProjectionType="equirectangular"'), isNull);
    });
  });

  group('parseGPanoCrop', () {
    test('parses the crop in both tag styles', () {
      // Element style, as exiftool writes it when it copies the tags into another file
      const elements = '''
  <GPano:CroppedAreaImageHeightPixels>1667</GPano:CroppedAreaImageHeightPixels>
  <GPano:CroppedAreaImageWidthPixels>4460</GPano:CroppedAreaImageWidthPixels>
  <GPano:CroppedAreaLeftPixels>0</GPano:CroppedAreaLeftPixels>
  <GPano:CroppedAreaTopPixels>2035</GPano:CroppedAreaTopPixels>
  <GPano:FullPanoHeightPixels>4601</GPano:FullPanoHeightPixels>
  <GPano:FullPanoWidthPixels>9202</GPano:FullPanoWidthPixels>''';
      // Attribute style, as cameras write it into originals
      const attributes =
          '<rdf:Description GPano:CroppedAreaLeftPixels="0" GPano:CroppedAreaTopPixels="2035" '
          'GPano:CroppedAreaImageWidthPixels="4460" GPano:CroppedAreaImageHeightPixels="1667" '
          'GPano:FullPanoWidthPixels="9202" GPano:FullPanoHeightPixels="4601"/>';
      const expected = NormalizedRect.fromLTWH(0, 2035 / 4601, 4460 / 9202, 1667 / 4601);

      expect(parseGPanoCrop(elements), expected);
      expect(parseGPanoCrop(attributes), expected);
      expect(parseGPanoCrop('no GPano tags'), isNull);
    });

    test('is null for a full panorama of no size', () {
      expect(
        parseGPanoCrop(
          'GPano:FullPanoWidthPixels="0" GPano:FullPanoHeightPixels="0" GPano:CroppedAreaLeftPixels="0" '
          'GPano:CroppedAreaTopPixels="0" GPano:CroppedAreaImageWidthPixels="10" GPano:CroppedAreaImageHeightPixels="5"',
        ),
        isNull,
      );
    });
  });

  group('parseGPanoInitialView', () {
    test('reads the heading and pitch in both tag styles', () {
      const elements = '''
  <GPano:InitialViewHeadingDegrees>90</GPano:InitialViewHeadingDegrees>
  <GPano:InitialViewPitchDegrees>12.5</GPano:InitialViewPitchDegrees>''';
      const attributes = '<rdf:Description GPano:InitialViewHeadingDegrees="90" GPano:InitialViewPitchDegrees="12.5"/>';
      const expected = (heading: 90.0, pitch: 12.5, poseHeading: 0.0);

      expect(parseGPanoInitialView(elements), expected);
      expect(parseGPanoInitialView(attributes), expected);
      // Single quotes and spaces around the equal sign are valid XML too
      expect(
        parseGPanoInitialView("GPano:InitialViewHeadingDegrees = '90' GPano:InitialViewPitchDegrees='12.5'"),
        expected,
      );
    });

    test('reads negative and decimal values', () {
      const xmp =
          '<GPano:InitialViewHeadingDegrees>-45.25</GPano:InitialViewHeadingDegrees>'
          '<GPano:InitialViewPitchDegrees>-.5</GPano:InitialViewPitchDegrees>'
          '<GPano:PoseHeadingDegrees>+12.75</GPano:PoseHeadingDegrees>';

      expect(parseGPanoInitialView(xmp), (heading: -45.25, pitch: -0.5, poseHeading: 12.75));
    });

    test('reads the pose heading, 0 when missing', () {
      const withPose =
          'GPano:PoseHeadingDegrees="237.5" GPano:InitialViewHeadingDegrees="10" GPano:InitialViewPitchDegrees="0"';

      expect(parseGPanoInitialView(withPose)?.poseHeading, 237.5);
      expect(
        parseGPanoInitialView('GPano:InitialViewHeadingDegrees="10" GPano:InitialViewPitchDegrees="0"')?.poseHeading,
        0,
      );
    });

    test('needs both the heading and the pitch, like Photo Sphere Viewer', () {
      expect(parseGPanoInitialView('GPano:InitialViewHeadingDegrees="90"'), isNull);
      expect(parseGPanoInitialView('<GPano:InitialViewPitchDegrees>10</GPano:InitialViewPitchDegrees>'), isNull);
      expect(parseGPanoInitialView('GPano:InitialViewHeadingDegrees="" GPano:InitialViewPitchDegrees="10"'), isNull);
      expect(parseGPanoInitialView('no GPano tags'), isNull);
    });

    test('does not mistake other tags for the initial view', () {
      const xmp =
          'GPano:InitialViewRollDegrees="5" GPano:InitialHorizontalFOVDegrees="75" '
          'GPano:PosePitchDegrees="3" GPano:PoseHeadingDegrees="20"';

      expect(parseGPanoInitialView(xmp), isNull);
    });
  });

  group('initialViewDirection', () {
    // The longitude of a column of the full panorama, u in [0, 1]
    double longitudeOfColumn(double u) => 360 * (u - 0.5);

    ({double longitude, double latitude}) direction(double heading, {double pitch = 0, double poseHeading = 0}) =>
        initialViewDirection((heading: heading, pitch: pitch, poseHeading: poseHeading));

    test('heading 0 looks at the centre column of the full panorama', () {
      expect(direction(0).longitude, longitudeOfColumn(0.5));
    });

    test('headings grow clockwise, to the right in the image', () {
      expect(direction(90).longitude, longitudeOfColumn(0.75));
      expect(direction(-90).longitude, longitudeOfColumn(0.25));
      // Wraps around to the same side
      expect(direction(270).longitude, longitudeOfColumn(0.25));
      expect(direction(450).longitude, longitudeOfColumn(0.75));
      expect(direction(-45.5).longitude, closeTo(-45.5, 1e-9));
    });

    test('headings are compass headings, relative to the pose heading of the image centre', () {
      expect(direction(237.5, poseHeading: 237.5).longitude, 0);
      expect(direction(10, poseHeading: 350).longitude, closeTo(20, 1e-9));
      expect(direction(350, poseHeading: 10).longitude, closeTo(-20, 1e-9));
    });

    test('pitch is the latitude, positive upwards, clamped to the poles', () {
      expect(direction(0, pitch: 30).latitude, 30);
      expect(direction(0, pitch: -12.5).latitude, -12.5);
      expect(direction(0, pitch: 120).latitude, 90);
      expect(direction(0, pitch: -120).latitude, -90);
    });
  });

  group('readGPanoTags', () {
    test('finds the tags at the head of the file with one read', () async {
      final reads = <int>[];
      final bytes = photoWithXmp(cameraXmp(crop: halfSphereCropTags), length: 300000);

      final tags = await readGPanoTags(bytesReader(bytes, reads), bytes.length);

      expect(tags?.projectionType, 'equirectangular');
      expect(tags?.crop, const NormalizedRect.fromLTWH(0.25, 0, 0.5, 1));
      expect(tags == null ? null : isHalfSphereGPano(tags), isTrue);
      expect(reads, [0]);
    });

    test('falls back to the tail of the file', () async {
      final reads = <int>[];
      final bytes = photoWithXmp(cameraXmp(), xmpOffset: 290000, length: 300000);

      final tags = await readGPanoTags(bytesReader(bytes, reads), bytes.length);

      expect(tags?.projectionType, 'equirectangular');
      expect(tags == null ? null : isHalfSphereGPano(tags), isNull, reason: 'no crop');
      expect(reads, [0, 300000 - gpanoWindowLength]);
    });

    test('reads a small file once, and is null without GPano tags', () async {
      final reads = <int>[];
      final bytes = photoWithXmp('<x:xmpmeta>nothing here</x:xmpmeta>');

      expect(await readGPanoTags(bytesReader(bytes, reads), bytes.length), isNull);
      expect(reads, [0]);
    });
  });
}
