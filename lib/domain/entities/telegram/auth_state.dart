import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_state.freezed.dart';

@freezed
sealed class TelegramAuthState with _$TelegramAuthState {
  const factory TelegramAuthState.initial() = TelegramAuthStateInitial;

  const factory TelegramAuthState.waitingPhoneNumber() =
      TelegramAuthStateWaitingPhoneNumber;

  const factory TelegramAuthState.waitingQrCode({
    required String qrCodeLink,
    required DateTime expiresAt,
  }) = TelegramAuthStateWaitingQrCode;

  const factory TelegramAuthState.waitingCode({
    required String phoneNumber,
    required String codeType,
    int? codeLength,
  }) = TelegramAuthStateWaitingCode;

  const factory TelegramAuthState.waitingPassword({
    required String passwordHint,
    required bool hasRecoveryEmail,
  }) = TelegramAuthStateWaitingPassword;

  const factory TelegramAuthState.waitingRegistration() =
      TelegramAuthStateWaitingRegistration;

  const factory TelegramAuthState.waitingIdentityVerification({
    required List<IdentityDocumentType> requiredDocuments,
    String? reason,
  }) = TelegramAuthStateWaitingIdentityVerification;

  const factory TelegramAuthState.verifyingDocuments({
    required List<String> submittedDocumentPaths,
    required DocumentVerificationStatus status,
  }) = TelegramAuthStateVerifyingDocuments;

  const factory TelegramAuthState.authorized({
    required int userId,
    required String firstName,
    String? lastName,
    String? phoneNumber,
    String? username,
  }) = TelegramAuthStateAuthorized;

  const factory TelegramAuthState.error({
    required String message,
    int? code,
    TelegramAuthState? previousState,
  }) = TelegramAuthStateError;

  const factory TelegramAuthState.loggedOut() = TelegramAuthStateLoggedOut;
}

enum IdentityDocumentType {
  passport,

  identityCard,

  driverLicense,

  selfieWithDocument,

  facePhoto,

  taxId,
}

enum DocumentVerificationStatus {
  pending,

  submitted,

  inReview,

  approved,

  rejected,

  additionalRequired,
}
