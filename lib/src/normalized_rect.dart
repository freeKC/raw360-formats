// A rectangle in normalised coordinates, [0, 1] across and down a picture or the full sphere: what a GPano crop, the
// part of the sphere a half sphere media covers, or the place of an eye in a stereo frame are expressed in. Pure Dart,
// so that the package needs no Flutter.

/// A rectangle whose [left], [top], [width] and [height] are fractions of a whole (a picture, or the full sphere as an
/// equirectangular image: longitudes from -180° to +180° across, latitudes from +90° to -90° down)
class NormalizedRect {
  const NormalizedRect.fromLTWH(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  @override
  bool operator ==(Object other) =>
      other is NormalizedRect &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'NormalizedRect.fromLTWH($left, $top, $width, $height)';
}
