package config

import (
	"fmt"
	"net"
	"os"
	"strconv"
)

type Config struct {
	Environment string
	HTTPAddr    string
}

func Load() (Config, error) { return load(os.Getenv) }

func load(getenv func(string) string) (Config, error) {
	cfg := Config{Environment: getenv("APP_ENV"), HTTPAddr: getenv("HTTP_ADDR")}
	if cfg.Environment == "" {
		cfg.Environment = "development"
	}
	if cfg.HTTPAddr == "" {
		cfg.HTTPAddr = "127.0.0.1:8080"
	}
	switch cfg.Environment {
	case "development", "test", "production":
	default:
		return Config{}, fmt.Errorf("APP_ENV must be development, test or production")
	}
	host, port, err := net.SplitHostPort(cfg.HTTPAddr)
	if err != nil || host == "" {
		return Config{}, fmt.Errorf("HTTP_ADDR must contain an explicit host and port")
	}
	n, err := strconv.Atoi(port)
	if err != nil || n < 1 || n > 65535 {
		return Config{}, fmt.Errorf("HTTP_ADDR port must be between 1 and 65535")
	}
	return cfg, nil
}
