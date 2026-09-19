import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/domain/fiscal/fiscal_offset_settings.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:telepos/presentation/controllers/settings/fiscal_offset_settings_controller.dart';

/// Сертификат и аванс в фискальном документе — решения заказчика
/// 2026-09-14: продажа сертификата с чеком (выкл), раскладка зачёта
/// (скидкой), приём аванса с чеком (вкл).
class FiscalOffsetSettingsSection extends ConsumerWidget {
  const FiscalOffsetSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(fiscalOffsetSettingsControllerProvider);
    final settings = async.value;
    if (settings == null) {
      return async.hasError
          ? Text(l10n.fiscalOffsetSaveError)
          : const Center(child: CircularProgressIndicator());
    }

    Future<void> change(FiscalOffsetSettings next) async {
      final ok = await ref
          .read(fiscalOffsetSettingsControllerProvider.notifier)
          .change(next);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.fiscalOffsetSaveError)));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const ValueKey('fiscal-offset-certificate-sale'),
          value: settings.fiscalizeCertificateSale,
          onChanged: (v) =>
              change(settings.copyWith(fiscalizeCertificateSale: v)),
          title: Text(l10n.fiscalOffsetCertificateSale),
          subtitle: Text(l10n.fiscalOffsetCertificateSaleSubtitle),
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.primary,
        ),
        const Divider(),
        ListTile(
          title: Text(l10n.fiscalOffsetLayout),
          subtitle: Text(l10n.fiscalOffsetLayoutSubtitle),
          contentPadding: EdgeInsets.zero,
        ),
        SegmentedButton<OffsetFiscalLayout>(
          key: const ValueKey('fiscal-offset-layout'),
          segments: [
            ButtonSegment(
              value: OffsetFiscalLayout.discount,
              label: Text(l10n.fiscalOffsetLayoutDiscount),
            ),
            ButtonSegment(
              value: OffsetFiscalLayout.surchargeOnly,
              label: Text(l10n.fiscalOffsetLayoutSurchargeOnly),
            ),
          ],
          selected: {settings.offsetLayout},
          onSelectionChanged: (s) =>
              change(settings.copyWith(offsetLayout: s.single)),
        ),
        const SizedBox(height: 8),
        const Divider(),
        SwitchListTile(
          key: const ValueKey('fiscal-offset-prepayment-receipt'),
          value: settings.fiscalizePrepaymentReceipt,
          onChanged: (v) =>
              change(settings.copyWith(fiscalizePrepaymentReceipt: v)),
          title: Text(l10n.fiscalOffsetPrepaymentReceipt),
          subtitle: Text(l10n.fiscalOffsetPrepaymentReceiptSubtitle),
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.primary,
        ),
      ],
    );
  }
}
