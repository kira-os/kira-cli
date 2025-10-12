package commands

import (
	"fmt"

	"github.com/spf13/cobra"
)

// These variables can be overridden via -ldflags at build time
var (
	Version   = "dev"
	Commit    = "unknown"
	BuildDate = "unknown"
	Dirty     = "clean"
)

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print the kira version and build info",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("Version: %s\nCommit: %s\nBuildDate: %s\nState: %s\n", Version, Commit, BuildDate, Dirty)
	},
}
