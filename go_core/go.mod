module merabriar_core

go 1.21

require (
	golang.org/x/crypto v0.18.0
	github.com/mattn/go-sqlite3 v1.14.22
	github.com/google/uuid v1.6.0
)

// Note: For SQLCipher support, you need to build with CGO and link against SQLCipher
// CGO_ENABLED=1 go build -tags sqlite_userauth
