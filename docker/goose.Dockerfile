FROM golang:1.27-bookworm AS builder

RUN GOBIN=/out go install github.com/pressly/goose/v3/cmd/goose@v3.29.0

FROM debian:bookworm-slim

COPY --from=builder /out/goose /usr/local/bin/goose

ENTRYPOINT ["goose"]
