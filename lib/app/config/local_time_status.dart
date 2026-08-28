enum TimeCheckStatus { ok, undefined, wrong }

class LocalTimeStatus {
  const LocalTimeStatus._({
    required this.status,
    this.referenceTime,
    this.localTime,
  });

  const LocalTimeStatus.ok()
    : status = TimeCheckStatus.ok,
      referenceTime = null,
      localTime = null;

  const LocalTimeStatus.undefined()
    : status = TimeCheckStatus.undefined,
      referenceTime = null,
      localTime = null;

  LocalTimeStatus.wrong({
    required DateTime referenceTime,
    required DateTime localTime,
  }) : this._(
         status: TimeCheckStatus.wrong,
         referenceTime: referenceTime,
         localTime: localTime,
       );

  final TimeCheckStatus status;

  final DateTime? referenceTime;

  final DateTime? localTime;

  Duration? get timeDifference {
    if (referenceTime == null || localTime == null) return null;
    return referenceTime!.difference(localTime!);
  }

  bool get isOk => status == TimeCheckStatus.ok;

  bool get isWrong => status == TimeCheckStatus.wrong;
}
