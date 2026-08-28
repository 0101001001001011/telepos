/// The raw C ABI, one Dart function per exported symbol.
///
/// Nothing here interprets anything. Every function returns the native status
/// unchanged, and the layer above turns it into a value or an exception. Kept
/// separate so the translation can be tested against a real library without
/// the translation and the lookup being tangled.
library;

import 'dart:ffi';

/// An opaque native handle. Only ever passed back to the library.
typedef RkzHandle = Pointer<Void>;

// The signature aliases below are shorthand for repeated shapes, not API:
// this file lives under lib/src/ and nothing here is exported.
// ignore_for_file: public_member_api_docs

typedef StatusOut = Int32 Function(Pointer<RkzHandle>);
typedef StatusOutDart = int Function(Pointer<RkzHandle>);

typedef StatusHandle = Int32 Function(RkzHandle);
typedef StatusHandleDart = int Function(RkzHandle);

typedef StatusHandleStr = Int32 Function(RkzHandle, Pointer<Char>);
typedef StatusHandleStrDart = int Function(RkzHandle, Pointer<Char>);

typedef StatusHandleBool = Int32 Function(RkzHandle, Bool);
typedef StatusHandleBoolDart = int Function(RkzHandle, bool);

typedef StatusHandleBuf = Int32 Function(RkzHandle, Pointer<Char>, Size);
typedef StatusHandleBufDart = int Function(RkzHandle, Pointer<Char>, int);

typedef StatusHandleOut = Int32 Function(RkzHandle, Pointer<RkzHandle>);
typedef StatusHandleOutDart = int Function(RkzHandle, Pointer<RkzHandle>);

typedef StatusHandleStrOut =
    Int32 Function(RkzHandle, Pointer<Char>, Pointer<RkzHandle>);
typedef StatusHandleStrOutDart =
    int Function(RkzHandle, Pointer<Char>, Pointer<RkzHandle>);

typedef CStringOf = Pointer<Char> Function(RkzHandle);
typedef CString = Pointer<Char> Function();

/// Every symbol this package needs, resolved once.
///
/// Resolution happens in the constructor rather than lazily, so a library that
/// is the wrong build fails at load with the name of the missing symbol
/// instead of at the first call that happens to need it.
class RkzBindings {
  RkzBindings(this.library)
    : nativeVersion = library.lookupFunction<CString, CString>(
        'rkz_native_version',
      ),
      lastErrorKind = library.lookupFunction<CString, CString>(
        'rkz_last_error_kind',
      ),
      lastErrorMessage = library.lookupFunction<CString, CString>(
        'rkz_last_error_message',
      ),
      configNew = library.lookupFunction<StatusOut, StatusOutDart>(
        'rkz_config_new',
      ),
      configSetMode = library
          .lookupFunction<StatusHandleStr, StatusHandleStrDart>(
            'rkz_config_set_mode',
          ),
      configPinZid = library
          .lookupFunction<StatusHandleStr, StatusHandleStrDart>(
            'rkz_config_pin_zid',
          ),
      configPinZidDerived = library
          .lookupFunction<StatusHandleStr, StatusHandleStrDart>(
            'rkz_config_pin_zid_derived',
          ),
      configAddConnect = library
          .lookupFunction<StatusHandleStr, StatusHandleStrDart>(
            'rkz_config_add_connect',
          ),
      configAddListen = library
          .lookupFunction<StatusHandleStr, StatusHandleStrDart>(
            'rkz_config_add_listen',
          ),
      configSetExtraJson5 = library
          .lookupFunction<StatusHandleStr, StatusHandleStrDart>(
            'rkz_config_set_extra_json5',
          ),
      configSetMulticastScouting = library
          .lookupFunction<StatusHandleBool, StatusHandleBoolDart>(
            'rkz_config_set_multicast_scouting',
          ),
      configSetGossipScouting = library
          .lookupFunction<StatusHandleBool, StatusHandleBoolDart>(
            'rkz_config_set_gossip_scouting',
          ),
      configRender = library
          .lookupFunction<StatusHandleBuf, StatusHandleBufDart>(
            'rkz_config_render',
          ),
      configDrop = library.lookupFunction<StatusHandle, StatusHandleDart>(
        'rkz_config_drop',
      ),
      sessionOpen = library
          .lookupFunction<StatusHandleOut, StatusHandleOutDart>(
            'rkz_session_open',
          ),
      sessionZid = library.lookupFunction<StatusHandleBuf, StatusHandleBufDart>(
        'rkz_session_zid',
      ),
      sessionPeerZids = library
          .lookupFunction<StatusHandleBuf, StatusHandleBufDart>(
            'rkz_session_peer_zids',
          ),
      sessionPut = library
          .lookupFunction<
            Int32 Function(
              RkzHandle,
              Pointer<Char>,
              Pointer<Uint8>,
              Size,
              Pointer<Char>,
              Pointer<Char>,
            ),
            int Function(
              RkzHandle,
              Pointer<Char>,
              Pointer<Uint8>,
              int,
              Pointer<Char>,
              Pointer<Char>,
            )
          >('rkz_session_put'),
      sessionDelete = library
          .lookupFunction<StatusHandleStr, StatusHandleStrDart>(
            'rkz_session_delete',
          ),
      sessionClose = library.lookupFunction<StatusHandle, StatusHandleDart>(
        'rkz_session_close',
      ),
      sessionDrop = library.lookupFunction<StatusHandle, StatusHandleDart>(
        'rkz_session_drop',
      ),
      subscriberDeclare = library
          .lookupFunction<StatusHandleStrOut, StatusHandleStrOutDart>(
            'rkz_subscriber_declare',
          ),
      subscriberRecv = library
          .lookupFunction<
            Int32 Function(RkzHandle, Uint64, Pointer<RkzHandle>),
            int Function(RkzHandle, int, Pointer<RkzHandle>)
          >('rkz_subscriber_recv'),
      subscriberDrop = library.lookupFunction<StatusHandle, StatusHandleDart>(
        'rkz_subscriber_drop',
      ),
      sampleKey = library.lookupFunction<CStringOf, CStringOf>(
        'rkz_sample_key',
      ),
      sampleKind = library.lookupFunction<CStringOf, CStringOf>(
        'rkz_sample_kind',
      ),
      samplePayload = library
          .lookupFunction<
            Int32 Function(RkzHandle, Pointer<Pointer<Uint8>>, Pointer<Size>),
            int Function(RkzHandle, Pointer<Pointer<Uint8>>, Pointer<Size>)
          >('rkz_sample_payload'),
      sampleDrop = library.lookupFunction<StatusHandle, StatusHandleDart>(
        'rkz_sample_drop',
      ),
      publisherDeclare = library
          .lookupFunction<
            Int32 Function(
              RkzHandle,
              Pointer<Char>,
              Pointer<Char>,
              Pointer<Char>,
              Pointer<RkzHandle>,
            ),
            int Function(
              RkzHandle,
              Pointer<Char>,
              Pointer<Char>,
              Pointer<Char>,
              Pointer<RkzHandle>,
            )
          >('rkz_publisher_declare'),
      publisherPut = library
          .lookupFunction<
            Int32 Function(RkzHandle, Pointer<Uint8>, Size),
            int Function(RkzHandle, Pointer<Uint8>, int)
          >('rkz_publisher_put'),
      publisherDrop = library.lookupFunction<StatusHandle, StatusHandleDart>(
        'rkz_publisher_drop',
      ),
      livelinessDeclareToken = library
          .lookupFunction<StatusHandleStrOut, StatusHandleStrOutDart>(
            'rkz_liveliness_declare_token',
          ),
      livelinessTokenDrop = library
          .lookupFunction<StatusHandle, StatusHandleDart>(
            'rkz_liveliness_token_drop',
          ),
      livelinessDeclareSubscriber = library
          .lookupFunction<StatusHandleStrOut, StatusHandleStrOutDart>(
            'rkz_liveliness_declare_subscriber',
          );

  /// The library these symbols came from.
  final DynamicLibrary library;

  final Pointer<Char> Function() nativeVersion;
  final Pointer<Char> Function() lastErrorKind;
  final Pointer<Char> Function() lastErrorMessage;

  final StatusOutDart configNew;
  final StatusHandleStrDart configSetMode;
  final StatusHandleStrDart configPinZid;
  final StatusHandleStrDart configPinZidDerived;
  final StatusHandleStrDart configAddConnect;
  final StatusHandleStrDart configAddListen;
  final StatusHandleStrDart configSetExtraJson5;
  final StatusHandleBoolDart configSetMulticastScouting;
  final StatusHandleBoolDart configSetGossipScouting;
  final StatusHandleBufDart configRender;
  final StatusHandleDart configDrop;

  final StatusHandleOutDart sessionOpen;
  final StatusHandleBufDart sessionZid;
  final StatusHandleBufDart sessionPeerZids;
  final int Function(
    RkzHandle,
    Pointer<Char>,
    Pointer<Uint8>,
    int,
    Pointer<Char>,
    Pointer<Char>,
  )
  sessionPut;
  final StatusHandleStrDart sessionDelete;
  final StatusHandleDart sessionClose;
  final StatusHandleDart sessionDrop;

  final StatusHandleStrOutDart subscriberDeclare;
  final int Function(RkzHandle, int, Pointer<RkzHandle>) subscriberRecv;
  final StatusHandleDart subscriberDrop;

  final Pointer<Char> Function(RkzHandle) sampleKey;
  final Pointer<Char> Function(RkzHandle) sampleKind;
  final int Function(RkzHandle, Pointer<Pointer<Uint8>>, Pointer<Size>)
  samplePayload;
  final StatusHandleDart sampleDrop;

  final int Function(
    RkzHandle,
    Pointer<Char>,
    Pointer<Char>,
    Pointer<Char>,
    Pointer<RkzHandle>,
  )
  publisherDeclare;
  final int Function(RkzHandle, Pointer<Uint8>, int) publisherPut;
  final StatusHandleDart publisherDrop;

  final StatusHandleStrOutDart livelinessDeclareToken;
  final StatusHandleDart livelinessTokenDrop;
  final StatusHandleStrOutDart livelinessDeclareSubscriber;
}
