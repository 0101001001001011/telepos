enum SystemChannelType {
  posSystem('POS-System', 'System events from all POS terminals'),

  posSales('POS-Sales', 'Real-time sales feed'),

  posAlerts('POS-Alerts', 'Critical alerts and notifications'),

  posReports('POS-Reports', 'Daily and shift reports'),

  posSync('POS-Sync', 'Data synchronization status'),

  posFiscal('POS-Fiscal', 'Fiscal events (OFD/WebKassa)'),

  staffChat('Staff-Chat', 'Staff internal chat'),

  posDataExchange('POS-DataExchange', 'Encrypted data exchange channel'),

  posTerminalStatus('POS-Status', 'Individual POS terminal status'),

  posBackup('POS-Backup', 'Database backups channel');

  final String suffix;
  final String description;

  const SystemChannelType(this.suffix, this.description);

  String formatTitle(String storeName, [String? posId]) {
    if (this == posTerminalStatus && posId != null) {
      return '$storeName-POS-$posId-Status';
    }
    return '$storeName-$suffix';
  }

  bool get isGroup => this == staffChat;

  bool get isPerPos => this == posTerminalStatus;
}
