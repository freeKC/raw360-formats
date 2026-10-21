// Prints what raw360_formats reads in the files named on the command line:
//
//   dart run example/inspect.dart IMG_20250101_120000_00_001.insp VID_20250101_120000_00_001.insv clip.mp4
//
// Every reader takes a ByteRangeReader, a function that returns the bytes of a range of the file. Here it reads a
// local file; the same function can send an HTTP request with a Range header instead.

import 'dart:io';
import 'dart:typed_data';

import 'package:raw360_formats/raw360_formats.dart';

/// A [ByteRangeReader] over a local file
ByteRangeReader fileReader(RandomAccessFile file) => (offset, length) async {
  await file.setPosition(offset);
  return file.read(length);
};

Future<void> main(List<String> paths) async {
  if (paths.isEmpty) {
    stderr.writeln('Usage: dart run example/inspect.dart FILE...');
    exitCode = 64;
    return;
  }
  for (final path in paths) {
    final file = await File(path).open();
    try {
      await inspect(path, fileReader(file), await file.length());
    } finally {
      await file.close();
    }
  }
}

Future<void> inspect(String path, ByteRangeReader read, int length) async {
  final name = path.split(Platform.pathSeparator).last;
  print('== $name ($length bytes)');
  // A HEIF photo starts with an ftyp box too: its stereo pair is looked for first
  final pair = await probeHeicStereoPair(read);
  if (pair != null) {
    print('HEIC stereo pair: $pair');
    return;
  }
  final head = await read(0, 12);
  final isMp4 = head.length >= 8 && String.fromCharCodes(head, 4, 8) == 'ftyp';
  print('raw 360° kind by name: ${rawMediaKindOfName(name, isVideo: isMp4) ?? 'none'}');

  final trailer = await readInsta360Trailer(read, length);
  if (trailer != null) {
    print('Insta360 trailer: ${trailer.cameraModel}, firmware ${trailer.firmware}, indexed: ${trailer.indexed}');
    final calibration = calibrationOf(trailer);
    if (calibration != null) {
      print('  calibration: ${calibration.model.name}, canvas square ${calibration.canvasSquare}');
      for (final (i, lens) in calibration.lenses.indexed) {
        print('  lens $i: centre (${lens.cx}, ${lens.cy}), yaw ${lens.yaw}, pitch ${lens.pitch}, roll ${lens.roll}');
      }
      print('  gravity in the body frame: ${calibration.downBody}');
    }
    final order = insta360TrackOrder(trailer);
    print('  video track 0 holds lens ${order.lensOfTrack0} (${order.source})');
  }

  if (isMp4) {
    final probe = await probeSphericalMetadata(read);
    print(
      'spherical metadata: ${probe.hasSphericalMetadata}, stereo ${probe.stereo?.name}, '
      'half sphere ${probe.halfSphere}',
    );
    for (final track in probe.tracks) {
      print(
        '  track ${track.index}: ${track.handlerType} ${track.codec} ${track.codedWidth ?? ''}'
        '${track.codedHeight == null ? '' : ' x ${track.codedHeight}'} "${track.handlerName ?? ''}"',
      );
    }
    final goPro = goProEacGeometryOf(probe);
    if (goPro != null) {
      print('GoPro EAC: ${goProCameraName(goPro)}, $goPro');
    }
    final dji = await readDjiOsvCalibration(read);
    if (dji != null) {
      print('DJI camd: ${dji.model}, firmware ${dji.firmware}, schema ${dji.schema}');
      for (final (i, lens) in dji.calibration.lenses.indexed) {
        print(
          '  lens $i: fx ${lens.fx}, centre (${lens.cx}, ${lens.cy}), k1..k5 '
          '${[lens.k1, lens.k2, lens.k3, lens.k4, lens.k5]}',
        );
      }
    }
  } else {
    final photo = await probe360Photo(read, length, name: name);
    print('photo: 360° ${photo.isPanorama}, half sphere ${photo.halfSphere}, raw ${photo.raw360}');
    final gpano = await readGPanoTags(read, length);
    if (gpano != null) {
      print('GPano: projection ${gpano.projectionType}, crop ${gpano.crop}, initial view ${gpano.initialView}');
    }
    final exif = parseExifHead(Uint8List.fromList(await read(0, exifHeadLength)));
    if (exif != null) {
      print('EXIF: ${exif.make} ${exif.model}, ${exif.pixelWidth} x ${exif.pixelHeight}');
    }
  }
}
