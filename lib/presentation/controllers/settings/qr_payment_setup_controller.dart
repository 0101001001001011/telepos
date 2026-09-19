/// Контроллер экрана настройки оплаты по QR — пункт 8 C (2026-09-15).
///
/// Ходит только через доменный порт [QrProviderSetupRepository]: базы не
/// читает (И5), ключа провайдера не получает — у [QrProviderView] нет такого
/// поля (докстринг `qr_provider_setup.dart`). Введённый кассиром новый ключ
/// уходит в порт и в состоянии не хранится.
///
/// # Отказ порта — кодом, а не «не удалось сохранить» (2026-09-18)
///
/// С того дня под портом может стоять **провод** (`WtQrProviderSetup`), и у
/// его отказов есть имена: касса без стойки QR отвечает
/// [qrSetupUnavailableCode], сторож провода — `forbidden`, потерянная связь —
/// `no_session`. Все они до этой правки складывались в одну фразу «не удалось
/// сохранить»: владелец, которому не хватает права, читал бы то же, что
/// владелец с оборванной сетью.
///
/// Поэтому названный отказ едет в состояние **ключом словаря**
/// ([QrPaymentSetupState.refusalKey]), а не текстом кассы: фразу даёт
/// `saleRefusalErrorKeyOf` → `ErrorLocalizer`, тем же путём, каким её берут
/// продажа, возврат и приём аванса. Русский текст кассы уходит в журнал.
///
/// [QrSettingsProblem] при этом остаётся и не подменяется кодами: это беды
/// **формы**, найденные до всякого обращения к порту, и словарь для них у
/// экрана свой (`qrSettings*`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/core/logging/app_talker.dart';
import 'package:telepos/domain/payment/qr_provider_setup.dart';
import 'package:telepos/domain/wire/till_ops.dart'
    show qrPatienceMaxSeconds, qrPatienceMinSeconds;
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/presentation/controllers/sale/sale_refusal_keys.dart';

/// Беды формы — словами экрана, а не текстом исключения.
enum QrSettingsProblem {
  invalidUrl,
  codeRequired,
  invalidPatience,
  saveFailed,
}

class QrPaymentSetupState {
  const QrPaymentSetupState({
    this.loading = true,
    this.saving = false,
    this.available = true,
    this.view,
    this.problem,
    this.refusalKey,
  });

  final bool loading;
  final bool saving;

  /// Порт заведён в этой сборке. `false` — настройку провайдера здесь делать
  /// нечем: сборка без контейнера или без привязки порта.
  ///
  /// **С 2026-09-18 это больше не «не касса».** У браузерного терминала порт
  /// есть — `WtQrProviderSetup` поверх провода, — и отсутствие привязки стало
  /// тем, чем и должно быть: ошибкой сборки, а не режимом работы.
  final bool available;

  final QrProviderView? view;
  final QrSettingsProblem? problem;

  /// Ключ `ErrorLocalizer` под названный отказ порта — или `null`.
  ///
  /// Отдельно от [problem], а не вместо: [problem] — беда формы, найденная
  /// экраном до обращения к кассе, и её фразы лежат в собственных ключах
  /// экрана. Здесь же — то, что сказала **касса**, и сказала кодом.
  final String? refusalKey;

  QrPaymentSetupState copyWith({
    bool? loading,
    bool? saving,
    bool? available,
    QrProviderView? view,
    QrSettingsProblem? problem,
    String? refusalKey,
    bool clearProblem = false,
  }) => QrPaymentSetupState(
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    available: available ?? this.available,
    view: view ?? this.view,
    problem: clearProblem ? null : (problem ?? this.problem),
    refusalKey: clearProblem ? null : (refusalKey ?? this.refusalKey),
  );
}

class QrPaymentSetupController extends Notifier<QrPaymentSetupState> {
  /// Границы ожидания оплаты. Меньше полуминуты покупатель не успеет открыть
  /// банк; больше получаса — касса держит чек «ждёт QR» дольше смены
  /// кассира у кассы.
  ///
  /// **Числа не свои, а кассины** (`till_ops.dart`): с 2026-09-18 те же
  /// границы обязана держать касса — кадр можно собрать и мимо экрана, —
  /// и два набора чисел разошлись бы на первой же правке. Проверка здесь
  /// избавляет от круга, запрет держит касса.
  static const minPatienceSeconds = qrPatienceMinSeconds;
  static const maxPatienceSeconds = qrPatienceMaxSeconds;

  QrProviderSetupRepository? get _repo =>
      GetIt.I.isRegistered<QrProviderSetupRepository>()
      ? GetIt.I<QrProviderSetupRepository>()
      : null;

  @override
  QrPaymentSetupState build() => const QrPaymentSetupState();

  /// Отказ порта → состояние, в котором у беды есть имя.
  ///
  /// Названный отказ кассы ([WireRefusal]) едет ключом словаря; всё прочее
  /// (падение обработчика, обрыв провода без кода, отказ базы) остаётся
  /// [QrSettingsProblem.saveFailed] — у него нет кода, и выдумывать его
  /// нельзя. Текст исключения в журнал идёт через `safeErrorText`: в нём мог
  /// оказаться довод.
  QrPaymentSetupState _refused(Object error) {
    if (error is WireRefusal) {
      talker.warning('QR settings refused: ${error.code} ${error.message}');
      return state.copyWith(
        loading: false,
        saving: false,
        refusalKey: saleRefusalErrorKeyOf(error),
      );
    }
    talker.warning('QR settings failed: ${safeErrorText(error)}');
    return state.copyWith(
      loading: false,
      saving: false,
      problem: QrSettingsProblem.saveFailed,
    );
  }

  Future<void> load() async {
    final repo = _repo;
    if (repo == null) {
      state = const QrPaymentSetupState(loading: false, available: false);
      return;
    }
    state = state.copyWith(loading: true, clearProblem: true);
    try {
      state = QrPaymentSetupState(loading: false, view: await repo.read());
    } catch (error) {
      // До 2026-09-18 чтения без `try` хватало: под портом стояла своя же
      // база. С проводом у чтения появились отказы — нет права, нет стойки,
      // оборвана связь, — и непойманное исключение оставляло экран
      // крутящимся вечно, ничего не сказав.
      state = _refused(error);
    }
  }

  /// Проверить форму и сохранить. `true` — сохранено.
  Future<bool> save({
    required String baseUrl,
    required String code,
    required String patienceSeconds,
    String? newApiKey,
    bool clearApiKey = false,
  }) async {
    final repo = _repo;
    if (repo == null) return false;

    final url = Uri.tryParse(baseUrl.trim());
    if (url == null ||
        !(url.scheme == 'http' || url.scheme == 'https') ||
        url.host.isEmpty) {
      state = state.copyWith(problem: QrSettingsProblem.invalidUrl);
      return false;
    }
    if (code.trim().isEmpty) {
      state = state.copyWith(problem: QrSettingsProblem.codeRequired);
      return false;
    }
    final seconds = int.tryParse(patienceSeconds.trim());
    if (seconds == null ||
        seconds < minPatienceSeconds ||
        seconds > maxPatienceSeconds) {
      state = state.copyWith(problem: QrSettingsProblem.invalidPatience);
      return false;
    }

    state = state.copyWith(saving: true, clearProblem: true);
    try {
      await repo.save(
        baseUrl: baseUrl,
        code: code,
        patience: Duration(seconds: seconds),
        newApiKey: newApiKey,
        clearApiKey: clearApiKey,
      );
      state = QrPaymentSetupState(loading: false, view: await repo.read());
      return true;
    } catch (error) {
      state = _refused(error);
      return false;
    }
  }

  Future<void> setKindActive(bool active) async {
    final repo = _repo;
    if (repo == null) return;
    state = state.copyWith(saving: true, clearProblem: true);
    try {
      await repo.setKindActive(active);
      state = QrPaymentSetupState(loading: false, view: await repo.read());
    } catch (error) {
      state = _refused(error);
    }
  }

  Future<void> clear() async {
    final repo = _repo;
    if (repo == null) return;
    state = state.copyWith(saving: true, clearProblem: true);
    try {
      await repo.clear();
      state = QrPaymentSetupState(loading: false, view: await repo.read());
    } catch (error) {
      state = _refused(error);
    }
  }
}

final qrPaymentSetupControllerProvider =
    NotifierProvider<QrPaymentSetupController, QrPaymentSetupState>(
      QrPaymentSetupController.new,
    );
