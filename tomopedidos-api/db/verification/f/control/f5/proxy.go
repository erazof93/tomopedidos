package main

import (
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"strings"
	"sync/atomic"
	"time"
)

const maxFrame = 1024 * 1024

func readFrame(r io.Reader) (byte, []byte, error) {
	var header [5]byte
	if _, e := io.ReadFull(r, header[:]); e != nil {
		return 0, nil, e
	}
	size := int(binary.BigEndian.Uint32(header[1:]))
	if size < 4 || size > maxFrame {
		return 0, nil, errors.New("invalid PostgreSQL frame size")
	}
	payload := make([]byte, size-4)
	_, e := io.ReadFull(r, payload)
	return header[0], payload, e
}
func writeFrame(w io.Writer, kind byte, payload []byte) error {
	b := make([]byte, 5+len(payload))
	b[0] = kind
	binary.BigEndian.PutUint32(b[1:], uint32(4+len(payload)))
	copy(b[5:], payload)
	_, e := w.Write(b)
	return e
}
func isCommit(kind byte, payload []byte) bool {
	return kind == 'Q' && strings.EqualFold(strings.TrimSpace(strings.TrimSuffix(string(payload), "\x00")), "COMMIT;")
}
func permittedStartup(b []byte) bool {
	if len(b) < 8 || binary.BigEndian.Uint32(b[4:8]) != 196608 {
		return false
	}
	parts := strings.Split(string(b[8:]), "\x00")
	fields := map[string]string{}
	for i := 0; i+1 < len(parts) && parts[i] != ""; i += 2 {
		if _, ok := fields[parts[i]]; ok {
			return false
		}
		fields[parts[i]] = parts[i+1]
	}
	return fields["database"] == database && fields["user"] == "tomopedidos_session_maintenance" &&
		fields["application_name"] == runID+":ambiguous-cleanup" && fields["options"] == ""
}
func startup(client net.Conn, server net.Conn) error {
	for {
		var h [4]byte
		if _, e := io.ReadFull(client, h[:]); e != nil {
			return e
		}
		n := int(binary.BigEndian.Uint32(h[:]))
		if n < 8 || n > maxFrame {
			return errors.New("startup size rejected")
		}
		b := make([]byte, n)
		copy(b, h[:])
		if _, e := io.ReadFull(client, b[4:]); e != nil {
			return e
		}
		code := binary.BigEndian.Uint32(b[4:8])
		// Loopback-only fault fixture, no TLS interception. Reject SSL/GSS negotiation.
		if n == 8 && (code == 80877103 || code == 80877104) {
			if _, e := client.Write([]byte{'N'}); e != nil {
				return e
			}
			continue
		}
		if !permittedStartup(b) {
			return errors.New("startup actor/database/application rejected")
		}
		_, e := server.Write(b)
		return e
	}
}
func runProxy(receiptPath, mode string) error {
	if mode != "before-commit" && mode != "drop-ack" {
		return errors.New("unapproved fault mode")
	}
	host, e := os.Hostname()
	if e != nil || host != "4218b22fbb21" {
		return errors.New("fault proxy may run only inside approved F PostgreSQL container")
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
	listener, e := net.Listen("tcp", "127.0.0.1:5433")
	if e != nil {
		return errors.New("F loopback proxy bind failed")
	}
	defer listener.Close()
	if l, ok := listener.(*net.TCPListener); ok {
		_ = l.SetDeadline(time.Now().Add(30 * time.Second))
	}
	fmt.Println("F_PROXY_READY: single maintenance client, loopback only")
	client, e := listener.Accept()
	if e != nil {
		return errors.New("no approved fault client")
	}
	defer client.Close()
	listener.Close()
	server, e := net.DialTimeout("tcp", "127.0.0.1:5432", 3*time.Second)
	if e != nil {
		return errors.New("F loopback upstream unavailable")
	}
	defer server.Close()
	// Bound both accepted sockets; timeout produces unknown, never success.
	_ = client.SetDeadline(time.Now().Add(30 * time.Second))
	_ = server.SetDeadline(time.Now().Add(30 * time.Second))
	if e = startup(client, server); e != nil {
		return e
	}
	var armed atomic.Bool
	done := make(chan string, 2)
	go func() {
		for {
			k, p, e := readFrame(client)
			if e != nil {
				done <- "CLIENT_LOST_UNKNOWN"
				return
			}
			if k == 'P' || k == 'B' || k == 'E' {
				done <- "EXTENDED_PROTOCOL_REJECTED"
				return
			}
			if isCommit(k, p) {
				if mode == "before-commit" {
					done <- "COMMIT_NOT_FORWARDED_CLIENT_UNKNOWN"
					return
				}
				armed.Store(true)
			}
			if e = writeFrame(server, k, p); e != nil {
				done <- "UPSTREAM_WRITE_UNKNOWN"
				return
			}
		}
	}()
	go func() {
		for {
			k, p, e := readFrame(server)
			if e != nil {
				done <- "SERVER_LOST_UNKNOWN"
				return
			}
			if armed.Load() && k == 'C' && string(p) == "COMMIT\x00" {
				// Evidence received by proxy, withheld from caller. Fresh SQL reconciliation required.
				done <- "SERVER_COMMIT_COMPLETE_SEEN_ACK_WITHHELD_CALLER_UNKNOWN"
				return
			}
			if e = writeFrame(client, k, p); e != nil {
				done <- "CLIENT_WRITE_UNKNOWN"
				return
			}
		}
	}()
	event := <-done
	client.Close()
	server.Close()
	fmt.Println(event)
	fmt.Println("OUTCOME_UNKNOWN_TO_CALLER: no retry; reconcile in a fresh direct F connection")
	return nil
}
