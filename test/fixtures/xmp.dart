// GPano XMP and photos that carry it, for the tests

import 'dart:convert';
import 'dart:typed_data';

// GPano XMP as cameras write it, attributes on rdf:Description
String cameraXmp({String projection = 'equirectangular', String crop = ''}) =>
    '<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF><rdf:Description rdf:about="" '
    'xmlns:GPano="http://ns.google.com/photos/1.0/panorama/" GPano:ProjectionType="$projection" '
    'GPano:UsePanoramaViewer="True" $crop/></rdf:RDF></x:xmpmeta>';

// The crop of a VR180 photo: half the width of the full panorama, all of its height
const halfSphereCropTags =
    'GPano:FullPanoWidthPixels="8000" GPano:FullPanoHeightPixels="4000" GPano:CroppedAreaLeftPixels="2000" '
    'GPano:CroppedAreaTopPixels="0" GPano:CroppedAreaImageWidthPixels="4000" GPano:CroppedAreaImageHeightPixels="4000"';

// A JPEG-like file: a few bytes, the XMP at [xmpOffset], then filler up to [length]
Uint8List photoWithXmp(String xmp, {int xmpOffset = 100, int length = 4096}) {
  final bytes = Uint8List(length);
  bytes.setAll(xmpOffset, latin1.encode(xmp));
  return bytes;
}
