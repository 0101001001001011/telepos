//! The operations, and the requests and replies that describe them.
//!
//! Everything here is expressed as serde types rather than as C structs. A
//! field added to a request is then not an ABI change, so a binding built on
//! Monday still calls a library built on Friday, and enumerations cross as
//! their names because JSON has no way to spell an index (I147).

use std::collections::HashMap;
use std::sync::Mutex;
use std::time::Duration;

use async_nats::jetstream::{self, consumer};
use base64::Engine as _;
use futures::StreamExt as _;
use serde::{Deserialize, Serialize};

use crate::codes::Code;
use crate::durability::{
    ack_meaning, gate, parse_varz, AckMeaning, PersistMode, Policy, ServerDurability, Storage,
};

/// What the caller may tell us about how to prove the server's durability.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "camelCase")]
pub enum Evidence {
    /// Nothing. Every ack then means `unknown`, and the default policy refuses
    /// to publish. That is the intended outcome, not an oversight: the safe
    /// default has to be unusable-until-proven or it is not a safe default.
    None,
    /// The caller fetched the server's `varz` itself — over the monitoring
    /// port, usually — and hands us the document. Keeps an HTTP stack out of
    /// this library and keeps the evidence something a human can print.
    VarzJson {
        /// The raw document, exactly as the server served it.
        varz: String,
    },
    /// Ask the server over NATS, from an account that can see `$SYS`. Works
    /// where the monitoring port is closed, which on an appliance it should be.
    SystemAccount {
        /// System-account user.
        user: String,
        /// System-account password.
        password: String,
    },
}

/// How to authenticate to NATS.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "camelCase")]
pub enum Credentials {
    /// No authentication.
    None,
    /// User and password.
    UserPassword {
        /// User name.
        user: String,
        /// Password.
        password: String,
    },
    /// A bare token.
    Token {
        /// The token.
        token: String,
    },
    /// A `.creds` file on disk.
    CredsFile {
        /// Path to the file.
        path: String,
    },
}

/// Opening a connection.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConnectRequest {
    /// One or more server URLs.
    pub servers: Vec<String>,
    /// The name this client reports, so `nats server report connections` shows
    /// which till is talking.
    #[serde(default)]
    pub name: String,
    /// How to authenticate. Absent means no authentication.
    #[serde(default)]
    pub credentials: Option<Credentials>,
    /// What an ack has to mean here. Defaults to the fsynced one.
    #[serde(default)]
    pub policy: Policy,
    /// For `flushOnAck` only: how much unsynced data the caller accepts losing.
    #[serde(default)]
    pub accepted_fsync_lag_nanos: u64,
    /// How to prove the server's durability.
    #[serde(default = "evidence_none")]
    pub evidence: Evidence,
    /// Deadline for the connect itself.
    #[serde(default = "default_timeout_millis")]
    pub timeout_millis: u64,
}

fn evidence_none() -> Evidence {
    Evidence::None
}

fn default_timeout_millis() -> u64 {
    5_000
}

/// Naming an existing connection.
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HandleRequest {
    /// The handle from `connect`.
    pub handle: u64,
    /// Deadline for whatever this call does.
    #[serde(default = "default_timeout_millis")]
    pub timeout_millis: u64,
}

/// Handing the library a `varz` document after the fact.
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ApplyVarzRequest {
    /// The handle from `connect`.
    pub handle: u64,
    /// The raw document.
    pub varz: String,
}

/// Creating a stream, or bringing an existing one to this shape.
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EnsureStreamRequest {
    /// The handle from `connect`.
    pub handle: u64,
    /// Stream name.
    pub name: String,
    /// Subjects the stream captures.
    #[serde(default)]
    pub subjects: Vec<String>,
    /// File or memory. Defaults to file.
    #[serde(default)]
    pub storage: Storage,
    /// Default or async. Defaults to default; `async` is refused outright by
    /// the fsynced policy because it acks before storing.
    #[serde(default)]
    pub persist_mode: PersistMode,
    /// How many replicas. More replicas is not a substitute for fsync — Jepsen
    /// found split brain after a single node failure at three replicas — and
    /// this library will not let one stand in for the other.
    #[serde(default = "one")]
    pub replicas: usize,
    /// The window in which a repeated `messageId` is recognised as the same
    /// message. This is what makes a retried publish safe.
    #[serde(default = "two_minutes_nanos")]
    pub duplicate_window_nanos: u64,
    /// Maximum age of a message, or zero for unlimited.
    #[serde(default)]
    pub max_age_nanos: u64,
    /// Deadline.
    #[serde(default = "default_timeout_millis")]
    pub timeout_millis: u64,
}

fn one() -> usize {
    1
}

fn two_minutes_nanos() -> u64 {
    120_000_000_000
}

/// Publishing one message.
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PublishRequest {
    /// The handle from `connect`.
    pub handle: u64,
    /// The stream the caller believes it is writing to. Required: durability is
    /// a property of a stream, so a publish that does not name one cannot be
    /// judged. The server's answer is checked against it.
    pub stream: String,
    /// The subject to publish on.
    pub subject: String,
    /// The body, base64 so arbitrary bytes survive JSON.
    pub payload_base64: String,
    /// `Nats-Msg-Id`. Given one, a retry inside the stream's duplicate window
    /// is recognised rather than stored twice.
    #[serde(default)]
    pub message_id: String,
    /// Deadline.
    #[serde(default = "default_timeout_millis")]
    pub timeout_millis: u64,
}

/// Pulling a batch from a durable consumer.
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FetchRequest {
    /// The handle from `connect`.
    pub handle: u64,
    /// Stream to read.
    pub stream: String,
    /// Durable consumer name. Durable on purpose: an ephemeral consumer forgets
    /// where it was, and forgetting where it was is how a till re-sends a day
    /// of sales.
    pub consumer: String,
    /// Only these subjects, or empty for all of them.
    #[serde(default)]
    pub filter_subject: String,
    /// How many messages at most.
    #[serde(default = "sixteen")]
    pub batch: usize,
    /// How long to wait for them.
    #[serde(default = "one_second_millis")]
    pub expires_millis: u64,
}

fn sixteen() -> usize {
    16
}

fn one_second_millis() -> u64 {
    1_000
}

/// Acknowledging a delivered message.
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AckRequest {
    /// The handle from `connect`.
    pub handle: u64,
    /// The reply subject that came with the message.
    pub reply_subject: String,
    /// Wait for the server to confirm it recorded the ack. On by default: an
    /// unconfirmed ack has the same "probably" problem as an unsynced write.
    #[serde(default = "yes")]
    pub double_ack: bool,
    /// Deadline.
    #[serde(default = "default_timeout_millis")]
    pub timeout_millis: u64,
}

fn yes() -> bool {
    true
}

/// One message, as it crosses the boundary.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DeliveredMessage {
    /// Subject it was published on.
    pub subject: String,
    /// Body, base64.
    pub payload_base64: String,
    /// Where to send the acknowledgement.
    pub reply_subject: String,
    /// Position in the stream.
    pub stream_sequence: u64,
    /// How many times this consumer has been given it. Above one means an
    /// earlier delivery was not acknowledged.
    pub num_delivered: u64,
}

/// What we know about a stream after the server has echoed its configuration.
#[derive(Debug, Clone, Copy)]
pub struct StreamFacts {
    /// Storage, as the server reports it.
    pub storage: Storage,
    /// Persistence mode in force, which is not always the one requested.
    pub effective_persist_mode: PersistMode,
}

/// One open connection.
pub struct Conn {
    servers: Vec<String>,
    client: async_nats::Client,
    js: jetstream::Context,
    policy: Policy,
    accepted_lag_nanos: u64,
    evidence: Evidence,
    server: Mutex<Option<ServerDurability>>,
    streams: Mutex<HashMap<String, StreamFacts>>,
}

/// A failure with a code and something a human can read.
pub struct Failure {
    /// The code, which crosses by name.
    pub code: Code,
    /// The detail. Never the only thing returned: a caller must be able to
    /// branch on the code without parsing prose.
    pub message: String,
}

impl Failure {
    fn new(code: Code, message: impl Into<String>) -> Self {
        Failure {
            code,
            message: message.into(),
        }
    }
}

/// Result of a boundary operation.
pub type Outcome = Result<serde_json::Value, Failure>;

async fn deadline<T>(
    millis: u64,
    what: &str,
    fut: impl std::future::Future<Output = T>,
) -> Result<T, Failure> {
    // No call waits forever. A call that can hang forever is a failure that
    // never gets returned, which is the same as no failure handling at all.
    match tokio::time::timeout(Duration::from_millis(millis), fut).await {
        Ok(v) => Ok(v),
        Err(_) => Err(Failure::new(
            Code::Timeout,
            format!("{what} did not finish within {millis} ms"),
        )),
    }
}

/// Opens a connection and, if the caller supplied evidence, learns what an ack
/// will mean on it.
pub async fn connect(req: ConnectRequest) -> Result<serde_json::Value, Failure> {
    if req.servers.is_empty() {
        return Err(Failure::new(
            Code::InvalidRequest,
            "connect needs at least one server URL",
        ));
    }
    if req.policy == Policy::FlushOnAck && req.accepted_fsync_lag_nanos == 0 {
        return Err(Failure::new(
            Code::InvalidRequest,
            "policy flushOnAck must name acceptedFsyncLagNanos: the point of \
             choosing it is to state how much unsynced data you accept losing",
        ));
    }

    let options = match &req.credentials_or_default() {
        Credentials::None => async_nats::ConnectOptions::new(),
        Credentials::UserPassword { user, password } => {
            async_nats::ConnectOptions::with_user_and_password(user.clone(), password.clone())
        }
        Credentials::Token { token } => async_nats::ConnectOptions::with_token(token.clone()),
        Credentials::CredsFile { path } => async_nats::ConnectOptions::with_credentials_file(path)
            .await
            .map_err(|e| Failure::new(Code::ConnectFailed, format!("credentials file: {e}")))?,
    };
    let options = if req.name.is_empty() {
        options
    } else {
        options.name(req.name.clone())
    };

    let client = deadline(
        req.timeout_millis,
        "connect",
        options.connect(req.servers.join(",")),
    )
    .await?
    .map_err(|e| Failure::new(Code::ConnectFailed, e.to_string()))?;

    let server_version = client.server_info().version.clone();
    let js = jetstream::new(client.clone());

    let conn = Conn {
        servers: req.servers.clone(),
        client,
        js,
        policy: req.policy,
        accepted_lag_nanos: req.accepted_fsync_lag_nanos,
        evidence: req.evidence.clone(),
        server: Mutex::new(None),
        streams: Mutex::new(HashMap::new()),
    };

    // Probing at connect is the whole difference between a durability contract
    // and a durability comment: by the time anyone publishes, the answer is
    // already known or already refused.
    let probe = conn.probe(req.timeout_millis).await;

    let handle = crate::registry::insert(conn);
    let mut out = serde_json::json!({
        "handle": handle,
        "serverVersion": server_version,
        "policy": req.policy.as_str(),
    });
    match probe {
        Ok(v) => {
            out["durability"] = v;
        }
        Err(f) => {
            // A failed probe is not a failed connect: consuming needs no
            // durability promise, and refusing the connection would hide the
            // reason. It is reported, and it will refuse the first publish.
            out["durability"] = serde_json::json!({
                "code": f.code.as_str(),
                "message": f.message,
                "ackMeaning": AckMeaning::Unknown.as_str(),
            });
        }
    }
    Ok(out)
}

impl ConnectRequest {
    fn credentials_or_default(&self) -> Credentials {
        self.credentials.clone().unwrap_or(Credentials::None)
    }
}

impl Conn {
    /// Reads the server's durability facts through whichever evidence path the
    /// caller configured, and remembers them.
    pub async fn probe(&self, timeout_millis: u64) -> Result<serde_json::Value, Failure> {
        let varz = match &self.evidence {
            Evidence::None => {
                return Err(Failure::new(
                    Code::DurabilityUnproven,
                    "no evidence path configured: pass evidence.varzJson with the \
                     server's monitoring document, or evidence.systemAccount so \
                     this library can ask the server itself",
                ))
            }
            Evidence::VarzJson { varz } => varz.clone(),
            Evidence::SystemAccount { user, password } => {
                self.varz_over_system_account(user, password, timeout_millis)
                    .await?
            }
        };

        let facts = parse_varz(&varz).map_err(|e| Failure::new(Code::DurabilityProbeFailed, e))?;
        let json = serde_json::json!({
            "code": Code::Ok.as_str(),
            "server": facts,
            "ackMeaning": ack_meaning(Some(&facts), Storage::File, PersistMode::Default).as_str(),
        });
        *self.server.lock().unwrap_or_else(|e| e.into_inner()) = Some(facts);
        Ok(json)
    }

    /// Takes a `varz` document the caller fetched itself and records what it
    /// says. The same evaluation as the probe, without the network.
    pub fn apply_varz(&self, varz: &str) -> Outcome {
        let facts = parse_varz(varz).map_err(|e| Failure::new(Code::DurabilityProbeFailed, e))?;
        let json = serde_json::json!({
            "server": facts,
            "ackMeaning": ack_meaning(Some(&facts), Storage::File, PersistMode::Default).as_str(),
        });
        *self.server.lock().unwrap_or_else(|e| e.into_inner()) = Some(facts);
        Ok(json)
    }

    async fn varz_over_system_account(
        &self,
        user: &str,
        password: &str,
        timeout_millis: u64,
    ) -> Result<String, Failure> {
        // A separate connection on purpose: the system account is not the
        // account the tills publish from, and blurring the two is how a till
        // ends up with more rights than it needs.
        //
        // Dialled with the URLs the caller gave us, not with the host the
        // server reports about itself: a server bound to 0.0.0.0 reports
        // 0.0.0.0, and nothing can connect to that.
        let target = self.servers.join(",");

        let sys = deadline(
            timeout_millis,
            "system-account connect",
            async_nats::ConnectOptions::with_user_and_password(user.into(), password.into())
                .connect(target),
        )
        .await?
        .map_err(|e| {
            Failure::new(
                Code::DurabilityProbeFailed,
                format!("system account connect: {e}"),
            )
        })?;

        let msg = deadline(
            timeout_millis,
            "$SYS.REQ.SERVER.PING.VARZ",
            sys.request("$SYS.REQ.SERVER.PING.VARZ", "".into()),
        )
        .await?
        .map_err(|e| Failure::new(Code::DurabilityProbeFailed, e.to_string()))?;

        Ok(String::from_utf8_lossy(&msg.payload).into_owned())
    }

    fn server_facts(&self) -> Option<ServerDurability> {
        self.server
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .clone()
    }

    /// Creates the stream, or brings an existing one to this configuration, and
    /// refuses outright if the result could not satisfy the connection's policy.
    pub async fn ensure_stream(&self, req: EnsureStreamRequest) -> Outcome {
        let facts = self.server_facts();
        let prospective = ack_meaning(facts.as_ref(), req.storage, req.persist_mode);
        if let Some(code) = gate(
            self.policy,
            prospective,
            self.accepted_lag_nanos,
            facts.as_ref(),
        ) {
            // A stream that cannot carry what this connection promised is not
            // created at all. Creating it and failing later would leave a
            // half-configured server behind every refusal.
            let code = if code == Code::DurabilityWeakerThanRequested {
                Code::StreamRefusedWeakerThanPolicy
            } else {
                code
            };
            return Err(Failure::new(
                code,
                format!(
                    "stream {} as configured would make an ack mean {}, and this \
                     connection asked for {}",
                    req.name,
                    prospective.as_str(),
                    self.policy.as_str()
                ),
            ));
        }

        let subjects = if req.subjects.is_empty() {
            vec![format!("{}.>", req.name)]
        } else {
            req.subjects.clone()
        };

        let config = jetstream::stream::Config {
            name: req.name.clone(),
            subjects,
            storage: match req.storage {
                Storage::File => jetstream::stream::StorageType::File,
                Storage::Memory => jetstream::stream::StorageType::Memory,
            },
            num_replicas: req.replicas,
            persist_mode: Some(match req.persist_mode {
                PersistMode::Default => jetstream::stream::PersistenceMode::Default,
                PersistMode::Async => jetstream::stream::PersistenceMode::Async,
            }),
            duplicate_window: Duration::from_nanos(req.duplicate_window_nanos),
            max_age: Duration::from_nanos(req.max_age_nanos),
            ..Default::default()
        };

        let mut stream = deadline(
            req.timeout_millis,
            "ensure stream",
            self.js.get_or_create_stream(config),
        )
        .await?
        .map_err(|e| Failure::new(Code::StreamFailed, e.to_string()))?;

        let info = deadline(req.timeout_millis, "stream info", stream.info())
            .await?
            .map_err(|e| Failure::new(Code::StreamFailed, e.to_string()))?;

        // What the server echoed, not what we asked for. A server too old to
        // know `persist_mode` drops the field silently; measured on 2.11.0,
        // which accepted `async` and echoed nothing back. Absence is therefore
        // read as the default mode, and the discrepancy is reported.
        let echoed = match info.config.persist_mode {
            Some(jetstream::stream::PersistenceMode::Async) => PersistMode::Async,
            _ => PersistMode::Default,
        };
        let honoured = echoed == req.persist_mode;
        let storage = match info.config.storage {
            jetstream::stream::StorageType::Memory => Storage::Memory,
            _ => Storage::File,
        };

        self.streams
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(
                req.name.clone(),
                StreamFacts {
                    storage,
                    effective_persist_mode: echoed,
                },
            );

        let effective = ack_meaning(facts.as_ref(), storage, echoed);
        Ok(serde_json::json!({
            "stream": req.name,
            "storage": storage,
            "requestedPersistMode": req.persist_mode,
            "effectivePersistMode": echoed,
            "persistModeHonoured": honoured,
            "replicas": info.config.num_replicas,
            "duplicateWindowNanos": info.config.duplicate_window.as_nanos() as u64,
            "ackMeaning": effective.as_str(),
        }))
    }

    /// Publishes, having first checked that the ack the server is about to send
    /// will mean what the caller asked an ack to mean.
    pub async fn publish(&self, req: PublishRequest) -> Outcome {
        let payload = base64::engine::general_purpose::STANDARD
            .decode(req.payload_base64.as_bytes())
            .map_err(|e| Failure::new(Code::InvalidRequest, format!("payloadBase64: {e}")))?;

        let stream_facts = self
            .streams
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .get(&req.stream)
            .copied();
        let Some(stream_facts) = stream_facts else {
            return Err(Failure::new(
                Code::InvalidRequest,
                format!(
                    "stream {} is not known to this connection: call ensureStream \
                     first, so that what its ack means has been established before \
                     anything is written to it",
                    req.stream
                ),
            ));
        };

        let server = self.server_facts();
        let meaning = ack_meaning(
            server.as_ref(),
            stream_facts.storage,
            stream_facts.effective_persist_mode,
        );
        if let Some(code) = gate(
            self.policy,
            meaning,
            self.accepted_lag_nanos,
            server.as_ref(),
        ) {
            return Err(Failure::new(
                code,
                format!(
                    "an ack from stream {} would mean {}, and this connection asked \
                     for {}; nothing was published",
                    req.stream,
                    meaning.as_str(),
                    self.policy.as_str()
                ),
            ));
        }

        let mut headers = async_nats::HeaderMap::new();
        if !req.message_id.is_empty() {
            headers.insert("Nats-Msg-Id", req.message_id.as_str());
        }

        let fut = async {
            let ack = self
                .js
                .publish_with_headers(req.subject.clone(), headers, payload.into())
                .await
                .map_err(|e| Failure::new(Code::PublishFailed, e.to_string()))?;
            ack.await
                .map_err(|e| Failure::new(Code::PublishFailed, e.to_string()))
        };

        let ack = deadline(req.timeout_millis, "publish", fut).await??;

        // The subject decides which stream captures a message, so a mistyped
        // subject can land in a stream whose durability nobody checked. Compare
        // rather than assume.
        if ack.stream != req.stream {
            return Err(Failure::new(
                Code::PublishFailed,
                format!(
                    "subject {} was captured by stream {}, not by {} as the caller \
                     believed; that stream's durability was never established",
                    req.subject, ack.stream, req.stream
                ),
            ));
        }

        Ok(serde_json::json!({
            "stream": ack.stream,
            "sequence": ack.sequence,
            "duplicate": ack.duplicate,
            "ackMeaning": meaning.as_str(),
        }))
    }

    /// Pulls a batch from a durable consumer, creating the consumer if it is
    /// not there yet.
    pub async fn fetch(&self, req: FetchRequest) -> Outcome {
        let stream = deadline(
            req.expires_millis + 2_000,
            "get stream",
            self.js.get_stream(&req.stream),
        )
        .await?
        .map_err(|e| Failure::new(Code::ConsumeFailed, e.to_string()))?;

        let config = consumer::pull::Config {
            durable_name: Some(req.consumer.clone()),
            filter_subject: req.filter_subject.clone(),
            ack_policy: consumer::AckPolicy::Explicit,
            ..Default::default()
        };

        let consumer = deadline(
            req.expires_millis + 2_000,
            "get or create consumer",
            stream.get_or_create_consumer(&req.consumer, config),
        )
        .await?
        .map_err(|e| Failure::new(Code::ConsumeFailed, e.to_string()))?;

        let mut batch = deadline(req.expires_millis + 2_000, "fetch", async {
            consumer
                .batch()
                .max_messages(req.batch)
                .expires(Duration::from_millis(req.expires_millis))
                .messages()
                .await
        })
        .await?
        .map_err(|e| Failure::new(Code::ConsumeFailed, e.to_string()))?;

        let mut messages = Vec::new();
        while let Some(item) = batch.next().await {
            let msg = item.map_err(|e| Failure::new(Code::ConsumeFailed, e.to_string()))?;
            let info = msg
                .info()
                .map_err(|e| Failure::new(Code::ConsumeFailed, e.to_string()))?;
            messages.push(DeliveredMessage {
                subject: msg.subject.to_string(),
                payload_base64: base64::engine::general_purpose::STANDARD.encode(&msg.payload),
                reply_subject: msg
                    .reply
                    .as_ref()
                    .map(|s| s.to_string())
                    .unwrap_or_default(),
                stream_sequence: info.stream_sequence,
                num_delivered: info.delivered.max(0) as u64,
            });
        }

        Ok(serde_json::json!({ "messages": messages }))
    }

    /// Acknowledges a delivered message.
    pub async fn ack(&self, req: AckRequest) -> Outcome {
        if req.reply_subject.is_empty() {
            return Err(Failure::new(
                Code::InvalidRequest,
                "ack needs the reply subject that came with the message",
            ));
        }
        if req.double_ack {
            deadline(
                req.timeout_millis,
                "double ack",
                self.client.request(req.reply_subject.clone(), "".into()),
            )
            .await?
            .map_err(|e| Failure::new(Code::AckFailed, e.to_string()))?;
        } else {
            deadline(
                req.timeout_millis,
                "ack",
                self.client.publish(req.reply_subject.clone(), "".into()),
            )
            .await?
            .map_err(|e| Failure::new(Code::AckFailed, e.to_string()))?;
            deadline(req.timeout_millis, "flush", self.client.flush())
                .await?
                .map_err(|e| Failure::new(Code::AckFailed, e.to_string()))?;
        }
        Ok(serde_json::json!({ "acknowledged": true, "doubleAck": req.double_ack }))
    }
}
