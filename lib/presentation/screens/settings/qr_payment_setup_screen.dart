import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/settings/qr_payment_setup_controller.dart';

/// Настройка оплаты по QR на кассе — пункт 8 C (2026-09-15).
///
/// До этого экрана строку `qr_provider_configs` писала только дверь стенда
/// `stand/qr-provider`: владельцу настоящей кассы включить оплату по QR было
/// нечем. Здесь же — выключатель вида оплаты 6 (QR), без которого настройка
/// провайдера не даёт ничего.
///
/// # Ключ
///
/// Поле ключа **никогда не заполняется** сохранённым: экрану ключ не отдают
/// (`QrProviderView` без такого поля). Пустое поле при сохранении — прежний
/// ключ остаётся; «Стереть ключ» — явное действие. Ввод скрыт, подсказки и
/// автоисправление выключены: ключ не должен лечь в словарь клавиатуры.
///
/// Достижим из хаба настроек под правом `settings.accounts`
/// (`PermissionKeys.routeToPermissionKey`).
///
/// # С 2026-09-18 экран тот же и в браузере
///
/// Решение заказчика: «это не граница, а пробел — в браузере должно работать
/// то же, что в приложении». Ни строки условий «а тут у нас планшет» здесь
/// нет и не появилось: экран спрашивает доменный порт
/// (`QrProviderSetupRepository`), а какая из двух реализаций под ним —
/// кассовая стойка или провод — решает точка входа сборки. Прежняя фраза «это
/// делается на самой кассе» осталась ровно для того, для чего и годится: для
/// сборки, где порт не привязан вовсе.
///
/// Единственное, что различает две сборки, — [homeRoute]: **куда уходить,
/// когда уходить некуда**. Вкладка браузера открывается прямо по адресу, и
/// стека переходов у неё нет — `context.pop()` в такой вкладке не делает
/// ничего, и кассир остаётся на экране навсегда (ровно этот дефект уже стоил
/// круга на `/refund` и `/sessions`). Дом у двух таблиц разный, и экран,
/// назвавший один из них сам, увёл бы вторую сборку на несуществующий адрес —
/// поэтому дом называет **таблица маршрутов**, а не экран.
class QrPaymentSetupScreen extends ConsumerStatefulWidget {
  const QrPaymentSetupScreen({super.key, this.homeRoute});

  /// Куда уйти по стрелке «назад», если возвращаться некуда. `null` — только
  /// `pop`, и это верно для десктопа: туда приходят `context.push` из хаба
  /// настроек, то есть стек есть всегда.
  final String? homeRoute;

  @override
  ConsumerState<QrPaymentSetupScreen> createState() =>
      _QrPaymentSetupScreenState();
}

class _QrPaymentSetupScreenState extends ConsumerState<QrPaymentSetupScreen> {
  final _url = TextEditingController();
  final _code = TextEditingController();
  final _key = TextEditingController();
  final _patience = TextEditingController();
  var _clearKey = false;
  var _synced = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(qrPaymentSetupControllerProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _url.dispose();
    _code.dispose();
    _key.dispose();
    _patience.dispose();
    super.dispose();
  }

  /// Назад — в стек, а при пустом стеке в дом сборки (докстринг виджета).
  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final home = widget.homeRoute;
    if (home != null) context.go(home);
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? Theme.of(context).colorScheme.error
            : AppColors.success,
      ),
    );
  }

  String _problemText(AppLocalizations l10n, QrSettingsProblem problem) =>
      switch (problem) {
        QrSettingsProblem.invalidUrl => l10n.qrSettingsInvalidUrl,
        QrSettingsProblem.codeRequired => l10n.qrSettingsCodeRequired,
        QrSettingsProblem.invalidPatience => l10n.qrSettingsInvalidPatience(
          '${QrPaymentSetupController.minPatienceSeconds}',
          '${QrPaymentSetupController.maxPatienceSeconds}',
        ),
        QrSettingsProblem.saveFailed => l10n.qrSettingsSaveFailed,
      };

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await ref
        .read(qrPaymentSetupControllerProvider.notifier)
        .save(
          baseUrl: _url.text,
          code: _code.text,
          patienceSeconds: _patience.text,
          newApiKey: _key.text,
          clearApiKey: _clearKey,
        );
    if (!mounted) return;
    if (ok) {
      // Введённый ключ ушёл в порт — в поле ему больше не место.
      _key.clear();
      setState(() => _clearKey = false);
      _snack(l10n.qrSettingsSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(qrPaymentSetupControllerProvider);

    ref.listen<QrPaymentSetupState>(qrPaymentSetupControllerProvider, (
      prev,
      next,
    ) {
      final view = next.view;
      if (view != null && !_synced) {
        _synced = true;
        _url.text = view.baseUrl;
        _code.text = view.code;
        _patience.text = view.patience.inSeconds.toString();
      }
      final problem = next.problem;
      if (problem != null && problem != prev?.problem) {
        _snack(_problemText(l10n, problem), error: true);
      }
      // Названный отказ кассы — фразой словаря по коду, а не текстом кассы:
      // текст написан по-русски внутри кассы и на экран не едет (И144).
      // Отдельной строкой от [QrSettingsProblem]: беда формы и отказ кассы —
      // разные вещи, и общее «не удалось сохранить» на оба было бы враньём
      // про то, что именно случилось.
      final refusal = next.refusalKey;
      if (refusal != null && refusal != prev?.refusalKey) {
        _snack(ErrorLocalizer.localize(context, refusal), error: true);
      }
    });

    final view = state.view;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.qrSettingsTitle),
        leading: IconButton(
          key: const Key('qr-settings-back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : view == null
          // Снимка нет — форму показывать нечем. Две разные причины, и
          // спутать их нельзя: **порт не привязан** (сборка без настройки
          // вовсе) и **касса отказала** названным кодом — нет права, нет
          // стойки, оборвана связь. До 2026-09-18 обе показывали «настройка
          // делается на самой кассе», и владелец, которому не хватало права,
          // читал бы, что ему надо подойти к кассе, где ему откажут так же.
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: state.refusalKey == null
                    ? Text(
                        key: const Key('qr-settings-till-only'),
                        l10n.qrSettingsTillOnly,
                        textAlign: TextAlign.center,
                      )
                    : Text(
                        key: const Key('qr-settings-refused'),
                        ErrorLocalizer.localize(context, state.refusalKey!),
                        textAlign: TextAlign.center,
                      ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: SwitchListTile(
                    key: const Key('qr-settings-kind'),
                    value: view.kindActive,
                    onChanged: state.saving
                        ? null
                        : (value) => ref
                              .read(qrPaymentSetupControllerProvider.notifier)
                              .setKindActive(value),
                    title: Text(l10n.qrSettingsKindTitle),
                    subtitle: Text(l10n.qrSettingsKindSubtitle),
                    secondary: const Icon(Icons.qr_code_2),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          key: const Key('qr-settings-status'),
                          view.configured
                              ? l10n.qrSettingsStatusReady
                              : l10n.qrSettingsStatusNotConfigured,
                          style: TextStyle(
                            color: view.configured
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('qr-settings-url'),
                          controller: _url,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            labelText: l10n.qrSettingsUrl,
                            hintText: 'https://',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('qr-settings-code'),
                          controller: _code,
                          decoration: InputDecoration(
                            labelText: l10n.qrSettingsCode,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('qr-settings-key'),
                          controller: _key,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          enabled: !_clearKey,
                          decoration: InputDecoration(
                            labelText: l10n.qrSettingsKey,
                            helperText: view.keySet
                                ? l10n.qrSettingsKeyStoredHint
                                : l10n.qrSettingsKeyEmptyHint,
                          ),
                        ),
                        if (view.keySet)
                          CheckboxListTile(
                            key: const Key('qr-settings-clear-key'),
                            contentPadding: EdgeInsets.zero,
                            value: _clearKey,
                            onChanged: (value) =>
                                setState(() => _clearKey = value ?? false),
                            title: Text(l10n.qrSettingsClearKey),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('qr-settings-patience'),
                          controller: _patience,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.qrSettingsPatience,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (view.configured)
                              TextButton(
                                key: const Key('qr-settings-remove'),
                                onPressed: state.saving
                                    ? null
                                    : () => ref
                                          .read(
                                            qrPaymentSetupControllerProvider
                                                .notifier,
                                          )
                                          .clear(),
                                child: Text(l10n.qrSettingsRemove),
                              ),
                            const Spacer(),
                            ElevatedButton(
                              key: const Key('qr-settings-save'),
                              onPressed: state.saving ? null : _save,
                              child: Text(l10n.qrSettingsSave),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
