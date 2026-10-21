// Byte range readers over bytes in memory, for the tests

import 'dart:typed_data';

import 'package:raw360_formats/raw360_formats.dart';

/// Reads [bytes] as a file would: fewer bytes at its end, none past it. The offset of each read goes to [reads].
ByteRangeReader bytesReader(Uint8List bytes, [List<int>? reads]) => (offset, length) async {
  reads?.add(offset);
  final start = offset.clamp(0, bytes.length);
  final end = (offset + length).clamp(0, bytes.length);
  return Uint8List.sublistView(bytes, start, end);
};
