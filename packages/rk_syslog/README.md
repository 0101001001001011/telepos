# rk_syslog

A syslog sink for Dart: **RFC 5424** framing, **RFC 5425** delivery over TLS,
and a bounded on-disk spool. The native part is Rust, bound through
`dart:ffi`.

## What this package is not

It **does not remove logging calls from your code**. Whether a class logs, what
it logs, and which of its fields are secret is decided at the call site, inside
that class. The native library sits below the contract and never sees those
classes; no wrapper over it, in any language, can reach upwards and delete that
code. Masking stays with the caller for the same reason: the package does not
know that a string is a PIN, and it does not guess.

If you came here to have less boilerplate in every class, the sink cannot give
you that, on either side of the FFI boundary. What it does give is worth having
on its own:

- records survive a crash of the process;
- a till whose collector is unreachable keeps selling at full speed: submitting
  a record never waits on the network;
- the log goes to whatever collection system the customer already runs, because
  it is in the format that system already reads.

## Example

```dart
final config = RkSyslogConfig(spoolDirectory: '/var/lib/telepos/syslog')
  ..identify(hostName: 'till-01', appName: 'telepos', procId: '$pid')
  ..facility = RkFacility.local0
  ..set('collector_scheme', 'tls')
  ..set('collector_host', 'logs.shop.example')
  ..set('tls_server_fingerprint_sha256', 'a1b2…');

final opened = RkSyslogSink.open(config);
if (opened case RkSyslogFailure(:final status, :final detail)) {
  return report(status, detail);   // a failure is a value, not an exception
}
final sink = opened.valueOrThrow();

sink.submit(
  severity: RkSeverity.informational,
  msgid: 'SALE',
  structuredData: RkStructuredData()
    ..element('sale@0').param('total', '1250.00'),
  message: 'receipt closed',
);

sink.flush();   // blocks: everything submitted is now on disk
sink.close();   // deterministic
```

## What is guaranteed

| | |
| --- | --- |
| Ordering | records leave in the order they were submitted, across a restart too |
| Delivery | **at least once**, not "exactly once" |
| Durability | begins at the on-disk spool, not at `submit` |
| Loss | never silent: see the spool rule below |
| Blocking | `submit` waits on neither network nor disk; only `flush` waits, and only for whoever called it |

**Why not "exactly once".** The spool cursor moves after the write to the
socket. A machine that dies between the write and saving the cursor will send
the record again. The opposite order would turn that same window into a loss,
and for a log a duplicate is an inconvenience while a hole is a defect. There
is nothing to make this exact with: RFC 5425 has no application-level
acknowledgement.

## The spool rule, and what it costs

The spool is bounded in bytes. Something has to give when the bound is reached,
and the rule is chosen at open time:

| `spool_policy` | What happens | The cost |
| --- | --- | --- |
| `drop_oldest` (default) | the **oldest segment is deleted whole** | those records are gone for good, and the granularity is a segment — up to `spool_segment_bytes` at a time, not one record. A `spool_dropped_records` counter is left behind, and **a record is written in place of the deleted ones** saying how many there were |
| `reject` | nothing is deleted | the failure moves to the caller: `submit` returns `spoolFull` and the record stays with them. For audit and security, where a discarded record is a defect and the caller has durable storage of their own |

The bound is checked **on the write path**, on every append. No timer, no
sweeper: a retention rule that depends on somebody remembering to start it will
one day not run.

## Three logs

| Log | `facility` | `spool_policy` |
| --- | --- | --- |
| Technical | `local0` | `drop_oldest` |
| Audit | `audit` (13) | `reject` |
| Security | `authpriv` (10) | `reject` |

## Settings

Set by name. A key the library does not know is a **failure**
(`unknownConfigKey`), not a silent no-op: `spool_max_byte` will stop the sink
from opening, rather than leave the bound at its default and let the disk fill
up six months later.

| Key | Default | |
| --- | --- | --- |
| `spool_dir` | — | required |
| `host_name`, `app_name`, `proc_id` | `-` | header fields; validated once, at open |
| `facility` | `local0` | by name |
| `spool_max_bytes` | `67108864` | 64 MiB |
| `spool_segment_bytes` | `1048576` | 1 MiB — also the granularity of loss |
| `spool_policy` | `drop_oldest` | `drop_oldest` \| `reject` |
| `queue_max_records` | `4096` | the loss window if the process crashes |
| `queue_policy` | `reject` | `drop_oldest` \| `reject` |
| `collector_scheme` | `none` | `none` \| `tls` \| `tcp` |
| `collector_host` | — | |
| `collector_port` | `6514` | |
| `tls_server_name` | = `collector_host` | SNI, and the name verified against |
| `tls_roots_pem` | — | path to a root bundle |
| `tls_server_fingerprint_sha256` | — | pinning, with or without colons |
| `tls_client_cert_pem`, `tls_client_key_pem` | — | mutual TLS; only together |
| `max_message_bytes` | `8192` | RFC 5425 §4.2 asks for 8192 to be supported |
| `oversize` | `truncate` | `truncate` \| `reject` |
| `msg_bom` | `true` | byte-order mark before MSG, RFC 5424 §6.4 |
| `connect_timeout_ms`, `write_timeout_ms` | `5000` | |
| `retry_min_ms`, `retry_max_ms` | `500`, `30000` | doubling up to the limit |

**Closed by default.** `collector_scheme` is `none`: a fresh installation opens
nothing outward. And the package carries no root store: a customer's collector
is usually signed by their own certificate authority, so a sink that silently
trusted the public roots would be trusting the wrong set. Either a bundle or a
fingerprint — otherwise it does not open.

`tcp` is **not RFC 5425**: no encryption, and no verification of the other
side. It exists because a collector on the same machine is a real deployment,
and because the framing has to be testable without a certificate. Anything
leaving the machine wants `tls`.

## Counters

Read by name; an unknown name gives `unknownStat` rather than zero — "not
measured" and "measured, and zero" are different answers.

`submitted`, `framing_refused`, `truncated`, `queue_refused`, `queue_dropped`,
`queue_depth`, `spooled`, `spool_refused`, `spool_dropped_records`,
`spool_dropped_segments`, `spool_torn_records`, `spool_bytes`, `spool_records`,
`spool_io_failures`, `sent`, `send_failures`, `connected`.

## Rules worth knowing

- **A failure is a value.** Nothing here throws when the native part
  fails; see `RkSyslogResult`. A panic across the boundary is caught and
  arrives as `panicked`.
- **Not on the interface isolate.** Every call in here is a call into
  foreign code.
- **`close()` is mandatory.** Dart's garbage collector knows nothing
  about the spool, the worker thread, or the socket.
- **Enumerations cross the boundary by name.**
  `RkSyslogSink.verifyNameTables()` checks the package's tables against those
  of the loaded library, rather than assuming they match.

## Building the native part

```
cd rust && cargo build --release
```

An ordinary `cdylib`/`staticlib` with a C ABI and no build script. The binding
finds it through `RK_SYSLOG_LIB` or next to the executable.

The package is a **Flutter FFI plugin**: `flutter build` invokes cargo itself
and puts the library in the application, on Windows, Linux and Android. The
mechanism, the three separate routes to cargo, and the order to check things in
on a Mac are in [`doc/native-build.md`](doc/native-build.md). There is no
`hook/` directory here and there will not be: its mere presence breaks
`dart run`, `dart test` and `flutter build`.

`panic = "abort"` must not be set: the boundary catches panics so that a
failure reaches the caller as a value, and aborting the process makes that
promise a lie.

**Where the library is proved to arrive:**

| Target | State | Evidence |
| --- | --- | --- |
| Windows | arrives | `rk_syslog.dll` next to the runner of a built application |
| Linux | arrives | `librk_syslog.so` in the application's `bundle/lib/` |
| Android | arrives | found **inside the unpacked APK** for `armeabi-v7a`, `arm64-v8a`, `x86_64` |
| macOS, iOS | **built and linked** | verified 2026-08-03 on Apple M4 / macOS 26.2 / Xcode 26.2: the archive builds for arm64 and x86_64 on macOS, arm64 on device and both on the simulator; a C probe links against it with `-force_load` in Release and Debug, and the macOS binaries run through the C ABI. Gated by CI from that day. |

## License

MIT, Rob Kim. See `LICENSE`.
