// A runnable tour of rk_devices. Build the native crate first:
//
//   cd rust && cargo build --release
//   dart run example/rk_devices_example.dart
//
// Nothing here touches a device: every call is a pure function of its
// arguments, which is the whole design of the package.

// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:rk_devices/rk_devices.dart';

void main() {
  final devices = RkDevices.tryOpen();
  if (devices == null) {
    print('no rk_devices native library on this host');
    print('reason: ${RkDevices.lastLoadFailure}');
    return;
  }

  print('rk_devices ${devices.version}');
  print('');

  _scales(devices);
  _display(devices);
  _drawer(devices);
  _mdb(devices);
  _partialWrites(devices);
}

void _scales(RkDevices devices) {
  print('-- scales --');
  print(
    'weight request (CAS): ${_hex(devices.scaleWeightRequest(ScaleProtocol.cas))}',
  );

  final frame = devices.scaleParse(
    ScaleProtocol.cas,
    Uint8List.fromList('ST,GS,+  1.234kg\r\n'.codeUnits),
  );
  if (frame is ScaleReadingFrame) {
    final r = frame.reading;
    print(
      'read ${r.toDecimalString()} ${r.unit.wireName}, '
      '${r.stability.wireName}, ${r.measure.wireName}',
    );
  }

  // The settling rule holds no clock: elapsed time is supplied, not measured.
  final rule = devices.stabilizer(budget: const Duration(seconds: 1));
  try {
    print(
      'silence at 0 ms: '
      '${rule.offer(elapsed: Duration.zero, heard: Heard.silence).wireName}',
    );
    print(
      'silence at 1000 ms: '
      '${rule.offer(elapsed: const Duration(seconds: 1), heard: Heard.silence).wireName}'
      '  <- not "timeout": nothing was ever heard',
    );
  } finally {
    rule.dispose();
  }
  print('');
}

void _display(RkDevices devices) {
  print('-- customer display --');
  final line = devices.displayEncode(
    model: DisplayModel.vfd20,
    op: DisplayOp.writeLine,
    line: 1,
    text: 'ИТОГО:',
  );
  print('VFD line 2: ${_hex(line.bytes)}');
  print('substitutions: ${line.substitutions}');

  final tenge = devices.displayEncode(
    model: DisplayModel.led8,
    op: DisplayOp.writeLine,
    text: '100 ₸',
  );
  print('LED "100 ₸": ${_hex(tenge.bytes)}');
  print(
    'substitutions: ${tenge.substitutions}'
    '  <- CP866 has no tenge sign, and says so',
  );
  print('');
}

void _drawer(RkDevices devices) {
  print('-- cash drawer --');
  switch (devices.drawerPulse()) {
    case DrawerPulseBytes(:final bytes):
      print('kick pin 2: ${_hex(bytes)}');
    case DrawerPulseRefused(:final status):
      print('refused: $status');
    case DrawerPulseUnsupportedHere(:final reason):
      print('unsupported here: $reason');
  }
  print(
    'reporting: ${devices.drawerReporting(DrawerModel.escposKick).wireName}'
    '  <- the kick wire is one-directional',
  );
  print('');
}

void _mdb(RkDevices devices) {
  print('-- MDB --');
  final poll = devices.mdbEncode(MdbAddress.coinChanger, 'poll');
  print(
    'changer poll: ${poll.map((w) => '0x${w.toRadixString(16)}').join(' ')}',
  );
  print('mode bit: 0x${devices.mdbModeBit.toRadixString(16)}');
  print(
    'response window: ${devices.mdbResponseWindow.inMilliseconds} ms'
    '  <- a number for the bridge, not a deadline held here',
  );
  print('');
}

void _partialWrites(RkDevices devices) {
  print('-- partial writes --');
  for (final wire in Wire.values) {
    print(
      '${wire.wireName}: reports a byte count = '
      '${devices.wireReportsPartialWrites(wire)}',
    );
  }
  print(
    'serial, 40 of 80 accepted: '
    '${devices.resolveWrite(wire: Wire.serial, total: 80, accepted: 40)}',
  );
  print(
    'socket, write failed:      '
    '${devices.resolveWrite(wire: Wire.socket, total: 80, accepted: null)}',
  );
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
