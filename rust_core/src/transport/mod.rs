//! Transport Module
//! 
//! Handles different transport mechanisms for message delivery.
//! Follows Briar's plugin-based transport system.
//! 
//! Transports (in priority order):
//! 1. Cloud (Supabase Realtime) - Primary, fastest
//! 2. LAN (WiFi Direct) - When on same network
//! 3. Bluetooth - When nearby
//! 4. Tor - For censorship resistance
//! 
//! This mirrors Briar's `bramble-api/plugin` system

use async_trait::async_trait;
use std::sync::Arc;

/// Transport ID (like Briar's TransportId)
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct TransportId(pub String);

impl TransportId {
    pub const CLOUD: &'static str = "org.merabriar.cloud";
    pub const LAN: &'static str = "org.merabriar.lan";
    pub const BLUETOOTH: &'static str = "org.merabriar.bluetooth";
    pub const TOR: &'static str = "org.merabriar.tor";
}

/// Transport state
#[derive(Clone, Debug, PartialEq)]
pub enum TransportState {
    /// Transport is active and can send/receive
    Active,
    
    /// Transport is enabling (connecting)
    Enabling,
    
    /// Transport is disabled
    Disabled,
    
    /// Transport is not available on this platform
    Unavailable,
}

/// Transport properties (like Briar's TransportProperties)
#[derive(Clone, Debug)]
pub struct TransportProperties {
    pub properties: std::collections::HashMap<String, String>,
}

/// Transport trait (like Briar's Plugin interface)
#[async_trait]
pub trait Transport: Send + Sync {
    /// Get the transport ID
    fn id(&self) -> TransportId;
    
    /// Get the current state
    fn state(&self) -> TransportState;
    
    /// Check if transport is available
    fn is_available(&self) -> bool {
        self.state() == TransportState::Active
    }
    
    /// Send a message
    async fn send(&self, recipient_id: &str, data: &[u8]) -> Result<(), String>;
    
    /// Start the transport
    async fn start(&mut self) -> Result<(), String>;
    
    /// Stop the transport
    async fn stop(&mut self) -> Result<(), String>;
}

/// Cloud transport (Supabase Realtime)
pub struct CloudTransport {
    state: TransportState,
    // supabase_client: Option<SupabaseClient>,
}

impl CloudTransport {
    pub fn new() -> Self {
        CloudTransport {
            state: TransportState::Disabled,
        }
    }
}

#[async_trait]
impl Transport for CloudTransport {
    fn id(&self) -> TransportId {
        TransportId(TransportId::CLOUD.to_string())
    }
    
    fn state(&self) -> TransportState {
        self.state.clone()
    }
    
    async fn send(&self, _recipient_id: &str, _data: &[u8]) -> Result<(), String> {
        // In production: Send via Supabase Realtime or insert to messages table
        // This is handled by Flutter/Dart side
        Ok(())
    }
    
    async fn start(&mut self) -> Result<(), String> {
        self.state = TransportState::Active;
        Ok(())
    }
    
    async fn stop(&mut self) -> Result<(), String> {
        self.state = TransportState::Disabled;
        Ok(())
    }
}

/// LAN transport (WiFi Direct / mDNS)
pub struct LanTransport {
    state: TransportState,
}

impl LanTransport {
    pub fn new() -> Self {
        LanTransport {
            state: TransportState::Disabled,
        }
    }
}

#[async_trait]
impl Transport for LanTransport {
    fn id(&self) -> TransportId {
        TransportId(TransportId::LAN.to_string())
    }
    
    fn state(&self) -> TransportState {
        self.state.clone()
    }
    
    async fn send(&self, _recipient_id: &str, _data: &[u8]) -> Result<(), String> {
        // Phase 2: Implement mDNS discovery + TCP connection
        Err("LAN transport not yet implemented".to_string())
    }
    
    async fn start(&mut self) -> Result<(), String> {
        // Phase 2: Start mDNS broadcast
        self.state = TransportState::Disabled;
        Ok(())
    }
    
    async fn stop(&mut self) -> Result<(), String> {
        self.state = TransportState::Disabled;
        Ok(())
    }
}

/// Bluetooth transport
pub struct BluetoothTransport {
    state: TransportState,
}

impl BluetoothTransport {
    pub fn new() -> Self {
        BluetoothTransport {
            state: TransportState::Disabled,
        }
    }
}

#[async_trait]
impl Transport for BluetoothTransport {
    fn id(&self) -> TransportId {
        TransportId(TransportId::BLUETOOTH.to_string())
    }
    
    fn state(&self) -> TransportState {
        self.state.clone()
    }
    
    async fn send(&self, _recipient_id: &str, _data: &[u8]) -> Result<(), String> {
        // Phase 2: Implement BLE connection
        Err("Bluetooth transport not yet implemented".to_string())
    }
    
    async fn start(&mut self) -> Result<(), String> {
        // Phase 2: Start Bluetooth scanning
        self.state = TransportState::Disabled;
        Ok(())
    }
    
    async fn stop(&mut self) -> Result<(), String> {
        self.state = TransportState::Disabled;
        Ok(())
    }
}

/// Tor transport
pub struct TorTransport {
    state: TransportState,
}

impl TorTransport {
    pub fn new() -> Self {
        TorTransport {
            state: TransportState::Disabled,
        }
    }
}

#[async_trait]
impl Transport for TorTransport {
    fn id(&self) -> TransportId {
        TransportId(TransportId::TOR.to_string())
    }
    
    fn state(&self) -> TransportState {
        self.state.clone()
    }
    
    async fn send(&self, _recipient_id: &str, _data: &[u8]) -> Result<(), String> {
        // Phase 3: Implement Tor hidden service connection
        Err("Tor transport not yet implemented".to_string())
    }
    
    async fn start(&mut self) -> Result<(), String> {
        // Phase 3: Start Tor client (arti-client)
        self.state = TransportState::Disabled;
        Ok(())
    }
    
    async fn stop(&mut self) -> Result<(), String> {
        self.state = TransportState::Disabled;
        Ok(())
    }
}

/// Transport manager - selects best available transport
pub struct TransportManager {
    transports: Vec<Arc<dyn Transport>>,
}

impl TransportManager {
    pub fn new() -> Self {
        TransportManager {
            transports: vec![
                Arc::new(CloudTransport::new()),
                Arc::new(LanTransport::new()),
                Arc::new(BluetoothTransport::new()),
                Arc::new(TorTransport::new()),
            ],
        }
    }
    
    /// Get the best available transport
    pub fn get_best_transport(&self) -> Option<Arc<dyn Transport>> {
        // Return first available transport (in priority order)
        self.transports
            .iter()
            .find(|t| t.is_available())
            .cloned()
    }
    
    /// Get all available transports
    pub fn get_available_transports(&self) -> Vec<Arc<dyn Transport>> {
        self.transports
            .iter()
            .filter(|t| t.is_available())
            .cloned()
            .collect()
    }
}
