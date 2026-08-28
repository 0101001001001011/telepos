/// Zenoh for Dart: publish, subscribe and liveliness for a fleet that spends
/// part of its life offline.
///
/// ## What this is
///
/// A binding over a small Rust crate (`rust/`) that wraps the **stable
/// subset** of Zenoh 1.9 and exposes a C ABI. The crate is deliberately narrow:
/// roughly thirty functions instead of the C API's eight hundred, one
/// ownership rule instead of a hundred and twenty-six typedefs, and every
/// enum crossing by name.
///
/// ## What is missing, and why you should care
///
/// **Advanced Pub/Sub is absent.** The cache, history for late joiners, miss
/// detection and recovery are all behind Zenoh's `unstable` feature, and this
/// package does not enable it. That is exactly the offline story, so it has to
/// be built above this package: durable state belongs in a database that
/// replicates, and this fabric carries what is happening now. A subscriber
/// that was not listening did not miss a message — there was no message for
/// it.
///
/// Also absent for the same reason: per-message reliability
/// (`zenoh::qos::Reliability` is unstable) and liveliness history.
///
/// **Zenoh does not traverse NAT.** It scouts on a LAN and gossips once it has
/// an entry point, and it expects the endpoints it is given to be routable.
/// Reaching a till behind someone else's router is the relay's job.
///
/// ## The Zenoh ID is not an address
///
/// A recreated session gets a new Zenoh ID, and messages sent to the old one
/// are accepted and delivered nowhere. This package makes the choice explicit
/// through [ZenohIdentity], and refuses a pinned ID without TLS, because
/// whoever claims a pinned ID first keeps it. See `doc/stale-zid.md` for the
/// measurements behind both statements.
///
/// ## Example
///
/// ```dart
/// final session = await ZenohSession.open(ZenohConfig(
///   mode: SessionMode.peer,
///   connect: ['tcp/127.0.0.1:7447'],
/// ));
/// final alive = await session.declareLiveliness('telepos/alive/till-17');
/// final orders = await session.subscribe('telepos/till/till-17/cmd');
/// orders.samples.listen((s) => print('${s.key}: ${s.text}'));
/// await session.put('telepos/shop/3/heartbeat', utf8.encode('ok'));
/// await alive.close();
/// await session.close();
/// ```
///
/// Nothing here runs on the calling isolate: every native call is made on a
/// worker isolate this package owns.
library;

export 'src/config.dart';
export 'src/library.dart'
    show RkzLibraryNotFound, defaultLibraryFileName, defaultLibrarySearchPaths;
export 'src/session.dart';
export 'src/status.dart';
