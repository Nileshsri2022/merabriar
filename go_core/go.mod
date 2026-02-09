module merabriar_core

go 1.21

require (
	github.com/mattn/go-sqlite3 v1.14.22
	golang.org/x/crypto v0.18.0
)

// Note: For SQLCipher support, you need to build with CGO and link against SQLCipher
// CGO_ENABLED=1 go build -tags sqlite_userauth
