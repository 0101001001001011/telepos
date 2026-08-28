import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:telepos/app/theme/telepos_icons.dart';
import 'package:telepos/core/locale/app_locale.dart';
import 'package:telepos/core/locale/locale_provider.dart';
import 'package:telepos/l10n/app_localizations.dart';

class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({super.key, this.color});

  final Color? color;

  static String _shortLabel(AppLocale locale) {
    return switch (locale) {
      AppLocale.ru => 'RU',
      AppLocale.en => 'EN',
      AppLocale.kk => 'ҚАЗ',
      AppLocale.ky => 'КЫР',
      AppLocale.uz => 'UZ',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
    final effectiveColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return PopupMenuButton<AppLocale>(
      tooltip: AppLocalizations.of(context)!.languageSwitcherTooltip,
      onSelected: (locale) {
        ref.read(localeProvider.notifier).setLocale(locale);
      },
      itemBuilder: (context) => [
        for (final locale in AppLocale.values)
          PopupMenuItem<AppLocale>(
            value: locale,
            child: Row(
              children: [
                Text(locale.flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Text(locale.nativeName),
                if (locale == current) ...[
                  const Spacer(),
                  const Icon(TeleposIcons.check, size: 18),
                ],
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language, size: 20, color: effectiveColor),
            const SizedBox(width: 4),
            Text(
              _shortLabel(current),
              style: TextStyle(
                color: effectiveColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
