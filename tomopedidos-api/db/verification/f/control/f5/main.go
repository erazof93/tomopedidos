// F5 tool: defaults to offline checking. No database driver/dependency downloads.
package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

const runID = "tp-b2a-f-20261014-r01"
const container = runID + "-pg"
const database = "tp_b2a_f_20261014_r01"
const systemID = "7696590721605967915"
const native = "/usr/lib/postgresql/18/lib/pgxs/src/test/isolation/isolationtester"

type Pin struct {
	File         string `json:"file"`
	SHA256       string `json:"sha256"`
	Permutations int    `json:"permutations"`
}
type Manifest struct {
	RunID    string `json:"run_id"`
	Database string `json:"database"`
	SystemID string `json:"system_identifier"`
	Pins     []Pin  `json:"files"`
}

// Receipt is prepared only after fresh live snapshots+SQL preflight by the operator.
// It is evidence supplied by a trusted operator, not cryptographic authorization.
type Receipt struct {
	RunID       string    `json:"run_id"`
	Database    string    `json:"database"`
	SystemID    string    `json:"system_identifier"`
	ContainerID string    `json:"container_id"`
	VerifiedAt  time.Time `json:"verified_at"`
	NoPorts     bool      `json:"no_ports"`
	Exclusive   bool      `json:"exclusive_resources"`
	Version     int       `json:"goose_version"`
}

func checkReceipt(r Receipt, now time.Time) error {
	age := now.Sub(r.VerifiedAt)
	if r.RunID != runID || r.Database != database || r.SystemID != systemID ||
		r.ContainerID != "4218b22fbb213e9ae748e164f4cb429a74ba2d8307e386a1e0d09c750437d351" || !r.NoPorts || !r.Exclusive || r.Version != 4 || age < 0 || age > 30*time.Second {
		return errors.New("F5 fresh identity receipt rejected")
	}
	return nil
}
func readManifest(root string) (Manifest, error) {
	var m Manifest
	b, e := os.ReadFile(filepath.Join(root, "manifest.json"))
	if e != nil {
		return m, e
	}
	if e = json.Unmarshal(b, &m); e != nil {
		return m, e
	}
	if m.RunID != runID || m.Database != database || m.SystemID != systemID {
		return m, errors.New("F5 target mismatch")
	}
	for _, p := range m.Pins {
		if filepath.Base(p.File) != p.File {
			return m, errors.New("pin path escape")
		}
		b, e = os.ReadFile(filepath.Join(root, p.File))
		if e != nil {
			return m, e
		}
		sum := sha256.Sum256(b)
		if !strings.EqualFold(hex.EncodeToString(sum[:]), p.SHA256) {
			return m, errors.New("F5 pin drift")
		}
		if strings.HasSuffix(p.File, ".spec") {
			if strings.Contains(string(b), "__F_SYSTEM_ID_PENDING__") || !strings.Contains(string(b), systemID) {
				return m, errors.New("spec identity unenrolled")
			}
			if e = checkSpec(string(b), p.Permutations); e != nil {
				return m, e
			}
		}
	}
	return m, nil
}
func checkSpec(s string, expected int) error {
	stepRE := regexp.MustCompile(`(?m)^step "([a-z0-9_]+)"`)
	steps := map[string]bool{}
	for _, match := range stepRE.FindAllStringSubmatch(s, -1) {
		if steps[match[1]] {
			return errors.New("duplicate step")
		}
		steps[match[1]] = true
	}
	perm := regexp.MustCompile(`(?m)^permutation (.+)$`).FindAllStringSubmatch(s, -1)
	if len(perm) != expected || expected < 1 {
		return errors.New("permutation count mismatch")
	}
	for _, p := range perm {
		for _, n := range regexp.MustCompile(`"([a-z0-9_]+)"`).FindAllStringSubmatch(p[1], -1) {
			if !steps[n[1]] {
				return errors.New("unknown permutation step")
			}
		}
	}
	if strings.Contains(s, "pg_sleep") || strings.Contains(s, "DROP ROLE") || strings.Contains(s, "DROP DATABASE") {
		return errors.New("unsafe/sleep-based spec")
	}
	return nil // Structural lint only; native parser/SQL compilation remain execution checks.
}
func auditOutput(b []byte, count int) error {
	if bytes.Contains(b, []byte("ERROR:")) || bytes.Contains(b, []byte("FATAL:")) || bytes.Contains(b, []byte("PANIC:")) || regexp.MustCompile(`(?m)^(setup|teardown|setup of session [^:]+) failed:`).Match(b) {
		return errors.New("native output contains failure; stop and reconcile")
	}
	if bytes.Count(b, []byte("starting permutation:")) != count {
		return errors.New("incomplete native permutations")
	}
	return nil // Does NOT approve results; golden comparison+review is mandatory.
}
func runNative(root, name, receiptPath string, caseNumber int) error {
	m, e := readManifest(root)
	if e != nil {
		return e
	}
	var pin *Pin
	for i := range m.Pins {
		if m.Pins[i].File == name {
			pin = &m.Pins[i]
		}
	}
	if pin == nil || !strings.HasSuffix(name, ".spec") {
		return errors.New("unapproved spec")
	}
	var r Receipt
	b, e := os.ReadFile(receiptPath)
	if e != nil {
		return e
	}
	if e = json.Unmarshal(b, &r); e != nil {
		return e
	}
	if e = checkReceipt(r, time.Now()); e != nil {
		return e
	}
	b, e = os.ReadFile(filepath.Join(root, name))
	if e != nil {
		return e
	}
	// Run exactly one permutation per invocation; never advance to another after failure.
	lines := strings.Split(string(b), "\n")
	selected := []string{}
	seen := 0
	for _, line := range lines {
		if strings.HasPrefix(line, "permutation ") {
			seen++
			if seen != caseNumber {
				continue
			}
		}
		selected = append(selected, line)
	}
	if caseNumber < 1 || caseNumber > pin.Permutations {
		return errors.New("case number not approved")
	}
	b = []byte(strings.Join(selected, "\n"))
	// One Docker invocation. All libpq destinations explicit; no user DSN arguments.
	conn := "host=127.0.0.1 port=5432 dbname=" + database + " user=tomopedidos_bootstrap sslmode=disable application_name=" + runID + ":f5 options='-c search_path=pg_catalog' connect_timeout=3"
	shell := "PGPASSWORD=$POSTGRES_PASSWORD PG_TEST_TIMEOUT_DEFAULT=10 exec " + native + " \"" + conn + "\""
	cmd := exec.Command("docker", "--context", "default", "exec", "-i", container, "sh", "-c", shell)
	cmd.Stdin = bytes.NewReader(b)
	// No host deadline kill: stopping Docker CLI alone does not stop server workers.
	out, e := cmd.CombinedOutput()
	capture := filepath.Join(root, "captures")
	if err := os.MkdirAll(capture, 0700); err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(capture, fmt.Sprintf("%s.case%d.actual", name, caseNumber)), out, 0600); err != nil {
		return err
	}
	if e != nil {
		return errors.New("native process failed; capture saved; no retry/teardown")
	}
	if e = auditOutput(out, 1); e != nil {
		return e
	}
	fmt.Println("CAPTURED_NOT_APPROVED: review results/waits against matrix; reconcile fixtures and locks")
	return nil
}
func main() {
	mode := flag.String("mode", "check", "check, native, proxy")
	root := flag.String("root", ".", "F5 artifact directory")
	spec := flag.String("spec", "", "pinned spec basename")
	receipt := flag.String("receipt", "", "fresh private F identity receipt")
	approval := flag.String("approval", "", "explicit future execution scope token")
	fault := flag.String("fault", "", "before-commit or drop-ack")
	caseNumber := flag.Int("case", 0, "one reviewed permutation number")
	flag.Parse()
	var e error
	switch *mode {
	case "check":
		_, e = readManifest(*root)
		if e == nil {
			fmt.Println("PASS F5 offline pins/target/permutations; no Docker/SQL executed")
		}
	case "native":
		if *approval != "F5_NATIVE_ONLY_"+systemID {
			e = errors.New("separate F5 native execution approval required")
		} else {
			e = runNative(*root, *spec, *receipt, *caseNumber)
		}
	case "proxy":
		if *approval != "F5_FAULT_ONLY_"+systemID {
			e = errors.New("separate F5 fault execution approval required")
		} else {
			e = runProxy(*receipt, *fault)
		}
	default:
		e = errors.New("unknown mode")
	}
	if e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
}
