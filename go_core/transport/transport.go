// Package transport provides multiple transport mechanisms.
// This mirrors Briar's plugin-based transport system in bramble-api/plugin
package transport

// TransportID identifies a transport
type TransportID string

const (
	TransportCloud     TransportID = "org.merabriar.cloud"
	TransportLAN       TransportID = "org.merabriar.lan"
	TransportBluetooth TransportID = "org.merabriar.bluetooth"
	TransportTor       TransportID = "org.merabriar.tor"
)

// TransportState represents the current state of a transport
type TransportState int

const (
	StateActive TransportState = iota
	StateEnabling
	StateDisabled
	StateUnavailable
)

// TransportProperties holds transport-specific configuration
type TransportProperties map[string]string

// Transport interface (like Briar's Plugin)
type Transport interface {
	ID() TransportID
	State() TransportState
	IsAvailable() bool
	Send(recipientID string, data []byte) error
	Start() error
	Stop() error
}

// CloudTransport implements Transport for Supabase Realtime
type CloudTransport struct {
	state TransportState
}

// NewCloudTransport creates a new cloud transport
func NewCloudTransport() *CloudTransport {
	return &CloudTransport{state: StateDisabled}
}

func (t *CloudTransport) ID() TransportID {
	return TransportCloud
}

func (t *CloudTransport) State() TransportState {
	return t.state
}

func (t *CloudTransport) IsAvailable() bool {
	return t.state == StateActive
}

func (t *CloudTransport) Send(recipientID string, data []byte) error {
	// In production: Send via Supabase Realtime
	// This is handled by Flutter/Dart side
	return nil
}

func (t *CloudTransport) Start() error {
	t.state = StateActive
	return nil
}

func (t *CloudTransport) Stop() error {
	t.state = StateDisabled
	return nil
}

// LANTransport implements Transport for local network
type LANTransport struct {
	state TransportState
}

// NewLANTransport creates a new LAN transport
func NewLANTransport() *LANTransport {
	return &LANTransport{state: StateDisabled}
}

func (t *LANTransport) ID() TransportID {
	return TransportLAN
}

func (t *LANTransport) State() TransportState {
	return t.state
}

func (t *LANTransport) IsAvailable() bool {
	return t.state == StateActive
}

func (t *LANTransport) Send(recipientID string, data []byte) error {
	// Phase 2: Implement mDNS discovery + TCP
	return nil
}

func (t *LANTransport) Start() error {
	// Phase 2: Start mDNS
	return nil
}

func (t *LANTransport) Stop() error {
	t.state = StateDisabled
	return nil
}

// BluetoothTransport implements Transport for Bluetooth LE
type BluetoothTransport struct {
	state TransportState
}

// NewBluetoothTransport creates a new Bluetooth transport
func NewBluetoothTransport() *BluetoothTransport {
	return &BluetoothTransport{state: StateDisabled}
}

func (t *BluetoothTransport) ID() TransportID {
	return TransportBluetooth
}

func (t *BluetoothTransport) State() TransportState {
	return t.state
}

func (t *BluetoothTransport) IsAvailable() bool {
	return t.state == StateActive
}

func (t *BluetoothTransport) Send(recipientID string, data []byte) error {
	// Phase 2: Implement BLE
	return nil
}

func (t *BluetoothTransport) Start() error {
	// Phase 2: Start BLE scanning
	return nil
}

func (t *BluetoothTransport) Stop() error {
	t.state = StateDisabled
	return nil
}

// TorTransport implements Transport for Tor hidden services
type TorTransport struct {
	state TransportState
}

// NewTorTransport creates a new Tor transport
func NewTorTransport() *TorTransport {
	return &TorTransport{state: StateDisabled}
}

func (t *TorTransport) ID() TransportID {
	return TransportTor
}

func (t *TorTransport) State() TransportState {
	return t.state
}

func (t *TorTransport) IsAvailable() bool {
	return t.state == StateActive
}

func (t *TorTransport) Send(recipientID string, data []byte) error {
	// Phase 3: Implement Tor
	return nil
}

func (t *TorTransport) Start() error {
	// Phase 3: Start Tor client
	return nil
}

func (t *TorTransport) Stop() error {
	t.state = StateDisabled
	return nil
}

// TransportManager manages and selects transports
type TransportManager struct {
	transports []Transport
}

// NewTransportManager creates a new transport manager
func NewTransportManager() *TransportManager {
	return &TransportManager{
		transports: []Transport{
			NewCloudTransport(),
			NewLANTransport(),
			NewBluetoothTransport(),
			NewTorTransport(),
		},
	}
}

// GetBestTransport returns the best available transport
func (m *TransportManager) GetBestTransport() Transport {
	// Return first available (in priority order)
	for _, t := range m.transports {
		if t.IsAvailable() {
			return t
		}
	}
	return nil
}

// GetAvailableTransports returns all available transports
func (m *TransportManager) GetAvailableTransports() []Transport {
	var available []Transport
	for _, t := range m.transports {
		if t.IsAvailable() {
			available = append(available, t)
		}
	}
	return available
}
