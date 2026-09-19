import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/payment/payment_intent.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// **Деньги без чека** — оплаченные намерения QR, которыми ни один чек не
/// закрыт.
///
/// # Почему на ЭТОМ экране, а не на своём
///
/// Потому что беда та же: **деньги взяты, документа нет**. Кассир,
/// разбирающий нефискализованные чеки, разбирает ровно этот класс, и
/// заводить ему второй экран под второе имя одной беды значило бы
/// поделить его внимание пополам. Спека говорит это прямо: намерение в
/// состоянии `paid`, чей чек не завершён, показывается **на том же экране
/// разбора**, что и нефискальные чеки.
///
/// # Что здесь можно сделать, и почему только это
///
/// **Спросить провайдера ещё раз** — и всё. Ни «списать», ни «закрыть
/// чеком» отсюда нет, и оба отсутствуют по разным причинам:
///
/// * **Списать** значило бы объявить чужие деньги несуществующими. У
///   нефискального чека списание законно (документа нет, деньги есть и
///   записаны); здесь наоборот — деньги есть, а записи нет, и «списать»
///   стёрло бы единственный след.
/// * **Закрыть чеком** — это продажа, а продажа делается на экране
///   продажи, с товаром, с фискализацией и с правом. Кнопка «сделать чек»
///   на экране разбора была бы второй, укороченной продажей, и первая же
///   разница между ними стала бы дефектом.
///
/// Строка остаётся видимой, пока чек её не закроет или пока провайдер не
/// скажет, что денег нет.
class OrphanQrMoneyPanel extends ConsumerWidget {
  const OrphanQrMoneyPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orphanQrMoneyProvider);
    return async.when(
      data: (intents) {
        if (intents.isEmpty) return const SizedBox.shrink();
        return _Panel(intents: intents);
      },
      // Загрузка молчит: мигать полосой на каждом открытии экрана значит
      // научить кассира её не замечать — и тогда она перестанет работать
      // и для настоящей беды.
      loading: () => const SizedBox.shrink(),
      // **Ошибка говорит.** Спросить не удалось — не то же самое, что
      // «нечего разбирать», и молчание здесь было бы вторым способом
      // потерять деньги покупателя с экрана.
      error: (e, _) => _Unknown(reason: '$e'),
    );
  }
}

/// Оплаченные намерения без чека.
///
/// Читает **базу кассы**, а не провайдера: провайдер отвечает про одно
/// намерение, а вопрос здесь — «что осталось неразобранным», и ответ на
/// него у нас.
/// **Пустой список здесь означает «денег без чека нет», и ничто другое.**
///
/// Первая редакция отвечала `const []`, когда база не зарегистрирована, —
/// и это ровно тот класс дефекта, ради которого в дереве есть отдельный
/// проход проверки: правдоподобное значение, возвращённое молча.
/// Несобранная касса выглядела бы как касса, у которой всё разобрано, и
/// деньги покупателя пропали бы с экрана без единого слова.
///
/// Теперь отсутствие базы — **ошибка с названной причиной**, и панель её
/// показывает (см. [OrphanQrMoneyPanel.build]).
final orphanQrMoneyProvider =
    FutureProvider.autoDispose<List<PaymentIntent>>((ref) async {
      if (!GetIt.I.isRegistered<AppDatabase>()) {
        throw StateError(
          'база кассы не зарегистрирована — неразобранные деньги по QR '
          'спросить не у кого',
        );
      }
      return GetIt.I<AppDatabase>().paymentIntentDao.orphanMoney();
    });

/// «Спросить не удалось» — **не** «разбирать нечего».
class _Unknown extends StatelessWidget {
  const _Unknown({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.error),
      ),
      child: Row(
        children: [
          Icon(Icons.qr_code_2, size: 18, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reason,
              style: TextStyle(fontSize: 12, color: scheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.intents});

  final List<PaymentIntent> intents;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_2, size: 18, color: scheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.qrOrphanTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: scheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.qrOrphanHint,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (final intent in intents) _OrphanLine(intent: intent),
        ],
      ),
    );
  }
}

class _OrphanLine extends StatelessWidget {
  const _OrphanLine({required this.intent});

  final PaymentIntent intent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.qrOrphanLine(
              // Деньги — строкой десятичного числа, как везде (I159).
              intent.money.toString(),
              intent.providerCode,
              intent.intentKey,
            ),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          if (intent.isPaidAfterGiveUp)
            Text(
              l10n.qrOrphanAfterGiveUp,
              style: TextStyle(fontSize: 11, color: AppColors.warning),
            ),
          if (intent.isPartial)
            Text(
              l10n.qrPaidPartial(
                intent.money.toString(),
                intent.amount.toString(),
              ),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
