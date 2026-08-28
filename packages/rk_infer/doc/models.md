# How a model reaches a till

A model is a large binary artefact, from a few to a few hundred megabytes. There
is no place for it in a pub.dev package: pub.dev stores Dart code with metadata,
and package versioning is not designed for weights that update on a cycle of
their own. A package that assumes the model is simply there is unfinished — so
this document records where it lives, how it reaches a till that has been off
the network for hours, what pins the version, and how a bad model is rolled
back.

**None of this is invented.** The product already ships software through a
signed apt repository. A model is an artefact of the same class and travels the
same channel. A second delivery mechanism would mean a second thing to keep
correct.

---

## 1. A model is a Debian package

One package per model, with the package version equal to the model version:

```
telepos-model-visitor-counter       1.4.0
telepos-model-unscanned-item-hint   0.2.0
```

The layout on disk:

```
/opt/telepos/models/visitor-counter/
    model.manifest            ← this path is what goes into ModelRef
    visitor-counter.onnx      ← the weights
```

What this gives for free, and what apt was chosen for:

| Property | Where it comes from |
| --- | --- |
| Signed before installation | the repository key |
| Delivery to a till that is offline for hours | the package installs while the till is on the network, and then sits locally |
| Rollback without a network | the previous version stays in the apt cache |
| Staged rollout | the same mechanism as the rest of the software |
| An inventory a human can read | `dpkg -l 'telepos-model-*'` |

The inference engine (ONNX Runtime) travels the same channel the same way — as a
package that puts `libonnxruntime.so` into `/opt/telepos/lib/`. `rk_infer`
neither downloads nor contains it: it opens what is already on the machine. If
the engine is absent, that is `EngineUnavailable` with the list of paths tried,
not a crash.

---

## 2. The manifest

Beside the weights, not in the code. The format is `Key: Value`, like
`debian/control`, and that is not a matter of taste: the packages travel through
apt, and every tool in that chain already reads and writes this format.
Following the existing precedent costs one small parser; a second serialisation
format costs a second thing to keep correct.

```
# Delivered by telepos-model-visitor-counter
Model: visitor-counter
Version: 1.4.0
Task: visitorCount
Weights: visitor-counter.onnx
Weights-Sha256: 9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318
Weights-Bytes: 5312044
Input-Width: 640
Input-Height: 384
Input-Format: rgb8
Schema: 1
Min-Rk-Infer-Abi: 1
Retention-Seconds: 604800
Classes: person
Producer: telepos-model-visitor-counter 1.4.0
```

**Every** key listed is mandatory. A missing key is a refusal to load, with the
key's name in the text, rather than a default value: a default for a weight
file, an input format or a retention period is a guess passing itself off as a
fact.

`Weights` is resolved relative to the manifest's directory, so a model directory
can be moved and staged without rewriting the manifest.

### Retention is mandatory, finite, and capped

`Retention-Seconds` is mandatory, strictly greater than zero, and no more than
90 days. A manifest without it, with zero, or with anything above the cap
**does not load**. Every kind of personal data owes a declared and finite
retention period, and this is that rule as a refusal rather than a wish: a
result with no retention is a result kept forever.

The retention travels with the result (`InferenceOutput.retainUntil`) rather
than sitting in a table somewhere else. A retention rule left to one side gets
lost at the first copy.

---

## 3. The order of checks at load time

The order matters, and it is this:

1. **The manifest is present and complete** → otherwise `ModelNotFound` /
   `ManifestMalformed`, with the key's name.
2. **The schema and the minimum ABI are ones this build can handle** →
   otherwise `ModelIncompatible`. Kept separate from "malformed": those are
   different pieces of news for an operator.
3. **Retention is present, non-zero and within the cap** → otherwise
   `ManifestMalformed`.
4. **The version is the one this terminal is pinned to** (if it is pinned) →
   otherwise `ModelPinMismatch`.
5. **The weights file exists** → otherwise `ModelNotFound`. This usually means
   "apt has not finished yet" rather than "something is broken", and telling
   that apart from corruption is worth a status of its own.
6. **The length matches the declared one** → otherwise
   `ModelChecksumMismatch`. The cheap check goes first: it is free and it closes
   the common case — a truncated download — before any I/O is spent.
7. **The SHA-256 matches** → otherwise `ModelChecksumMismatch`.

The expensive part — streaming a hash over hundreds of megabytes — is done last,
and only after everything cheap and decisive has said yes.

**A mismatch is a refusal, not a warning.** Weights read in the wrong layout do
not fail with an error: they give a confident wrong answer. For a loss
prevention model, a confident wrong answer is an accusation aimed at a customer,
not a bug in the interface.

The signature that matters is apt's signature over the package. The SHA-256 in
the manifest checks integrity **inside** an already signed artefact: that what
is on disk is the same thing that was built, and that the disk has not degraded
since.

---

## 4. Pinning the version

`ModelRef.pinnedVersion` is the version this terminal agrees to accept:

```dart
const ref = ModelRef(
  manifestPath: '/opt/telepos/models/visitor-counter/model.manifest',
  pinnedVersion: '1.4.0',
);
```

If it does not match: `ModelPinMismatch`, with both versions in the text —
without that, an operator cannot say which end is the wrong one.

**Why not "whatever is latest in the repository".** The repository is allowed to
move; the till is not, until someone permits it. A bad model on a till means
false alarms in front of customers, and that is not the same class of incident
as a bug in the interface. It is the same reason an update of till software
must not begin while a shift is open and the fiscal queue is non-empty.

The terminal → model version binding lives where the rest of the terminal's
configuration lives, and is changed through the interface, not by editing a file
on the machine.

---

## 5. Rollback

The same as for software, and for the same reason the product requires it of
software: **it must be possible from the machine itself, without a network.** If
something on the network went down because of the model, remote rollback is
unavailable by definition.

```bash
# what is installed and what is available
apt-cache policy telepos-model-visitor-counter

# back to the previous version from the local cache
apt-get install --allow-downgrades telepos-model-visitor-counter=1.3.0

# and stop it going forward again until someone has looked into it
apt-mark hold telepos-model-visitor-counter
```

Then the terminal's pin is changed to `1.3.0`. The order is: package first, pin
second — otherwise the terminal gets `ModelPinMismatch` in the interval, which
is safe enough: it refuses to load a model rather than loading the wrong one.

**A till sells without inference.** No failure on this path prevents selling:
all six correlated video events except two need no inference, and the visitor
counter is an indicator, not a till. Calling code should treat
`EngineUnavailable` and any load failure as "this capability is not available
today", not as a fault.

---

## 6. What is not here

- **Training.** `rk_infer` runs models, it does not train them. Where the
  weights come from, what they were trained on and who signs them is a question
  for the model build pipeline, and that is a separate one.
- **Downloading.** The package opens no network connections at all. Delivery is
  done by apt, video decoding is done by the video provider, and `rk_infer`
  receives a finished frame in memory. The separation is not decorative: the
  module that can open a socket has no access to frames, and the module that
  has the frames cannot open a socket.
- **Signature verification.** apt does it before installation. Duplicating it
  here would mean keeping a second set of keys on the till.
