/// Readers for the raw files of 360° cameras (Insta360 .insp and .insv, GoPro .360, DJI Osmo 360 .osv) and for the
/// spherical and stereo metadata of photos and videos (GPano XMP, Spherical Video V1 and V2, VR180, Apple spatial
/// photos and videos), with the lens models and the reference math to stitch the raw files. Pure Dart: every reader
/// takes a [ByteRangeReader], so the bytes may come from a file, from memory or from HTTP range requests.
library;

export 'src/dji_osv.dart';
export 'src/dual_fisheye_calibration.dart';
export 'src/dual_fisheye_math.dart';
export 'src/exif_head.dart';
export 'src/gopro_eac.dart';
export 'src/gpano.dart';
export 'src/heic_stereo_probe.dart';
export 'src/insta360_trailer.dart';
export 'src/normalized_rect.dart';
export 'src/protobuf_reader.dart';
export 'src/raw_360_detection.dart';
export 'src/raw_sampler.dart';
export 'src/sphere_coverage.dart';
export 'src/spherical_probe.dart';
export 'src/stereo_layout.dart';
