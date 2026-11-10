//! A relay served at several origins: a link starts with the configured origin
//! whose host the caller reached, and any other `Host` gets the canonical one.

use agentwire::Client;
use agentwire_relay::{Options, Relay};
use tokio::net::TcpListener;

const CANONICAL: &str = "https://agentwire.new.example";
const OLD: &str = "https://agentwire.old.example";

async fn relay() -> String {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let address = listener.local_addr().unwrap();
    let relay = Relay::open(Options {
        origins: vec![CANONICAL.to_owned(), OLD.to_owned()],
        ..Options::default()
    })
    .unwrap();
    tokio::spawn(async move { axum::serve(listener, relay.router()).await.unwrap() });
    format!("http://{address}")
}

#[tokio::test]
async fn a_link_starts_with_a_configured_origin() {
    let address = relay().await;
    let reached = |origin: &str| Client::new().via(origin, &address);

    let link = reached(CANONICAL).create(CANONICAL).await.unwrap();
    assert!(link.starts_with(&format!("{CANONICAL}/v2/s/")), "{link}");

    let link = reached(OLD).create(OLD).await.unwrap();
    assert!(link.starts_with(&format!("{OLD}/v2/s/")), "{link}");

    // The same host over plain HTTP still gets the configured origin.
    let plain = "http://agentwire.old.example";
    let link = reached(plain).create(plain).await.unwrap();
    assert!(link.starts_with(&format!("{OLD}/v2/s/")), "{link}");

    // A host outside the list never reaches a link.
    let evil = "https://evil.example";
    let link = reached(evil).create(evil).await.unwrap();
    assert!(link.starts_with(&format!("{CANONICAL}/v2/s/")), "{link}");

    // Nor does one reached by address.
    let link = Client::new().create(&address).await.unwrap();
    assert!(link.starts_with(&format!("{CANONICAL}/v2/s/")), "{link}");
}
