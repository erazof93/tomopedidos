// Package database reserves PostgreSQL infrastructure without opening connections.
package database

import (
	"context"

	"github.com/jackc/pgx/v5/pgconn"
)

// Executor is compatible with pgx connections and transactions.
// Future tenant repositories must execute through a context-bound transaction.
type Executor interface {
	Exec(context.Context, string, ...any) (pgconn.CommandTag, error)
}
