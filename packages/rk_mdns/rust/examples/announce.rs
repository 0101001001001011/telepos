//! Announces a service and prints what happens, until interrupted.
//!
//! This is the binary the interoperability proof runs. It exists as an example
//! rather than as a test because the other side of the proof is a **different
//! implementation** — `avahi-browse`, `avahi-resolve`, `dns-sd` — driven by
//! hand or by a script, and a test that could only talk to itself would prove
//! the one thing that is not in question.
//!
//! ```text
//! cargo run --example announce -- till-3 _telepos._tcp.local 8443
//! ```
//!
//! Then, on the same host (which is where the proof has to run when the
//! segment does not carry multicast between machines):
//!
//! ```text
//! avahi-browse -r -t _telepos._tcp
//! avahi-resolve -n till-3.local
//! ```

use std::time::{Duration, Instant};

use rk_mdns::responder::{Responder, ResponderConfig};

fn main() {
    let mut args = std::env::args().skip(1);
    let instance = args.next().unwrap_or_else(|| "rk-mdns".into());
    let service = args
        .next()
        .unwrap_or_else(|| "_rkmdns._tcp.local".to_string());
    let port: u16 = args.next().and_then(|p| p.parse().ok()).unwrap_or(8443);
    let mdns_port: u16 = args.next().and_then(|p| p.parse().ok()).unwrap_or(5353);
    // How long to announce for, in seconds. 0 means forever.
    //
    // This exists because of a measured mistake: the interoperability script
    // stopped this example with SIGTERM, the process died without unwinding,
    // `stop()` never ran, and **the goodbye was never sent** — after which
    // `avahi-browse` went on listing a service that was no longer there and
    // the check looked like a defect in the responder. It was a defect in how
    // the responder was stopped. A bounded run stops the way an application
    // does.
    let seconds: u64 = args.next().and_then(|p| p.parse().ok()).unwrap_or(0);

    // Which interfaces to announce on, comma-separated. Empty means all of
    // them, which is the default and is often wrong: a spare address in an
    // announcement is *tried* by a client and costs it a connection timeout.
    // Measured 2026-08-06 against `avahi-resolve` on a machine with a docker
    // bridge — the third-party resolver picked `172.17.0.1` over the real
    // address, which is exactly the failure this switch exists for.
    let named: Vec<String> = std::env::var("RK_MDNS_INTERFACES")
        .unwrap_or_default()
        .split(',')
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect();

    let config: ResponderConfig = serde_json::from_value(serde_json::json!({
        "instanceName": instance,
        "serviceType": service,
        "port": port,
        "txt": ["quic=4433", "path=/rk", "scheme=https"],
        "mdnsPort": mdns_port,
        "interfaces": named,
        // On, because the proof runs against a resolver on this same host.
        "loopbackInterface": true,
        "multicastLoopback": true,
    }))
    .expect("the configuration is well formed");

    let responder = match Responder::start(config) {
        Ok(responder) => responder,
        Err(error) => {
            eprintln!("rk_mdns: could not announce: {error}");
            std::process::exit(1);
        }
    };

    if seconds == 0 {
        println!("announcing, indefinitely");
    } else {
        println!("announcing for {seconds}s, then saying goodbye");
    }

    let deadline = Instant::now() + Duration::from_secs(if seconds == 0 { u64::MAX } else { seconds });
    while Instant::now() < deadline {
        if let Some(event) = responder.poll(Duration::from_millis(500)) {
            println!("{event:?}");
        }
        let state = responder.state();
        if state.claimed {
            for interface in &state.interfaces {
                if interface.sent == 0 {
                    println!(
                        "warning: {} ({}) has carried nothing",
                        interface.name, interface.address
                    );
                }
            }
        }
    }

    println!("stopping; the goodbye goes out before this returns");
    responder.stop();
    println!("stopped");
}
