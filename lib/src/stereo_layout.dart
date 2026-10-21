// Stereoscopic (3D) 360° media hold one equirectangular image per eye in a single frame. Without spherical metadata
// that says so (the st3d box of a video, see probeSphericalMetadata), nothing tells them apart from regular 360°
// media: a viewer guesses the layout from the frame dimensions, and lets the user change it.

import 'normalized_rect.dart';
import 'sphere_coverage.dart';

/// How the eyes of a stereoscopic media are laid out in its frame: one picture for both eyes, the left eye on top of
/// the right one, or the left eye to the left of the right one
enum StereoLayout { mono, topBottom, leftRight }

/// Guesses how the eyes of a 360° photo or video of [width] x [height] pixels are laid out.
///
/// Each eye of a full sphere is a 2:1 equirectangular image: stacked, they make a square frame (left eye on top),
/// side by side a 4:1 frame (left eye on the left). Each eye of a half sphere ([coverage], VR180 media) is a square
/// 180° image: stacked, they make a 1:2 frame, side by side a 2:1 frame. Within 10% of those. Anything else is mono, as
/// are unknown dimensions and partial panoramas, whose GPano crop ([hasGPanoCrop]) gives the image any aspect ratio.
StereoLayout guessStereoLayout({
  required int? width,
  required int? height,
  bool hasGPanoCrop = false,
  SphereCoverage coverage = SphereCoverage.full,
}) {
  if (hasGPanoCrop || width == null || height == null || width <= 0 || height <= 0) {
    return StereoLayout.mono;
  }
  final eyeAspectRatio = switch (coverage) {
    SphereCoverage.full => 2.0,
    SphereCoverage.half => 1.0,
  };
  bool near(double aspectRatio) => (width / height - aspectRatio).abs() <= aspectRatio * 0.1 + 1e-9;
  if (near(eyeAspectRatio / 2)) {
    return StereoLayout.topBottom;
  }
  if (near(eyeAspectRatio * 2)) {
    return StereoLayout.leftRight;
  }
  return StereoLayout.mono;
}

extension StereoLayoutExtension on StereoLayout {
  /// The layout a viewer's 3D control may switch to: mono, then top and bottom, then side by side, then mono again
  StereoLayout get next => switch (this) {
    StereoLayout.mono => StereoLayout.topBottom,
    StereoLayout.topBottom => StereoLayout.leftRight,
    StereoLayout.leftRight => StereoLayout.mono,
  };

  /// Part of the frame the left eye fills, normalised to [0, 1]. A flat screen shows that eye only.
  NormalizedRect get leftEyeRect => switch (this) {
    StereoLayout.mono => const NormalizedRect.fromLTWH(0, 0, 1, 1),
    StereoLayout.topBottom => const NormalizedRect.fromLTWH(0, 0, 1, 0.5),
    StereoLayout.leftRight => const NormalizedRect.fromLTWH(0, 0, 0.5, 1),
  };
}
