// The GPano XMP of panoramas (Google's Photo Sphere XMP metadata, https://developers.google.com/streetview/spherical-
// metadata): the projection type, the crop of the image within the full panorama and the view to open on. Cameras
// and stitchers write the tags as attributes (GPano:ProjectionType="equirectangular"), some tools as elements
// (<GPano:ProjectionType>equirectangular</GPano:ProjectionType>); both are read. The XMP packet sits at the head of a
// JPEG (an APP1 segment) and may sit at the tail of other files (a WebP for example), so the head and the tail of a
// file are searched, without parsing the XML.
//
// Pure Dart: the caller reads the bytes, from a file or with HTTP range requests.

import 'normalized_rect.dart';
import 'spherical_probe.dart' show ByteRangeReader;

/// Length of the windows at the head and at the tail of a file where the GPano XMP is looked for
const gpanoWindowLength = 131072;

/// The view a panorama asks to open on, in degrees. Headings are compass headings: the centre of the image points
/// to [poseHeading], 0 when the file does not say. Pitch is positive upwards.
typedef GPanoInitialView = ({double heading, double pitch, double poseHeading});

/// The GPano tags of a file: its [projectionType] as written (see [isEquirectangularGPano]), the part of the full
/// sphere the image covers ([crop], normalised to [0, 1], null without the six crop tags; see [isPartialSphere] for
/// crops that cover the whole sphere) and the [initialView]
typedef GPanoTags = ({String? projectionType, NormalizedRect? crop, GPanoInitialView? initialView});

// Value of a numeric GPano tag, written as an attribute (GPano:Name="1.5") or as an element (<GPano:Name>1.5</...>)
double? _gpanoTag(String xmp, String name) {
  final match = RegExp(
    'GPano:$name'
    r'''(?:\s*=\s*["']|>)\s*([-+]?(?:\d+\.?\d*|\.\d+))''',
  ).firstMatch(xmp);
  return match == null ? null : double.tryParse(match.group(1)!);
}

/// The GPano crop of [xmp]: which part of the full sphere the image covers, normalised to [0, 1], from
/// CroppedAreaLeftPixels, CroppedAreaTopPixels, CroppedAreaImageWidthPixels and CroppedAreaImageHeightPixels over
/// FullPanoWidthPixels and FullPanoHeightPixels; null unless all six are there
NormalizedRect? parseGPanoCrop(String xmp) {
  double? tag(String name) => _gpanoTag(xmp, name);
  final fullWidth = tag('FullPanoWidthPixels');
  final fullHeight = tag('FullPanoHeightPixels');
  final left = tag('CroppedAreaLeftPixels');
  final top = tag('CroppedAreaTopPixels');
  final width = tag('CroppedAreaImageWidthPixels');
  final height = tag('CroppedAreaImageHeightPixels');
  if (fullWidth == null || fullHeight == null || left == null || top == null || width == null || height == null) {
    return null;
  }
  if (fullWidth <= 0 || fullHeight <= 0) {
    return null;
  }
  return NormalizedRect.fromLTWH(left / fullWidth, top / fullHeight, width / fullWidth, height / fullHeight);
}

/// The initial view of [xmp], from InitialViewHeadingDegrees, InitialViewPitchDegrees and PoseHeadingDegrees; null
/// unless both the heading and the pitch are set, as Photo Sphere Viewer reads them
GPanoInitialView? parseGPanoInitialView(String xmp) {
  final heading = _gpanoTag(xmp, 'InitialViewHeadingDegrees');
  final pitch = _gpanoTag(xmp, 'InitialViewPitchDegrees');
  if (heading == null || pitch == null) {
    return null;
  }
  return (heading: heading, pitch: pitch, poseHeading: _gpanoTag(xmp, 'PoseHeadingDegrees') ?? 0);
}

/// The GPano projection of [xmp], as written: "equirectangular" for a 360° panorama, "cylindrical" for a flat one
String? parseGPanoProjectionType(String xmp) =>
    RegExp(r'''GPano:ProjectionType(?:\s*=\s*["']|>)\s*([A-Za-z_-]+)''').firstMatch(xmp)?.group(1);

/// Whether [tags] declare a 360° panorama: an equirectangular projection, in any case
bool isEquirectangularGPano(GPanoTags tags) => tags.projectionType?.toLowerCase() == 'equirectangular';

/// Whether the GPano crop of [tags] is the one of a VR180 photo: about half the width of the full panorama (0.45 to
/// 0.55) and all of its height (more than 0.9); null without a crop
bool? isHalfSphereGPano(GPanoTags tags) {
  final crop = tags.crop;
  return crop == null ? null : crop.width >= 0.45 && crop.width <= 0.55 && crop.height > 0.9;
}

/// The GPano tags of the text [xmp] (any text that holds an XMP packet, the bytes of a file read as Latin-1 for
/// example); null when it has none of the projection type, the six crop tags and the initial view
GPanoTags? parseGPanoTags(String xmp) {
  final projectionType = parseGPanoProjectionType(xmp);
  final crop = parseGPanoCrop(xmp);
  final initialView = parseGPanoInitialView(xmp);
  if (projectionType == null && crop == null && initialView == null) {
    return null;
  }
  return (projectionType: projectionType, crop: crop, initialView: initialView);
}

/// Reads the GPano tags of a file [length] bytes long through [read]: the first [gpanoWindowLength] bytes, where JPEG
/// files carry their XMP, else the last ones. Null when neither holds GPano tags. Errors of [read] are not caught.
Future<GPanoTags?> readGPanoTags(ByteRangeReader read, int length) async {
  for (final offset in {0, if (length > gpanoWindowLength) length - gpanoWindowLength}) {
    final tags = parseGPanoTags(String.fromCharCodes(await read(offset, gpanoWindowLength)));
    if (tags != null) {
      return tags;
    }
  }
  return null;
}

/// Where a viewer looks first for a GPano initial view, as its longitude and latitude in degrees.
///
/// The longitude is 0 at the centre column of the full panorama and grows to the right, and the centre of the image
/// points to the pose heading: the longitude is how far clockwise the initial heading is from it. Photo Sphere
/// Viewer does the same by turning the sphere by the pose heading.
({double longitude, double latitude}) initialViewDirection(GPanoInitialView view) =>
    (longitude: (view.heading - view.poseHeading + 180) % 360 - 180, latitude: view.pitch.clamp(-90.0, 90.0));
