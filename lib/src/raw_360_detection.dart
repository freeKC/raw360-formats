// Which files are the raw files of a 360° camera, which a viewer has to stitch itself: Insta360 .insp photos (a JPEG
// with both fisheye circles side by side) and .insv videos (both lenses side by side, one per video track, or one per
// file of a split pair), GoPro .360 videos (six cube faces in two video tracks) and DJI .osv videos (one lens per video
// track). The name tells, or for a photo the trailer the camera writes at the end of the file (see
// readInsta360Trailer). How a video holds its lenses is settled once it is opened, from the tracks its probe lists. See
// docs/insta360.md, docs/gopro-360.md and docs/dji-osv.md.
//
// It also tells the equirect photos a 360° camera stitched itself (GoPro .36P, DJI and GoPro JPEGs without GPano
// tags), which are no raw files: an equirect viewer shows them as they are. See docs/camera-equirect-photos.md.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'exif_head.dart';
import 'gpano.dart';
import 'insta360_trailer.dart';
import 'sphere_coverage.dart';
import 'spherical_probe.dart';
import 'stereo_layout.dart';

/// A raw 360° file a viewer stitches itself, as its name (or, for a photo, its trailer) tells; the layout of a video
/// is settled once it is opened, from its tracks
enum RawMediaKind { insta360Photo, insta360Video, goProVideo, djiVideo }

final _rawPhotoName = RegExp(r'\.insp$', caseSensitive: false);
final _insta360VideoName = RegExp(r'\.insv$', caseSensitive: false);
final _goProVideoName = RegExp(r'\.360$', caseSensitive: false);
final _djiVideoName = RegExp(r'\.osv$', caseSensitive: false);
final _cameraEquirectPhotoName = RegExp(r'\.36p$', caseSensitive: false);

/// What raw 360° file the file named [name] is, by its last extension, case aside: a photo named .insp is an Insta360
/// photo; a video named .insv an Insta360 video, .360 a GoPro one, .osv a DJI one. Null for anything else: the .lrv and
/// .lrf proxies, the equirect .36p photos of the GoPro MAX 2, a name that does not match [isVideo].
RawMediaKind? rawMediaKindOfName(String name, {required bool isVideo}) {
  if (!isVideo) {
    return isRawPhotoName(name) ? RawMediaKind.insta360Photo : null;
  }
  if (_insta360VideoName.hasMatch(name)) {
    return RawMediaKind.insta360Video;
  }
  if (_goProVideoName.hasMatch(name)) {
    return RawMediaKind.goProVideo;
  }
  if (_djiVideoName.hasMatch(name)) {
    return RawMediaKind.djiVideo;
  }
  return null;
}

/// Whether [name] is the name of a raw Insta360 photo (.insp)
bool isRawPhotoName(String name) => _rawPhotoName.hasMatch(name);

/// Whether [name] is the name of a raw 360° video: Insta360 .insv, GoPro .360, DJI .osv
bool isRawVideoName(String name) => rawMediaKindOfName(name, isVideo: true) != null;

/// Whether [name] is the name of a raw file of a 360° camera: Insta360 .insp and .insv, GoPro .360, DJI .osv
bool isRaw360FileName(String name) => isRawPhotoName(name) || isRawVideoName(name);

/// Whether a frame of [width] x [height] pixels holds two squares side by side (within 1 percent); null when its size
/// is unknown
bool? isSideBySideFrame(int? width, int? height) {
  if (width == null || height == null || width <= 0 || height <= 0) {
    return null;
  }
  return (width / height / 2 - 1).abs() <= 0.01;
}

// A file of a split Insta360 recording: _00_ holds lens 0, _10_ lens 1, before the index of the recording and its
// extension (a copy may have a suffix such as "(1)" before it). The LRV proxies are _01_ and _11_ .lrv files.
final _splitLensName = RegExp(r'^(.*_)([01])0(_\d+[^.]*\.insv)$', caseSensitive: false);

/// The lens of a split recording file by its name (_00_ lens 0, _10_ lens 1) and the name of the other file of the
/// pair; null for any other name (the LRV proxies _01_ and _11_ are .lrv files and never match).
/// VID_20250101_120000_00_001.insv gives (lens: 0, siblingName: VID_20250101_120000_10_001.insv), and the inverse; the
/// case of the rest of the name is kept.
({int lens, String siblingName})? splitPairOf(String name) {
  final match = _splitLensName.firstMatch(name);
  if (match == null) {
    return null;
  }
  final lens = int.parse(match.group(2)!);
  return (lens: lens, siblingName: '${match.group(1)}${1 - lens}0${match.group(3)}');
}

/// Why the file found under the sibling name of [splitPairOf] is not the other lens of the recording whose file was
/// probed as [probe], null when it is: the sibling ([siblingProbe]) lists a video track; the first video tracks of both
/// files have the same coded size and the same codec; their durations differ by at most 1 second or 1 percent when
/// both are known; and both trailers name the same recording (field 26.3, [groupIdentity] and [siblingGroupIdentity])
/// when both name one. A sibling that does not fit is best taken for a missing one, with this reason in the logs.
String? splitSiblingMismatch({
  required SphericalProbe? probe,
  required SphericalProbe? siblingProbe,
  String? groupIdentity,
  String? siblingGroupIdentity,
}) {
  final sibling = siblingProbe?.videoTracks.firstOrNull;
  if (sibling == null) {
    return 'the sibling has no video track';
  }
  final opened = probe?.videoTracks.firstOrNull;
  if (opened != null) {
    if (opened.codedWidth != sibling.codedWidth || opened.codedHeight != sibling.codedHeight) {
      return 'frames of ${opened.codedWidth} x ${opened.codedHeight} and ${sibling.codedWidth} x '
          '${sibling.codedHeight}';
    }
    if (opened.codec != sibling.codec) {
      return 'codecs ${opened.codec} and ${sibling.codec}';
    }
    final duration = opened.durationMs;
    final siblingDuration = sibling.durationMs;
    if (duration != null && siblingDuration != null) {
      final tolerance = math.max(1000, (0.01 * math.max(duration, siblingDuration)).round());
      if ((duration - siblingDuration).abs() > tolerance) {
        return 'durations of $duration and $siblingDuration ms';
      }
    }
  }
  if (groupIdentity != null && siblingGroupIdentity != null && groupIdentity != siblingGroupIdentity) {
    return 'recordings $groupIdentity and $siblingGroupIdentity';
  }
  return null;
}

/// The name of the first lens file (_00_) of a split Insta360 recording when [name] is its second lens file (_10_),
/// null for any other name. "VID_20250101_120000_10_001.insv" gives "VID_20250101_120000_00_001.insv".
String? splitFirstLensName(String name) {
  final pair = splitPairOf(name);
  return pair != null && pair.lens == 1 ? pair.siblingName : null;
}

/// Whether the photo named [name] is an equirect JPEG a 360° camera stitched itself: named .36p (GoPro MAX 2), or of
/// 2:1 within 1 percent ([width] x [height]) from a known 360° camera, for a photo without GPano tags (the caller tests
/// those first): [make] contains "gopro" and [model] contains "max"; [make] contains "dji" and [model] contains "360"
/// or "oq"; [make] is "arashi vision" (Insta360 stitching in the camera). Case aside. Never true for a raw .insp,
/// whose trailer the caller tests first.
bool isEquirectCameraPhoto({required String name, String? make, String? model, int? width, int? height}) {
  if (isRawPhotoName(name)) {
    return false;
  }
  if (_cameraEquirectPhotoName.hasMatch(name)) {
    return true;
  }
  if (isSideBySideFrame(width, height) != true) {
    return false;
  }
  final maker = make?.trim().toLowerCase() ?? '';
  final camera = model?.trim().toLowerCase() ?? '';
  return (maker.contains('gopro') && camera.contains('max')) ||
      (maker.contains('dji') && (camera.contains('360') || camera.contains('oq'))) ||
      maker == 'arashi vision';
}

/// How a viewer shows a raw 360° media once stitched: one picture over the whole sphere. Its name or its 2:1 shape may
/// look like a 3D or VR180 media; the stitch is neither.
const SphereView raw360SphereView = (
  layout: StereoLayout.mono,
  coverage: SphereCoverage.full,
  coverageGuess: SphereCoverage.full,
);

// The fixed tail of a version 3 trailer: 32 reserved bytes, the size, the version, the magic
const _tailLength = 72;
const _versionOffset = 36;
const _magicOffset = 40;
const _trailerVersion = 3;

/// Whether the file of [fileSize] bytes that [read] reads ends with the trailer of an Insta360 camera (version 3):
/// reads its last 72 bytes only, so that a photo renamed from .insp is still found raw. Errors of [read] are not
/// caught.
Future<bool> hasInsta360Trailer(ByteRangeReader read, int fileSize) async {
  if (fileSize < _tailLength) {
    return false;
  }
  final tail = await read(fileSize - _tailLength, _tailLength);
  if (tail.length != _tailLength) {
    return false;
  }
  final magic = ascii.encode(insta360TrailerMagic);
  for (var i = 0; i < magic.length; i++) {
    if (tail[_magicOffset + i] != magic[i]) {
      return false;
    }
  }
  return ByteData.sublistView(tail).getUint32(_versionOffset, Endian.little) == _trailerVersion;
}

/// The image category (field 129 of the trailer, see [Insta360Trailer.imageCategory]) of a photo an Insta360 camera
/// stitched into an equirect picture itself
const insta360StitchedImageCategory = 6;

/// Whether the photo of [length] bytes that [read] reads, which ends with the trailer of an Insta360 camera (see
/// [hasInsta360Trailer]), is an equirect picture the camera stitched itself rather than its two fisheye circles: its
/// trailer says so (see [insta360StitchedImageCategory]). Meant for a photo found raw by its trailer only: a .insp is
/// raw whatever. Reads the metadata of the trailer, not its IMU samples. Errors of [read] are not caught.
Future<bool> isInsta360StitchedPhoto(ByteRangeReader read, int length) async =>
    (await readInsta360Trailer(read, length, maxImuLength: 0))?.imageCategory == insta360StitchedImageCategory;

/// What a photo declares about the sphere: whether it is a 360° picture ([isPanorama]), whether it covers the front
/// half only ([halfSphere], null when it does not say) and whether it is a raw dual fisheye photo to stitch ([raw360])
typedef Photo360Probe = ({bool isPanorama, bool? halfSphere, bool raw360});

const Photo360Probe _flatPhoto = (isPanorama: false, halfSphere: null, raw360: false);
const Photo360Probe _rawPhoto = (isPanorama: true, halfSphere: null, raw360: true);
// An equirect photo a 360° camera stitched itself: the whole sphere, as GoPro, DJI and Insta360 cameras stitch it
const Photo360Probe _cameraEquirectPhoto = (isPanorama: true, halfSphere: false, raw360: false);

/// Reads what the photo of [length] bytes named [name] declares about the sphere, through [read], in this order:
/// - its GPano XMP (see [readGPanoTags]): an equirectangular projection makes it 360°, half of a sphere when its crop
///   says so (see [isHalfSphereGPano]);
/// - else the trailer of an Insta360 camera at its end (see [hasInsta360Trailer]) makes it a raw dual fisheye photo,
///   a .insp renamed to be seen as a JPEG; unless it is named otherwise than .insp and its trailer says the camera
///   stitched it (see [isInsta360StitchedPhoto]), which makes it an equirect photo;
/// - else an EXIF that names a 360° camera with a 2:1 frame makes it an equirect photo the camera stitched itself (see
///   [isEquirectCameraPhoto]), its frame of [width] x [height] when the caller knows it, else the one its EXIF gives.
///
/// Errors of [read] are not caught.
Future<Photo360Probe> probe360Photo(
  ByteRangeReader read,
  int length, {
  String name = '',
  int? width,
  int? height,
}) async {
  final tags = await readGPanoTags(read, length);
  if (tags != null && isEquirectangularGPano(tags)) {
    return (isPanorama: true, halfSphere: isHalfSphereGPano(tags), raw360: false);
  }
  if (await hasInsta360Trailer(read, length)) {
    // Raw by its trailer only: one the camera stitched itself keeps the trailer, and is a 360° photo as it is
    return !isRawPhotoName(name) && await isInsta360StitchedPhoto(read, length) ? _cameraEquirectPhoto : _rawPhoto;
  }
  final exif = parseExifHead(await read(0, exifHeadLength));
  final isCameraEquirect = isEquirectCameraPhoto(
    name: name,
    make: exif?.make,
    model: exif?.model,
    width: width ?? exif?.pixelWidth,
    height: height ?? exif?.pixelHeight,
  );
  return isCameraEquirect ? _cameraEquirectPhoto : _flatPhoto;
}

// "360" on its own, not within a longer number ("IMG_1360.JPG", "20240613_103600.jpg"), "pano" ("PANO_0001.jpg",
// "PXL_20240101_PANO.jpg", "panorama"), "vr180", the raw files of 360° cameras (Insta360 .insp and .insv, GoPro .360,
// DJI .osv) and the equirect photos of the GoPro MAX 2 (.36p)
final _panoramaName = RegExp(r'(?<![0-9])360(?![0-9])|pano|vr180|\.(ins[pv]|osv|36p)$', caseSensitive: false);

// "3d" on its own ("trip_3D.jpg", but not "IMG_3D41.JPG") and the VR180 words: two eyes stacked or side by side
final _stereoName = RegExp(r'(?<![a-z0-9])3d(?![a-z0-9])|vr180|180x180', caseSensitive: false);

// Whether [ratio] is [target] within 2 percent
bool _isAbout(double ratio, double target) => (ratio / target - 1).abs() <= 0.02;

/// Whether a photo or a video named [name], of [width] x [height] pixels, may be 360°, so that its file is worth
/// reading (with [probe360Photo] or [probeSphericalMetadata]) when a gallery holds thousands of them: a 2:1 frame
/// (within 2 percent), the shape of an equirectangular image; a name that says so ("360" on its own, "pano", "vr180",
/// the raw files of 360° cameras, the .36p photos of the GoPro MAX 2); or a square or 1:2 frame, where two 360° or
/// VR180 eyes are stacked, with a name that says 3D or VR180.
bool isPanoramaCandidate({required String name, int? width, int? height}) {
  if (_panoramaName.hasMatch(name)) {
    return true;
  }
  if (width == null || height == null || width <= 0 || height <= 0) {
    return false;
  }
  final ratio = width / height;
  if (_isAbout(ratio, 2)) {
    return true;
  }
  return (_isAbout(ratio, 1) || _isAbout(ratio, 0.5)) && _stereoName.hasMatch(name);
}
