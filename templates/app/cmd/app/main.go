package main

import (
	"flag"
	"fmt"
	"os"

	"__MODULE__/internal/web"
)

func main() {
	config := flag.String("config", "/opt/etc/__APP__/config.json", "path to config.json")
	listen := flag.String("listen", ":__PORT__", "listen address")
	showVersion := flag.Bool("version", false, "print version and exit")
	flag.Parse()

	if *showVersion {
		fmt.Println(web.Version)
		return
	}
	if err := web.Serve(*listen, *config); err != nil {
		fmt.Fprintln(os.Stderr, "fatal:", err)
		os.Exit(1)
	}
}
