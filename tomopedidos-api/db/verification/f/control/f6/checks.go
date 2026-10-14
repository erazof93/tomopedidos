// Offline semantic helpers only: no database/network/process execution.
package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"
)

type VersionRow struct {
	ID      int
	Version int
	Applied bool
}

func currentVersion(rows []VersionRow) (int, error) {
	latest := map[int]bool{}
	lastID := 0
	for _, r := range rows {
		if r.ID <= lastID || r.Version < 0 || r.Version > 4 {
			return 0, errors.New("unexpected Goose history")
		}
		lastID = r.ID
		latest[r.Version] = r.Applied
	}
	if !latest[0] {
		return 0, errors.New("missing version0 baseline")
	}
	result := 0
	for v := 1; v <= 4; v++ {
		if latest[v] {
			if v != result+1 {
				return 0, errors.New("noncontiguous applied versions")
			}
			result = v
		}
	}
	return result, nil
}
func classify(exit int, output string) string {
	// Expected SQL failure + explicit rollback + connection recovery is NOT operation success.
	if exit == 0 && strings.Contains(output, "F6_CONNECTION_RECOVERED_OPERATION_ERROR") {
		return "ERROR_ROLLED_BACK_CONNECTION_RECOVERED"
	}
	return "UNKNOWN_RECONCILE_NO_RETRY" // Includes transport loss, missing marker and unexpected exit.
}

type Backend struct {
	PID      int
	Start    string
	DB       string
	Role     string
	App      string
	State    string
	Wait     string
	Blockers []int
}

func cancelEligible(w, h Backend, waiterStart, holderStart string, observedAt, now time.Time) bool {
	return now.Sub(observedAt) >= 0 && now.Sub(observedAt) <= 5*time.Second && w.PID > 0 && h.PID > 0 && w.PID != h.PID &&
		w.Start == waiterStart && h.Start == holderStart && w.Start != "" && h.Start != "" && w.DB == "tp_b2a_f_20261014_r01" && h.DB == w.DB &&
		w.Role == "tomopedidos_session_maintenance" && h.Role == "tomopedidos_bootstrap" &&
		w.App == "tp-b2a-f-20261014-r01:f6-cancel" && h.App == "tp-b2a-f-20261014-r01:f6-holder" &&
		w.State == "active" && w.Wait == "Lock" && h.State == "idle in transaction" && len(w.Blockers) == 1 && w.Blockers[0] == h.PID
}
func main() {
	fmt.Println("F6 offline helpers only; this binary cannot connect, cancel, or run Goose")
	if len(os.Args) > 1 {
		var rows []VersionRow
		b, e := os.ReadFile(os.Args[1])
		if e != nil {
			fmt.Fprintln(os.Stderr, e)
			os.Exit(1)
		}
		if e = json.Unmarshal(b, &rows); e != nil {
			fmt.Fprintln(os.Stderr, e)
			os.Exit(1)
		}
		v, e := currentVersion(rows)
		if e != nil {
			fmt.Fprintln(os.Stderr, e)
			os.Exit(1)
		}
		fmt.Printf("Latest applied version: %d\n", v)
	}
}
