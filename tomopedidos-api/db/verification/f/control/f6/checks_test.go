package main

import (
	"testing"
	"time"
)

func TestHistoryDownIgnoresOldAppliedRows(t *testing.T) {
	r := []VersionRow{{1, 0, true}, {2, 1, true}, {3, 2, true}, {4, 3, true}, {5, 4, true}, {6, 4, false}}
	v, e := currentVersion(r)
	if e != nil || v != 3 {
		t.Fatal(v, e)
	}
}
func TestHistoryReUp(t *testing.T) {
	r := []VersionRow{{1, 0, true}, {2, 1, true}, {3, 1, false}, {4, 1, true}}
	v, e := currentVersion(r)
	if e != nil || v != 1 {
		t.Fatal(v, e)
	}
}
func TestHistoryRejectsHolesAndUnordered(t *testing.T) {
	for _, r := range [][]VersionRow{{{1, 0, true}, {2, 2, true}}, {{2, 0, true}, {1, 1, true}}, {{1, 1, true}}} {
		if _, e := currentVersion(r); e == nil {
			t.Fatal("unsafe history")
		}
	}
}
func TestTransportNeverMeansSuccess(t *testing.T) {
	for _, v := range []struct {
		exit int
		out  string
	}{{0, ""}, {2, "connection lost"}, {0, "pending deleted2"}, {3, "F6_CONNECTION_RECOVERED_OPERATION_ERROR"}} {
		if classify(v.exit, v.out) != "UNKNOWN_RECONCILE_NO_RETRY" {
			t.Fatal("false success")
		}
	}
}
func TestExpectedFailureRecovered(t *testing.T) {
	if classify(0, "F6_CONNECTION_RECOVERED_OPERATION_ERROR") != "ERROR_ROLLED_BACK_CONNECTION_RECOVERED" {
		t.Fatal("error classification")
	}
}
func TestCancellationTargetAndPIDReuse(t *testing.T) {
	now := time.Now()
	w := Backend{10, "w1", "tp_b2a_f_20261014_r01", "tomopedidos_session_maintenance", "tp-b2a-f-20261014-r01:f6-cancel", "active", "Lock", []int{20}}
	h := Backend{20, "h1", w.DB, "tomopedidos_bootstrap", "tp-b2a-f-20261014-r01:f6-holder", "idle in transaction", "", nil}
	if !cancelEligible(w, h, "w1", "h1", now, now) {
		t.Fatal("valid target")
	}
	if cancelEligible(w, h, "reused-pid", "h1", now, now) {
		t.Fatal("PID reuse")
	}
	w.DB = "other"
	if cancelEligible(w, h, "w1", "h1", now, now) {
		t.Fatal("cross database")
	}
}
func TestCancellationForeignBlockerOrStale(t *testing.T) {
	now := time.Now()
	w := Backend{10, "w1", "tp_b2a_f_20261014_r01", "tomopedidos_session_maintenance", "tp-b2a-f-20261014-r01:f6-cancel", "active", "Lock", []int{20, 30}}
	h := Backend{20, "h1", w.DB, "tomopedidos_bootstrap", "tp-b2a-f-20261014-r01:f6-holder", "idle in transaction", "", nil}
	if cancelEligible(w, h, "w1", "h1", now, now) {
		t.Fatal("foreign blocker")
	}
	w.Blockers = []int{20}
	if cancelEligible(w, h, "w1", "h1", now.Add(-6*time.Second), now) {
		t.Fatal("stale observation")
	}
}
