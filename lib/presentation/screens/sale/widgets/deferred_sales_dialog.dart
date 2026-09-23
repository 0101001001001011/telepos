import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/core/errors/named_refusal.dart';
import 'package:telepos/core/errors/safe_error_text.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/common/utils/error_localizer.dart';
import 'package:telepos/presentation/controllers/sale/sale_controller.dart';

/// Список отложенных чеков — общий пул кассы (решение 3 заказчика,
/// задача 17 плана «Продажа с браузерного терминала»).
///
/// # Что в этом списке есть и чего в нём нет
///
/// **Есть только отложенное.** Чек в работе — личное дело рабочего
/// места и в пул не попадает: в общий список он уходит **явным**
/// «Отложить» (решение 4 заказчика). Ни своего чека в работе, ни чужого
/// здесь не увидит никто; фильтр стоит не здесь, а у источника
/// (`LocalCartService._deferredCards` — только `state = 3` и только эта
/// касса), и проверен пробами `test/data/sale/deferred_pool_test.dart`.
///
/// **Пул общий, и подъём — гонка.** Тот же чек в тот же момент может
/// поднять сосед. Проигравший получает от кассы названный отказ
/// (`deferred_taken`), а не пустую корзину; показывает его экран продажи
/// своей строкой ошибки — этот диалог закрывается сразу, не дожидаясь
/// ответа кассы, потому что ждать его здесь значило бы держать модальное
/// окно поверх экрана, на котором и появится объяснение.
///
/// **Своей копии списка у диалога нет.** `deferredCartsProvider` — это
/// подписка на кассу (`CartService.watchDeferred`), и чек, поднятый
/// соседом, пропадает из открытого списка сам.

/// Текст отказа подписки на пул — фраза словаря, а не текст кассы.
///
/// Названный отказ (`WireRefusal` кассы, `WtProtocolError` провода — оба
/// `NamedRefusal`) едет через `safeErrorText` в `ErrorLocalizer`: код из
/// словаря показывается своей фразой («нет права» — `error.not_allowed`),
/// неизвестный — «недоступен: неизвестная причина (код …)».
///
/// # Что было до 2026-09-15
///
/// Здесь показывался `WireRefusal.message` — фраза, написанная кассой
/// по-русски для журнала, — а на всё прочее литерал «Список отложенных
/// чеков недоступен». Кассир с казахским интерфейсом читал по-русски оба.
/// Проба — `test/presentation/screens/sale/deferred_sales_dialog_text_test.dart`.
///
/// Всё прочее — неожиданность, и показывать её сырой нельзя тем же доводом,
/// каким `till_wire.dart` не кладёт в кадр текст произвольного исключения.
/// Экран `lib/web/` не импортирует: у него нет и не может быть браузерных
/// типов.
///
/// **Перенесено сюда при слиянии.** Третий круг задачи 13 чинил диалог,
/// живший телом `sale_screen.dart`; задача 17 к тому времени вынесла его
/// в этот файл. Взять правку дословно значило бы завести **второй**
/// диалог — мёртвый, но с починкой, — а взять «нашу сторону» значило бы
/// потерять починку молча. Перенесены обе: и текст отказа, и порядок
/// `hasError` перед `when` ниже.
String _deferredErrorText(BuildContext context, Object error) =>
    error is NamedRefusal
    ? ErrorLocalizer.localize(
        context,
        'error.deferred_list_unavailable:${safeErrorText(error)}',
      )
    : AppLocalizations.of(context)!.errorDeferredListUnavailable;

/// «600.00 · Айгуль · Молоко 1л» — сумма, кассир, первый товар. Пустые
/// части опускаются: у чека, отложенного до появления пользователя в
/// `Users`, имени нет, а первого товара нет у чека, отложенного пустым.
String _deferredSubtitle(DeferredCart cart, AppLocalizations l10n) {
  final parts = <String>[cart.total.toStringAsFixed(2)];
  // Корзина соседней кассы помечается ЯВНО, и решает это касса
  // (`DeferredCart.foreign`), а не экран: своего номера кассы экран не
  // знает. Без пометки кассир видит чужой чек как свой и не понимает,
  // почему подъём отказывается без связи.
  if (cart.foreign) parts.add(l10n.deferredFromTill('${cart.posId}'));
  final user = cart.userName;
  if (user != null && user.trim().isNotEmpty) parts.add(user.trim());
  final firstLine = cart.firstLineName;
  if (firstLine != null && firstLine.trim().isNotEmpty) {
    parts.add(firstLine.trim());
  }
  return parts.join(' · ');
}

class DeferredSalesDialog extends ConsumerWidget {
  const DeferredSalesDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final deferredAsync = ref.watch(deferredCartsProvider);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.history, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(l10n.actionDeferredList),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 300,
        // `hasError` **раньше** `when`, и это не стилистика.
        //
        // Отказ подписки приходит сюда не только как `AsyncError`: Riverpod
        // держит подписку живой и после ошибки, и состояние выходит
        // `AsyncLoading(error: …)` — то есть `when` уводит в ветку `loading`,
        // а кассир смотрит в **вечный кружок**. Измерено на сеансе без
        // `op.deferSale` (подписка на пул закрыта им нарочно — пул отдаёт
        // весь список кассы вместе с именами кассиров): диалог открывался,
        // кадр `sale.deferredList` уходил снова и снова, а на экране не
        // менялось ничего.
        //
        // Кружок без конца хуже названного отказа ровно тем, что не
        // заканчивается: кассир ждёт, а ждать нечего.
        child: deferredAsync.hasError
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing),
                  child: Text(
                    _deferredErrorText(context, deferredAsync.error!),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              )
            : deferredAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                // Отказ — названной причиной, а не `toString()` протокола.
                //
                // **Это внутри задачи 13, а не вне её.** Её собственный пункт —
                // «отказ кассы доезжает до кассира названным», и восемь ключей
                // состояния экран этому научен показывать. Здесь был девятый путь,
                // и он рисовал `Error: WtProtocolError(forbidden: sale.deferredList:
                // нет права op.deferSale)` — код протокола, имя операции и
                // внутренний ключ права в лицо кассиру.
                //
                // Случай не выдуманный и не редкий: подписка на пул закрыта
                // `op.deferSale` намеренно (круг правки задачи 9 — пул отдаёт весь
                // список кассы вместе с именами кассиров), значит **любой кассир с
                // правом продавать и без права откладывать** видит здесь отказ. У
                // `WireRefusal` и `WtProtocolError` текст уже написан для человека
                // (И144) — показывается он, а не обёртка.
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing),
                    child: Text(
                      _deferredErrorText(context, e),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
                data: (sales) {
                  if (sales.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.saleNoDeferredSales,
                        style: AppTextStyles.body.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: sales.length,
                    itemBuilder: (context, index) {
                      final sale = sales[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.warning.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            '${sale.receiptNo}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text('${l10n.saleReceiptNo} ${sale.receiptNo}'),
                        // Пул общий для всех рабочих мест кассы (решение 3
                        // спеки), и кассир пришёл забрать **свой** чек. Кассир и
                        // первый товар различают его надёжнее суммы: два чека на
                        // одну сумму по номеру и цене неразличимы — обоснование
                        // состава в докстринге `DeferredCart`.
                        subtitle: Text(_deferredSubtitle(sale, l10n)),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.restore,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            ref
                                .read(saleControllerProvider.notifier)
                                .loadDeferredSale(
                                  sale.receiptNo,
                                  // Касса-владелец — из карточки пула:
                                  // чужой чек отличается от своего только
                                  // ею, и по номеру чека её не угадать.
                                  fromPosId: sale.posId,
                                );
                            Navigator.of(context).pop();
                          },
                        ),
                      );
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalCancel),
        ),
      ],
    );
  }
}
