class ServiceOrderPhotoEntity {
  const ServiceOrderPhotoEntity({
    this.id,
    required this.serviceOrderId,
    required this.filePath,
    required this.photoType,
    required this.createdAt,
    this.mediaType = 0,
  });

  final int? id;
  final int serviceOrderId;
  final String filePath;

  final int photoType;

  final int mediaType;
  final int createdAt;

  bool get isIntakePhoto => photoType == 0;
  bool get isDeliveryPhoto => photoType == 1;
  bool get isRepairMedia => photoType == 2;
  bool get isVideo => mediaType == 1;
}
