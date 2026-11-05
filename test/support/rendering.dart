import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadTestFonts() async {
  final configFile = File('.dart_tool/package_config.json');
  final packages =
      jsonDecode(configFile.readAsStringSync())['packages'] as List;
  final flutter = packages.firstWhere((entry) => entry['name'] == 'flutter');
  final root = Directory.fromUri(
    configFile.absolute.uri.resolve(flutter['rootUri'] as String),
  ).parent.parent;
  final fonts = '${root.path}/bin/cache/artifacts/material_fonts';
  for (final entry in [
    ('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']),
    ('MaterialIcons', ['MaterialIcons-Regular.otf']),
  ]) {
    final loader = FontLoader(entry.$1);
    for (final file in entry.$2) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(File('$fonts/$file').readAsBytesSync()),
        ),
      );
    }
    await loader.load();
  }
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_PREVIEWS')) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final rendered = await boundary.toImage(pixelRatio: 2);
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/previews').createSync(recursive: true);
    File('build/previews/$name.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
    rendered.dispose();
  });
}
