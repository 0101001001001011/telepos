import 'package:meta/meta.dart';

import 'package:telepos/domain/device/device_class.dart';

/// What a device *model* can do, as declared by its manufacturer.
///
/// Every field here is true of every unit of the model — that is the test
/// for whether something belongs here rather than on `DeviceBinding`: a
/// serial scale's baud rate is fixed by the manufacturer, so it lives here;
/// a printer's IP address differs per unit, so it does not.
///
/// Not every field applies to every device class — a scale has no paper
/// width, a printer has no baud rate. Unused fields sit at their default
/// (empty list / `false` / `null`); leaving the shape flat and generic keeps
/// one profile type instead of one per class, at the cost of some fields
/// being irrelevant noise for a given class.
@immutable
class DeviceCapabilities {
  const DeviceCapabilities({
    this.paperWidthsMm = const <int>[],
    this.labelHeightsMm = const <int>[],
    this.canCutPaper = false,
    this.codePages = const <String>[],
    this.defaultBaudRate,
    this.barcodeSymbologies = const <String>[],
    this.supportsOpenDrawer = false,
    this.displayColumns,
  });

  /// Paper or label widths the model *supports*, in millimetres. Which one
  /// is actually installed on one unit is an operator choice, recorded on
  /// `DeviceBinding` — not here. Printers and label printers only.
  final List<int> paperWidthsMm;

  /// Label heights the model *supports*, in millimetres — same shape and
  /// same reasoning as [paperWidthsMm], just the other axis of the label.
  /// Label printers only. Added while closing a review finding: this used to
  /// have nowhere to live at all, so `hardware_module.dart` hardcoded
  /// `labelHeightMm: 40` for every installation regardless of what the
  /// operator's label stock actually was — a lost setting, not merely an
  /// unmodelled field (the pre-branch blob carried `labelHeightMm` per
  /// installation). See [DeviceProfile.options] for how this becomes an
  /// operator-selectable choice the same way [paperWidthsMm] does.
  final List<int> labelHeightsMm;

  /// Whether the model can cut the paper it feeds. Printers only.
  final bool canCutPaper;

  /// Character encodings the model accepts for text. Printers and displays.
  final List<String> codePages;

  /// The serial baud rate fixed by the manufacturer for this model. `null`
  /// for classes with no serial port of their own (e.g. payment terminals,
  /// which speak over the network).
  final int? defaultBaudRate;

  /// Barcode symbologies the model can read. Scanners only.
  final List<String> barcodeSymbologies;

  /// Whether the model can pulse a cash drawer open — either its own kick
  /// port (cash drawers) or a printer's (receipt printers wired to a
  /// drawer).
  final bool supportsOpenDrawer;

  /// The number of characters the model's display can show, fixed by the
  /// manufacturer — e.g. 8 for a single-line LED pole display, 20 for a VFD
  /// or 2x20 LCD. Customer displays only; `null` for every other class.
  ///
  /// Added closing a review finding (task 5, plan 2b): `hardware_module.dart`
  /// used to hardcode every customer display to `DisplayModel.vfd20`
  /// regardless of which profile a binding actually named, which made
  /// `DisplayModel.led8` (a real value the enum has always declared —
  /// `lib/hardware/display/display_config.dart`) impossible to reach from
  /// any binding no matter which profile it chose. This is the fact that
  /// distinguishes the two: `_displayModelFor` now picks the `DisplayModel`
  /// whose `chars` matches this value instead of ignoring the profile
  /// entirely.
  final int? displayColumns;

  @override
  String toString() =>
      'DeviceCapabilities(paperWidthsMm: $paperWidthsMm, '
      'labelHeightsMm: $labelHeightsMm, '
      'canCutPaper: $canCutPaper, codePages: $codePages, '
      'defaultBaudRate: $defaultBaudRate, '
      'barcodeSymbologies: $barcodeSymbologies, '
      'supportsOpenDrawer: $supportsOpenDrawer, '
      'displayColumns: $displayColumns)';
}

/// One parameter a profile's protocol needs in order to connect — a host,
/// a COM port, a merchant id, an API key. Declared on the profile because
/// which parameters exist is fixed by the model/protocol; the *values* are
/// supplied per unit on `DeviceBinding.parameters` — see
/// docs/system-architecture.md, И141.
///
/// Deliberately just a key, a required flag, and a description: "keep it
/// simple, string values are enough, do not build a type system for
/// parameters" (plan 2, task 1, fix round 1). A settings screen (plan 2b)
/// renders one text field per declared parameter, using [description] as
/// its label/help text.
///
/// [key] does *not* belong here for barcode length limits, scan timeouts, or
/// anything else that does not change how the device is *addressed* — И142:
/// "параметр, не влияющий на разговор с устройством, не хранится среди его
/// настроек". Those are business rules about the value read, not the
/// conversation with the hardware, and this task does not model them at
/// all.
@immutable
class DeviceConnectionParam {
  const DeviceConnectionParam({
    required this.key,
    required this.isRequired,
    this.description = '',
  });

  /// Matched against the keys of `DeviceBinding.parameters`. Stable, not
  /// shown to the operator directly.
  final String key;

  /// Whether a binding must supply a non-blank value for [key] to validate.
  /// A profile may also declare optional parameters — e.g. a TCP port with
  /// a sensible protocol default that most installations never touch.
  final bool isRequired;

  /// Shown next to the field a settings screen renders for this parameter.
  final String description;

  @override
  String toString() =>
      'DeviceConnectionParam(key: $key, isRequired: $isRequired, '
      'description: $description)';
}

/// One operator-facing choice a model offers, and the values permitted for
/// it — e.g. "which paper width is installed", permitted values `58`/`80`.
///
/// Not a connection parameter: it has nothing to do with reaching the
/// device (see `DeviceConnectionParam`) and everything to do with which of
/// several supported physical configurations the operator actually
/// installed. Declared on the profile because the *set of permitted values*
/// is fixed by the model; the *chosen value* is supplied per unit on
/// `DeviceBinding.options` (plan 2, task 1, fix round 2).
///
/// Same shape as `DeviceConnectionParam` on purpose: a key, string values,
/// no type system. "Keep it simple, string values are enough."
@immutable
class DeviceOption {
  const DeviceOption({required this.key, required this.allowedValues, this.description = ''});

  /// Matched against the keys of `DeviceBinding.options`.
  final String key;

  /// The only values a binding may choose for [key]. A printer that
  /// supports only 80mm must not silently accept a binding that says 58 —
  /// the receipt would come out wrong and nothing would complain.
  final List<String> allowedValues;

  /// Shown next to the field a settings screen renders for this option.
  final String description;

  @override
  String toString() =>
      'DeviceOption(key: $key, allowedValues: $allowedValues, '
      'description: $description)';
}

/// One entry in the device profile catalog: a named model, its class, the
/// protocol it speaks, what it can do, and what a binding must supply to
/// reach one unit of it.
///
/// Deliberately absent: any actual address, port value, credential, chosen
/// option value, or enabled flag. Those differ between two units of the
/// same model and belong on `DeviceBinding`
/// (`lib/domain/terminal/device_binding.dart`), never here — see
/// docs/system-architecture.md, section 8, "Класс устройства, а не модель",
/// and И141.
@immutable
class DeviceProfile {
  const DeviceProfile({
    required this.id,
    required this.deviceClass,
    required this.title,
    required this.protocol,
    this.capabilities = const DeviceCapabilities(),
    this.connectionParams = const <DeviceConnectionParam>[],
  });

  /// Stable identifier, referenced by `DeviceBinding.profileId`. Not shown
  /// to the operator; the catalog UI (plan 2b) shows [title].
  final String id;

  final DeviceClass deviceClass;

  /// Human-readable model name, shown in the device catalog UI.
  final String title;

  final DeviceProtocol protocol;

  final DeviceCapabilities capabilities;

  /// What a `DeviceBinding` for this profile must (and may) supply to
  /// connect — e.g. a serial scale declares one `comPort` parameter, a
  /// networked payment terminal declares `ipAddress` and `port`. Empty for
  /// a class with nothing to configure (e.g. a USB HID scanner that the OS
  /// finds on its own).
  final List<DeviceConnectionParam> connectionParams;

  /// Operator-selectable options this model offers, and the values
  /// permitted for each — e.g. installed paper width.
  ///
  /// Deliberately *not* a separate stored/authored field: it is computed
  /// from [capabilities] so the set of permitted values is written exactly
  /// once. Right now that means [DeviceCapabilities.paperWidthsMm] — when a
  /// profile names more than zero supported widths, a `paperWidthMm` option
  /// appears here automatically, with exactly those widths (as strings) as
  /// its permitted values. There is no second, independently-typed list of
  /// widths anywhere to drift out of sync with the first — this codebase
  /// has already been bitten by that shape of bug twice (two country
  /// tables disagreeing on Russia's VAT rate; two writers using two
  /// encodings for the printer connection type).
  ///
  /// If a future capability needs the same "model supports several, unit
  /// runs exactly one" shape, add it here, derived from that capability —
  /// not as a new hand-typed list.
  List<DeviceOption> get options => [
    if (capabilities.paperWidthsMm.isNotEmpty)
      DeviceOption(
        key: 'paperWidthMm',
        allowedValues: capabilities.paperWidthsMm
            .map((mm) => mm.toString())
            .toList(growable: false),
        description: 'Installed paper width, in millimetres',
      ),
    // Same shape as paperWidthMm, added for the same reason: a second
    // hand-typed list of heights would be exactly the kind of duplicated
    // fact this codebase has already been bitten by twice.
    if (capabilities.labelHeightsMm.isNotEmpty)
      DeviceOption(
        key: 'labelHeightMm',
        allowedValues: capabilities.labelHeightsMm
            .map((mm) => mm.toString())
            .toList(growable: false),
        description: 'Installed label height, in millimetres',
      ),
  ];

  @override
  String toString() =>
      'DeviceProfile(id: $id, deviceClass: $deviceClass, title: $title, '
      'protocol: $protocol, capabilities: $capabilities, '
      'connectionParams: $connectionParams, options: $options)';
}
