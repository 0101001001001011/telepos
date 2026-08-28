// A till and the shop server it talks to, in one process.
//
// Run it after building the native library:
//
//   cd rust && cargo build --release
//   dart run example/rk_zenoh_example.dart
//
// It shows the three things worth showing: that addressing by durable identity
// survives a restart, that addressing by Zenoh ID does not, and that the
// failure is silent.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:rk_zenoh/rk_zenoh.dart';

const _port = 17447;

Future<void> main() async {
  final library = _locateLibrary();
  if (library == null) {
    stderr.writeln(
      'Build the native library first: cd rust && cargo build '
      '--release',
    );
    exitCode = 1;
    return;
  }

  // The shop server listens; the till dials it. Neither traverses NAT — a till
  // behind someone else's router is reached through a relay, not through this.
  final server = await ZenohSession.open(
    ZenohConfig(mode: SessionMode.peer, listen: ['tcp/127.0.0.1:$_port']),
    libraryPath: library,
  );
  print('shop server is ${server.zid}');

  // Watch who is present. Declared before anyone announces themselves: there
  // is no history in the stable subset, so a late watcher sees nothing.
  final presence = await server.watchLiveliness('telepos/alive/**');
  presence.samples.listen((s) {
    final verb = s.kind == SampleKind.put ? 'arrived' : 'left';
    print('  presence: ${s.key} $verb');
  });

  var till = await ZenohSession.open(
    ZenohConfig(mode: SessionMode.peer, connect: ['tcp/127.0.0.1:$_port']),
    libraryPath: library,
  );
  final firstZid = till.zid;
  print('till is $firstZid');

  var alive = await till.declareLiveliness('telepos/alive/till-17');
  var orders = await till.subscribe('telepos/till/till-17/cmd');
  orders.samples.listen((s) => print('  till received: ${s.text}'));

  await _keepSending(server, 'telepos/till/till-17/cmd', 'open-drawer');

  // The till restarts, as it does on every update.
  print('\n--- the till restarts ---');
  await alive.close();
  await orders.close();
  await till.close();

  till = await ZenohSession.open(
    ZenohConfig(mode: SessionMode.peer, connect: ['tcp/127.0.0.1:$_port']),
    libraryPath: library,
  );
  print('till came back as ${till.zid} (it was $firstZid)');

  alive = await till.declareLiveliness('telepos/alive/till-17');
  orders = await till.subscribe('telepos/till/till-17/cmd');
  orders.samples.listen((s) => print('  till received: ${s.text}'));

  // Addressed by durable identity: still works.
  await _keepSending(server, 'telepos/till/till-17/cmd', 'print-receipt');

  // Addressed by the Zenoh ID the server remembered: accepted, delivered
  // nowhere, and nothing says so.
  print('\nsending to the old zid $firstZid ...');
  for (var i = 0; i < 10; i++) {
    await server.put(
      'telepos/direct/$firstZid/cmd',
      utf8.encode('this goes nowhere'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  print('  ten puts succeeded. Nothing was delivered, and nothing complained.');

  await alive.close();
  await orders.close();
  await presence.close();
  await till.close();
  await server.close();
}

/// Publish until the other side has had a chance to receive.
///
/// A subscription takes a moment to propagate, and a put with nothing matching
/// yet is a success that delivers nothing — which is the whole lesson.
Future<void> _keepSending(
  ZenohSession session,
  String key,
  String message,
) async {
  for (var i = 0; i < 6; i++) {
    await session.put(key, utf8.encode(message));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

String? _locateLibrary() {
  final s = Platform.pathSeparator;
  final name = defaultLibraryFileName();
  for (final root in ['rust${s}target']) {
    for (final profile in ['release', 'debug']) {
      final path = '$root$s$profile$s$name';
      if (File(path).existsSync()) return File(path).absolute.path;
    }
  }
  return null;
}
