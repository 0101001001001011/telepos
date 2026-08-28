//! Browses a service type and prints what comes and goes.
//!
//! The other half of the interoperability proof: this must see a service that
//! **Avahi** published, not one this crate published.
//!
//! ```text
//! avahi-publish -s avahi-side _telepos._tcp 9443 quic=1234 &
//! cargo run --example browse -- _telepos._tcp.local
//! ```

use std::time::Duration;

use rk_mdns::browser::{Browser, BrowserConfig};

fn main() {
    let mut args = std::env::args().skip(1);
    let service = args
        .next()
        .unwrap_or_else(|| "_rkmdns._tcp.local".to_string());
    let mdns_port: u16 = args.next().and_then(|p| p.parse().ok()).unwrap_or(5353);

    let config: BrowserConfig = serde_json::from_value(serde_json::json!({
        "serviceType": service,
        "mdnsPort": mdns_port,
        "loopbackInterface": true,
        "multicastLoopback": true,
    }))
    .expect("the configuration is well formed");

    let browser = match Browser::start(config) {
        Ok(browser) => browser,
        Err(error) => {
            eprintln!("rk_mdns: could not browse: {error}");
            std::process::exit(1);
        }
    };

    println!("browsing; ^C to stop");
    loop {
        if let Some(event) = browser.poll(Duration::from_secs(5)) {
            println!("{event:?}");
        }
    }
}
