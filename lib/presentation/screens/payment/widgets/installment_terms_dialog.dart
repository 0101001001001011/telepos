import 'package:flutter/material.dart';

import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/domain/payment/installment_scheduler.dart';
import 'package:telepos/l10n/app_localizations.dart';

/// Что кассир выбрал для рассрочки: срок и схема.
@immutable
class InstallmentTerms {
  const InstallmentTerms({required this.termMonths, required this.scheme});

  final int termMonths;
  final InstallmentScheme scheme;
}

/// Срок и схема рассрочки — спрашиваются **до** выбора вида оплаты.
///
/// # Почему до, а не после
///
/// Касса отвергает рассрочку без срока названным отказом
/// (`credit_term_invalid`). Спроси экран после — и кассир получил бы отказ
/// за то, чего у него не спросили: он нажал кнопку, набрал первый взнос,
/// нажал «Оплатить» и услышал «срок не назван».
///
/// # Список берётся у домена, а не выписан здесь
///
/// [InstallmentScheduler.allowedTerms] — то же самое, чем меряет касса.
/// Второй список рядом разошёлся бы с первым молча: экран предлагал бы
/// срок, который касса не принимает, и это выглядело бы поломкой кассы.
///
/// То же и со схемами: перебираются `InstallmentScheme.values`, а не три
/// выписанные кнопки. Новая схема появится здесь сама.
///
/// # Слова — из словаря (2026-09-15)
///
/// Заголовок, подписи и кнопки были литералами по-русски (обход группы F,
/// проба `test/presentation/dialogs/payment_dialogs_text_test.dart`). Имя
/// схемы по-прежнему у домена — см. комментарий у `RadioListTile`.
Future<InstallmentTerms?> showInstallmentTermsDialog(
  BuildContext context,
) => showDialog<InstallmentTerms>(
  context: context,
  builder: (_) => const _InstallmentTermsDialog(),
);

class _InstallmentTermsDialog extends StatefulWidget {
  const _InstallmentTermsDialog();

  @override
  State<_InstallmentTermsDialog> createState() =>
      _InstallmentTermsDialogState();
}

class _InstallmentTermsDialogState extends State<_InstallmentTermsDialog> {
  int _term = InstallmentScheduler.allowedTerms.first;
  InstallmentScheme _scheme = InstallmentScheme.equalInstalments;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      key: const Key('installment_terms_dialog'),
      title: Text(l10n.installmentTermsTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.installmentTermsMonths),
          const SizedBox(height: AppTheme.spacingSmall),
          Wrap(
            spacing: AppTheme.spacingSmall,
            children: [
              for (final term in InstallmentScheduler.allowedTerms)
                ChoiceChip(
                  key: Key('installment_term_$term'),
                  label: Text('$term'),
                  selected: _term == term,
                  onSelected: (_) => setState(() => _term = term),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing),
          Text(l10n.installmentTermsScheme),
          const SizedBox(height: AppTheme.spacingSmall),
          for (final scheme in InstallmentScheme.values)
            RadioListTile<InstallmentScheme>(
              key: Key('installment_scheme_${scheme.code}'),
              contentPadding: EdgeInsets.zero,
              value: scheme,
              groupValue: _scheme,
              // Имя схемы берётся у домена (`InstallmentScheme.label`), а
              // не выписано здесь: печатная форма договора называет её тем
              // же словом, и два списка названий разошлись бы молча — кассир
              // выбрал бы одно, покупатель подписал бы другое.
              title: Text(scheme.label),
              onChanged: (v) => setState(() => _scheme = v ?? _scheme),
            ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('installment_terms_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.globalCancel),
        ),
        FilledButton(
          key: const Key('installment_terms_confirm'),
          onPressed: () => Navigator.of(context).pop(
            InstallmentTerms(termMonths: _term, scheme: _scheme),
          ),
          child: Text(l10n.installmentTermsContinue),
        ),
      ],
    );
  }
}
