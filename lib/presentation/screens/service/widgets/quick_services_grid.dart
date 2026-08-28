import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:telepos/app/theme/app_colors.dart';
import 'package:telepos/app/theme/app_theme.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/l10n/app_localizations.dart';

class QuickServiceItem {
  const QuickServiceItem({
    required this.ucode,
    required this.name,
    required this.price,
  });

  final int ucode;
  final String name;
  final Decimal price;
}

final quickServicesProvider = FutureProvider<List<QuickServiceItem>>((
  ref,
) async {
  final db = GetIt.I<AppDatabase>();
  final allQuick = await db.quickProductDao.findAllByParents();

  final result = <QuickServiceItem>[];
  for (final qp in allQuick) {
    if (qp.ucode == null) continue;

    final info = await db.productInfoDao.findByIdAndNotDeleted(qp.ucode!);
    if (info == null || info.type != 4) continue;

    final price = await db.productPriceDao.findByUcode(qp.ucode!);
    result.add(
      QuickServiceItem(
        ucode: qp.ucode!,
        name: qp.name ?? info.name,
        price: price?.sellingPrice ?? Decimal.zero,
      ),
    );
  }
  return result;
});

class QuickServicesGrid extends ConsumerWidget {
  const QuickServicesGrid({
    required this.onServiceTap,
    this.crossAxisCount = 3,
    this.compact = false,
    super.key,
  });

  final void Function(QuickServiceItem item) onServiceTap;
  final int crossAxisCount;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final servicesAsync = ref.watch(quickServicesProvider);

    return servicesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (services) {
        if (services.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.flash_on,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.serviceQuickServicesTitle,
                    style: context.styles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                  childAspectRatio: compact ? 2.0 : 1.6,
                ),
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final item = services[index];
                  return _QuickServiceButton(
                    name: item.name,
                    price: item.price,
                    compact: compact,
                    onTap: () => onServiceTap(item),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickServiceButton extends StatelessWidget {
  const _QuickServiceButton({
    required this.name,
    required this.price,
    required this.onTap,
    this.compact = false,
  });

  final String name;
  final Decimal price;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '$price',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
