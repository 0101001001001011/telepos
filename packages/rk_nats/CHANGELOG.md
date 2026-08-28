## 0.2.2

- macOS and iOS actually build now. The pod script phase shipped with CRLF line endings and exited 0 without invoking cargo, the macOS link needs Security and CoreFoundation which the podspec did not name, and the Dart loader asked for a dylib that is never produced. All fixed and verified on a Mac.

## 0.2.1

- Documentation is now in English throughout: README, CHANGELOG, CONTRIBUTING, SECURITY, doc/ and both examples. The example in example/example.md was also stale — it called rkNatsVersion and hasNativeConnection, which have not existed since 0.1.0 — and now shows the real API. The README no longer attributes the 4,137 msg/s figure to ackIsMemoryOnly: that number is the async persist mode, and a memory-storage stream was never benchmarked.

## 0.2.0

- The package became a Flutter FFI plugin: `flutter build` now invokes cargo itself and puts the library into the application on Windows, Linux and Android. Before this there was no `flutter.plugin.platforms` block in the pubspec, and the native side reached no build at all. macOS and iOS are written but have never been built.

## 0.1.0

- A working client instead of a claimed name: connecting, streams, publishing,
  durable consumers, acknowledgement.
- **The durability contract.** The default policy is `fsyncOnAck`: an
  acknowledgement means "flushed to disk", and publishing is refused until that
  is proven. Weaker settings exist, each has a name that is visible in the
  consumer's source, and **every acknowledgement reports what it meant**.
- Refusal of a server stream in `persist_mode: async` under the safe policy — it
  acknowledges before the write even where the server fsyncs every write.
- Proof of the server's properties comes from `varz`: the document is either
  passed in by the caller or requested by the library through the system
  account. No proof means refusal, not an assumption.
- `messageId` turns on server-side duplicate detection, so republishing does not
  become a second sale.
- Failures come back as values; a panic on the native side is caught at the
  boundary and turned into a code. Enums cross the boundary by name.

## 0.0.1

- Name claimed. No content yet: the package exercises the publishing pipeline
  rather than solving the problem.
