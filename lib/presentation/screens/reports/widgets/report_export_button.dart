import 'package:telepos/core/platform/local_file.dart';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:telepos/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:telepos/app/theme/app_colors.dart';

class ReportExportButton extends StatelessWidget {
  const ReportExportButton({
    required this.fileName,
    required this.headers,
    required this.rows,
    super.key,
  });

  final String fileName;
  final List<String> headers;
  final List<List<dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.download, size: 18),
      tooltip: AppLocalizations.of(context)!.catalogExportCsv,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      onPressed: () => exportCsv(context, fileName, headers, rows),
    );
  }

  static Future<void> exportCsv(
    BuildContext context,
    String fileName,
    List<String> headers,
    List<List<dynamic>> rows,
  ) async {
    try {
      final csvData = [headers, ...rows];
      final csvString = const ListToCsvConverter().convert(csvData);

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final filePath = '${dir.path}/${fileName}_$timestamp.csv';
      await writeLocalString(filePath, '\uFEFF$csvString');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.repExportedTo(filePath),
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.repExportFailed('$e')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
