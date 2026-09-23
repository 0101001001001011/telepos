import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/data/sysd/sysd_client.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/system/system_management_controller.dart';
import 'package:telepos/core/constants/enums/user_role.dart';
import 'package:telepos/presentation/common/widgets/owner_only_gate.dart';
import 'package:telepos/presentation/controllers/app/app_state_controller.dart';
import 'package:telepos/app/theme/app_typography.dart';

class SystemTerminalScreen extends ConsumerStatefulWidget {
  const SystemTerminalScreen({super.key});

  @override
  ConsumerState<SystemTerminalScreen> createState() =>
      _SystemTerminalScreenState();
}

class _TerminalEntry {
  _TerminalEntry({required this.command, this.running = false});

  final String command;
  String stdout = '';
  String stderr = '';
  int? exitCode;
  bool running;
  String? transportError;
}

class _Preset {
  const _Preset(this.nameOf, this.command);

  final String Function(AppLocalizations) nameOf;

  final String command;
}

class _PresetGroup {
  const _PresetGroup(this.titleOf, this.presets);

  final String Function(AppLocalizations) titleOf;

  final List<_Preset> presets;
}

final List<_PresetGroup> _terminalPresetGroups = [
  _PresetGroup((l) => l.sysmTermGroupDiagnostics, [
    _Preset(
      (l) => l.sysmTermDiagOsAndDaemon,
      'echo "=== OS ==="; grep -E "PRETTY_NAME|VERSION=" /etc/os-release; '
      'echo "=== sysd ==="; systemctl --no-pager show telepos-sysd -p ActiveState,SubState; '
      'journalctl -u telepos-sysd -b --no-pager 2>/dev/null | grep -m1 -iE "telepos-sysd|listening|version"',
    ),
    _Preset(
      (l) => l.sysmTermDiagNetworkStatus,
      'echo "=== devices ==="; nmcli device status; '
      'echo "=== ip ==="; nmcli -f GENERAL.STATE,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS dev show; '
      'echo "=== route ==="; ip route',
    ),
    _Preset(
      (l) => l.sysmTermDiagNetworkConnectivity,
      'echo "=== ping ==="; ping -c2 -W2 8.8.8.8; '
      'echo "=== dns ==="; getent hosts repo.spherex.kz',
    ),
    _Preset(
      (l) => l.sysmTermDiagHardware,
      'echo "=== disk/mem ==="; df -h /; free -h; uptime; '
      'echo "=== printers ==="; ls -l /dev/usb/lp* /dev/ttyUSB* /dev/ttyACM* 2>/dev/null; '
      'echo "=== net dmesg ==="; dmesg 2>/dev/null | grep -iE "rhine|velocity|link is|eth[0-9]|enp" | tail -12',
    ),
  ]),
  _PresetGroup((l) => l.sysmTermGroupPrinter, [
    _Preset(
      (l) => l.sysmTermPrinterFixAuto,
      r'''echo "[1/7] освобождаем от CUPS..."; systemctl stop cups cups-browsed cups.socket cups.path 2>/dev/null; systemctl mask cups cups.socket cups.path 2>/dev/null; '''
      r'''echo "[2/7] удаляем фантомные файлы lp* (НЕ char-устройства)..."; for n in /dev/usb/lp* /dev/lp*; do if [ -e "$n" ] && [ ! -c "$n" ]; then rm -f "$n" && echo "  удалён фантом $n"; fi; done; '''
      r'''echo "[3/7] usblp + автозагрузка..."; echo usblp > /etc/modules-load.d/telepos-usblp.conf; modprobe -r usblp 2>/dev/null; modprobe usblp 2>&1; sleep 1; '''
      r'''echo "[4/7] доступ пользователя к принтеру (группа lp)..."; usermod -aG lp telepos 2>/dev/null; id telepos 2>&1; '''
      r'''echo "[5/7] узлы:"; ls -l /dev/usb/lp* /dev/lp* 2>&1; '''
      r'''echo "[6/7] выбираем CHAR-узел (любой индекс)..."; D=""; for n in /dev/usb/lp* /dev/lp*; do if [ -c "$n" ]; then D="$n"; break; fi; done; echo "  узел: ${D:-НЕТ}"; '''
      r'''echo "[7/7] тест-печать:"; if [ -n "$D" ]; then printf '\n\n   TelePOS: printer OK\n\n\n\n' > "$D" && echo "OK - отправлено на $D. ВАЖНО: чтобы печатало САМО приложение, перезагрузите приставку (reboot) — нужно подхватить группу lp." || echo "ОШИБКА записи в $D"; else echo "НЕТ char-узла принтера (проверьте кабель/питание; см. lsusb)"; fi''',
    ),
    _Preset(
      (l) => l.sysmTermPrinterDiag,
      'ls -l /dev/usb/lp* /dev/lp* 2>&1; echo "--usblp--"; lsmod | grep -i usblp; '
      'echo "--lsusb--"; lsusb; echo "--user--"; id telepos; '
      'echo "--cups--"; systemctl is-active cups 2>&1',
    ),
    _Preset(
      (l) => l.sysmTermPrinterLoadUsblp,
      'modprobe usblp && echo "usblp загружен"; lsmod | grep -i usblp; ls -l /dev/usb/lp* 2>&1',
    ),
    _Preset(
      (l) => l.sysmTermPrinterNodesAndPerms,
      'ls -l /dev/usb/lp* /dev/lp* /dev/ttyUSB* /dev/ttyACM* 2>&1',
    ),
    _Preset((l) => l.sysmTermPrinterLsusb, 'lsusb'),
    _Preset(
      (l) => l.sysmTermPrinterCupsStatus,
      'systemctl is-active cups; lpstat -p -d 2>&1',
    ),
    _Preset(
      (l) => l.sysmTermPrinterGiveToKernel,
      'systemctl stop cups cups-browsed 2>/dev/null; modprobe usblp; sleep 1; ls -l /dev/usb/lp* 2>&1',
    ),
    _Preset(
      (l) => l.sysmTermPrinterTestPrint,
      r'''printf '\n\n   TelePOS test print\n\n\n\n' > /dev/usb/lp0 && echo "отправлено на /dev/usb/lp0" || echo "ОШИБКА: нет доступа к /dev/usb/lp0"''',
    ),
  ]),
  _PresetGroup((l) => l.sysmTermGroupNetwork, [
    _Preset((l) => l.sysmTermNetDeviceStatus, 'nmcli device status'),
    _Preset((l) => l.sysmTermNetIpAddresses, 'ip -br a'),
    _Preset((l) => l.sysmTermNetConnectEthernet, 'nmcli device connect enp5s0'),
    _Preset((l) => l.sysmTermNetReload, 'nmcli general reload'),
    _Preset((l) => l.sysmTermNetPing, 'ping -c3 8.8.8.8'),
  ]),
  _PresetGroup((l) => l.sysmTermGroupSystem, [
    _Preset((l) => l.sysmTermSysDisk, 'df -h'),
    _Preset((l) => l.sysmTermSysMemory, 'free -h'),
    _Preset(
      (l) => l.sysmTermSysSysdStatus,
      'systemctl status telepos-sysd --no-pager',
    ),
    _Preset(
      (l) => l.sysmTermSysKioskLogs,
      'journalctl -u telepos-kiosk -n 50 --no-pager',
    ),
  ]),
  _PresetGroup((l) => l.sysmTermGroupTime, [
    _Preset((l) => l.sysmTermTimeDateTime, 'timedatectl'),
    _Preset((l) => l.sysmTermTimeNtpSync, 'chronyc tracking'),
  ]),
];

class _SystemTerminalScreenState extends ConsumerState<SystemTerminalScreen> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scrollController = ScrollController();

  final List<_TerminalEntry> _entries = [];

  final List<String> _history = [];
  int _historyCursor = -1;

  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  SystemManagementNotifier get _ctrl =>
      ref.read(systemManagementControllerProvider.notifier);

  Future<void> _run() async {
    final cmd = _input.text.trim();
    if (cmd.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _historyCursor = -1;
      if (_history.isEmpty || _history.last != cmd) _history.add(cmd);
      _input.clear();
    });
    final entry = _TerminalEntry(command: cmd, running: true);
    setState(() => _entries.add(entry));
    _scrollToBottom();

    try {
      final ExecResult res = await _ctrl.exec(cmd, timeout: 60);
      if (!mounted) return;
      setState(() {
        entry.stdout = res.stdout;
        entry.stderr = res.stderr;
        entry.exitCode = res.exitCode;
        entry.running = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        entry.running = false;
        entry.transportError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollToBottom();
        _inputFocus.requestFocus();
      }
    }
  }

  void _applyPreset(String command, {bool run = true}) {
    if (_busy) return;
    _input.text = command;
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    _historyCursor = -1;
    if (run) {
      _run();
    } else {
      setState(() {});
      _inputFocus.requestFocus();
    }
  }

  Future<void> _showPresetsMenu() async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    l10n.sysmTerminalPresets,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (final group in _terminalPresetGroups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      group.titleOf(l10n),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final preset in group.presets)
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.play_arrow_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        preset.nameOf(l10n),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        preset.command,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.familyMono,
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onTap: () => Navigator.of(ctx).pop(preset.command),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && mounted) {
      _applyPreset(selected);
    }
  }

  Widget _presetsBar(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: OutlinedButton(
        onPressed: _busy ? null : _showPresetsMenu,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Row(
          children: [
            const Icon(Icons.dashboard_customize_outlined, size: 18),
            const SizedBox(width: 10),
            Text(l10n.sysmTerminalPresets),
            const Spacer(),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _historyUp() {
    if (_history.isEmpty) return;
    setState(() {
      if (_historyCursor == -1) {
        _historyCursor = _history.length - 1;
      } else if (_historyCursor > 0) {
        _historyCursor--;
      }
      _input.text = _history[_historyCursor];
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
    });
  }

  void _historyDown() {
    if (_history.isEmpty || _historyCursor == -1) return;
    setState(() {
      if (_historyCursor < _history.length - 1) {
        _historyCursor++;
        _input.text = _history[_historyCursor];
      } else {
        _historyCursor = -1;
        _input.clear();
      }
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _historyUp();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _historyDown();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(appStateProvider.select((s) => s.userRole));
    if (role != null && role != UserRole.owner.index) {
      return ownerOnlyScaffold(context, l10n.sysmTerminalTitle);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sysmTerminalTitle),
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: l10n.sysmTerminalClear,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _entries.isEmpty
                ? null
                : () => setState(() => _entries.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.warningLight,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.sysmTerminalRootNote,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _presetsBar(l10n),
          const Divider(height: 1),
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFF1E1E1E),
              child: _entries.isEmpty
                  ? Center(
                      child: Text(
                        l10n.sysmTerminalEmpty,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontFamily: AppTypography.familyMono,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _entries.length,
                      itemBuilder: (context, i) =>
                          _entryView(l10n, _entries[i]),
                    ),
            ),
          ),
          _inputBar(l10n),
        ],
      ),
    );
  }

  Widget _entryView(AppLocalizations l10n, _TerminalEntry e) {
    const mono = TextStyle(fontFamily: AppTypography.familyMono, fontSize: 13);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            '\$ ${e.command}',
            style: mono.copyWith(
              color: const Color(0xFF6AB0F3),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (e.running)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            ),
          if (e.transportError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SelectableText(
                e.transportError!,
                style: mono.copyWith(color: const Color(0xFFFF8A80)),
              ),
            ),
          if (e.stdout.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SelectableText(
                e.stdout.trimRight(),
                style: mono.copyWith(color: const Color(0xFFE0E0E0)),
              ),
            ),
          if (e.stderr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SelectableText(
                e.stderr.trimRight(),
                style: mono.copyWith(color: const Color(0xFFFF8A80)),
              ),
            ),
          if (e.exitCode != null && e.exitCode != 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(
                    TeleposIcons.error,
                    size: 14,
                    color: Color(0xFFFF8A80),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.sysmTerminalExitCode(e.exitCode!),
                    style: mono.copyWith(color: const Color(0xFFFF8A80)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _inputBar(AppLocalizations l10n) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Focus(
                onKeyEvent: _onKey,
                child: TextField(
                  key: const ValueKey('terminal-input'),
                  controller: _input,
                  focusNode: _inputFocus,
                  autofocus: true,
                  enabled: !_busy,
                  textInputAction: TextInputAction.go,
                  style: const TextStyle(
                    fontFamily: AppTypography.familyMono,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.sysmTerminalHint,
                    prefixText: '\$ ',
                    prefixStyle: const TextStyle(
                      fontFamily: AppTypography.familyMono,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _run(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: FilledButton(
                key: const ValueKey('terminal-run'),
                onPressed: _busy ? null : _run,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.keyboard_return),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
