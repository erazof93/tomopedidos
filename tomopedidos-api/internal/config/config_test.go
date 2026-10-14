package config

import "testing"

func TestLoad(t *testing.T) {
	tests := []struct {
		name    string
		env     map[string]string
		wantErr bool
	}{
		{"defaults", nil, false},
		{"valid", map[string]string{"APP_ENV": "test", "HTTP_ADDR": "127.0.0.1:8081"}, false},
		{"invalid environment", map[string]string{"APP_ENV": "typo"}, true},
		{"invalid address", map[string]string{"HTTP_ADDR": "8080"}, true},
		{"empty host", map[string]string{"HTTP_ADDR": ":8080"}, true},
		{"invalid port", map[string]string{"HTTP_ADDR": "127.0.0.1:70000"}, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cfg, err := load(func(key string) string { return tt.env[key] })
			if (err != nil) != tt.wantErr {
				t.Fatalf("error = %v; want error %v", err, tt.wantErr)
			}
			if tt.name == "defaults" && (cfg.Environment != "development" || cfg.HTTPAddr != "127.0.0.1:8080") {
				t.Fatalf("unexpected defaults: %+v", cfg)
			}
		})
	}
}
