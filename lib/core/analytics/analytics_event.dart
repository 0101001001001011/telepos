enum AnalyticsEventType {
  appStart('app_start'),
  appClose('app_close'),
  appBackground('app_background'),
  appForeground('app_foreground'),

  login('login'),
  logout('logout'),
  loginFailed('login_failed'),
  switchUser('switch_user'),

  shiftOpen('shift_open'),
  shiftClose('shift_close'),
  shiftXReport('shift_x_report'),
  shiftZReport('shift_z_report'),

  saleStart('sale_start'),
  saleAddItem('sale_add_item'),
  saleRemoveItem('sale_remove_item'),
  saleDiscount('sale_discount'),
  saleHold('sale_hold'),
  saleRecall('sale_recall'),
  saleComplete('sale_complete'),
  saleCancelled('sale_cancelled'),

  refundStart('refund_start'),
  refundComplete('refund_complete'),
  refundCancelled('refund_cancelled'),

  paymentStart('payment_start'),
  paymentCash('payment_cash'),
  paymentCard('payment_card'),
  paymentKaspi('payment_kaspi'),
  paymentMixed('payment_mixed'),
  paymentComplete('payment_complete'),
  paymentFailed('payment_failed'),

  agentCreate('agent_create'),
  agentEdit('agent_edit'),
  agentSelect('agent_select'),

  cashInvestment('cash_investment'),
  cashExpense('cash_expense'),

  syncStart('sync_start'),
  syncComplete('sync_complete'),
  syncFailed('sync_failed'),
  syncConflict('sync_conflict'),

  printReceipt('print_receipt'),
  printFailed('print_failed'),

  fiscalRegister('fiscal_register'),
  fiscalSuccess('fiscal_success'),
  fiscalFailed('fiscal_failed'),

  screenView('screen_view'),

  error('error'),
  crash('crash'),

  updateCheck('update_check'),
  updateAvailable('update_available'),
  updateSkipped('update_skipped'),
  updateStarted('update_started'),
  updateComplete('update_complete'),

  custom('custom');

  const AnalyticsEventType(this.name);

  final String name;
}

class AnalyticsEvent {
  const AnalyticsEvent({required this.type, this.properties, this.timestamp});

  factory AnalyticsEvent.custom(
    String name, {
    Map<String, dynamic>? properties,
  }) {
    return AnalyticsEvent(
      type: AnalyticsEventType.custom,
      properties: {'event_name': name, ...?properties},
    );
  }

  factory AnalyticsEvent.screenView(
    String screenName, {
    Map<String, dynamic>? properties,
  }) {
    return AnalyticsEvent(
      type: AnalyticsEventType.screenView,
      properties: {'screen_name': screenName, ...?properties},
    );
  }

  factory AnalyticsEvent.error(
    String errorType, {
    String? message,
    String? stackTrace,
    Map<String, dynamic>? properties,
  }) {
    return AnalyticsEvent(
      type: AnalyticsEventType.error,
      properties: {
        'error_type': errorType,
        if (message != null) 'error_message': message,
        if (stackTrace != null) 'stack_trace': stackTrace,
        ...?properties,
      },
    );
  }

  final AnalyticsEventType type;

  final Map<String, dynamic>? properties;

  final DateTime? timestamp;

  String get eventName => type.name;

  Map<String, dynamic> toJson() {
    return {
      'event_type': eventName,
      'time': (timestamp ?? DateTime.now()).millisecondsSinceEpoch,
      if (properties != null) 'event_properties': properties,
    };
  }

  @override
  String toString() {
    return 'AnalyticsEvent($eventName, properties: $properties)';
  }
}

class AnalyticsUserProperties {
  const AnalyticsUserProperties({
    this.userId,
    this.posId,
    this.storeId,
    this.role,
    this.appVersion,
    this.platform,
    this.osVersion,
    this.language,
    this.country,
    this.custom,
  });

  final String? userId;
  final String? posId;
  final String? storeId;
  final String? role;
  final String? appVersion;
  final String? platform;
  final String? osVersion;
  final String? language;
  final String? country;
  final Map<String, dynamic>? custom;

  Map<String, dynamic> toJson() {
    return {
      if (userId != null) 'user_id': userId,
      if (posId != null) 'pos_id': posId,
      if (storeId != null) 'store_id': storeId,
      if (role != null) 'role': role,
      if (appVersion != null) 'app_version': appVersion,
      if (platform != null) 'platform': platform,
      if (osVersion != null) 'os_version': osVersion,
      if (language != null) 'language': language,
      if (country != null) 'country': country,
      ...?custom,
    };
  }
}
