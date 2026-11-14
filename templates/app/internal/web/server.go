// Package web serves the embedded UI and a small JSON API.
package web

import (
	"embed"
	"encoding/json"
	"io/fs"
	"net/http"
	"os"
	"time"
)

// Version is injected at build time:
//
//	go build -ldflags "-X <module>/internal/web.Version=1.2.3"
var Version = "dev"

//go:embed assets
var assets embed.FS

// Serve starts the HTTP server. addr looks like ":8099".
func Serve(addr, configPath string) error {
	sub, err := fs.Sub(assets, "assets")
	if err != nil {
		return err
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/api/session", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"version": Version,
			"time":    time.Now().Format(time.RFC3339),
			"host":    hostname(),
			"config":  configPath,
		})
	})
	mux.HandleFunc("/api/ping", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("pong"))
	})
	mux.Handle("/", http.FileServer(http.FS(sub)))

	srv := &http.Server{
		Addr:              addr,
		Handler:           noStore(mux),
		ReadHeaderTimeout: 10 * time.Second,
	}
	return srv.ListenAndServe()
}

// noStore keeps the browser honest while the UI is being developed on a router.
func noStore(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store, must-revalidate")
		h.ServeHTTP(w, r)
	})
}

func hostname() string {
	h, err := os.Hostname()
	if err != nil {
		return ""
	}
	return h
}
