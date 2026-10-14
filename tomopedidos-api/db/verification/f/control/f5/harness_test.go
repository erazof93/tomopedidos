package main

import (
	"bytes"
	"encoding/binary"
	"testing"
	"time"
)

func TestReceiptFailsClosed(t *testing.T) {
	now := time.Now()
	r := Receipt{runID, database, systemID, "4218b22fbb213e9ae748e164f4cb429a74ba2d8307e386a1e0d09c750437d351", now, true, true, 4}
	if e := checkReceipt(r, now); e != nil {
		t.Fatal(e)
	}
	for _, change := range []func(*Receipt){func(r *Receipt) { r.Database = "other" }, func(r *Receipt) { r.SystemID = "0" }, func(r *Receipt) { r.NoPorts = false }, func(r *Receipt) { r.VerifiedAt = now.Add(-31 * time.Second) }, func(r *Receipt) { r.ContainerID = "other" }, func(r *Receipt) { r.Version = 3 }} {
		c := r
		change(&c)
		if checkReceipt(c, now) == nil {
			t.Fatal("unsafe receipt accepted")
		}
	}
}
func TestAuditCannotApproveIncompleteOrError(t *testing.T) {
	if auditOutput([]byte("starting permutation: a\nERROR: denied"), 1) == nil {
		t.Fatal("error accepted")
	}
	if auditOutput([]byte("starting permutation: a"), 2) == nil {
		t.Fatal("partial accepted")
	}
	if auditOutput([]byte("starting permutation: a"), 1) != nil {
		t.Fatal("capture rejected")
	}
}
func TestSuccessfulStepTextIsNotAnError(t *testing.T) {
	if auditOutput([]byte("starting permutation: a\nstep verify: DO BEGIN RAISE EXCEPTION 'invariant failed'; END;"), 1) != nil {
		t.Fatal("SQL source mistaken for an emitted error")
	}
}
func TestStructuralSpec(t *testing.T) {
	good := "step \"a\" {BEGIN;}\npermutation \"a\"\n"
	if checkSpec(good, 1) != nil {
		t.Fatal("good spec")
	}
	if checkSpec(good+"permutation \"missing\"\n", 2) == nil {
		t.Fatal("undefined step")
	}
	if checkSpec(good+"pg_sleep(1)", 1) == nil {
		t.Fatal("sleep accepted")
	}
}
func TestCommitRecognition(t *testing.T) {
	if !isCommit('Q', []byte("COMMIT;\x00")) {
		t.Fatal("commit not detected")
	}
	for _, s := range []string{"SELECT 'COMMIT;'\x00", "COMMIT; SELECT 1;\x00", "ROLLBACK;\x00"} {
		if isCommit('Q', []byte(s)) {
			t.Fatal("ambiguous query armed fault")
		}
	}
}
func TestFramesAndLimits(t *testing.T) {
	var b bytes.Buffer
	if e := writeFrame(&b, 'C', []byte("COMMIT\x00")); e != nil {
		t.Fatal(e)
	}
	k, p, e := readFrame(&b)
	if e != nil || k != 'C' || string(p) != "COMMIT\x00" {
		t.Fatal("wire frame")
	}
	bad := make([]byte, 5)
	bad[0] = 'Q'
	binary.BigEndian.PutUint32(bad[1:], maxFrame+1)
	if _, _, e = readFrame(bytes.NewReader(bad)); e == nil {
		t.Fatal("oversize accepted")
	}
}
func TestStartupNoCrossConnection(t *testing.T) {
	payload := []byte("user\x00tomopedidos_session_maintenance\x00database\x00" + database + "\x00application_name\x00" + runID + ":ambiguous-cleanup\x00\x00")
	b := make([]byte, 8+len(payload))
	binary.BigEndian.PutUint32(b, uint32(len(b)))
	binary.BigEndian.PutUint32(b[4:], 196608)
	copy(b[8:], payload)
	if !permittedStartup(b) {
		t.Fatal("approved client")
	}
	b = bytes.ReplaceAll(b, []byte(database), []byte("other"))
	if permittedStartup(b) {
		t.Fatal("cross database accepted")
	}
}
