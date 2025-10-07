package commands

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
	"kira/internal/config"
	"kira/internal/templates"
)

var initCmd = &cobra.Command{
	Use:   "init [folder]",
	Short: "Initialize a kira workspace",
	Long:  `Creates the files and folders used by kira in the specified directory.`,
	Args:  cobra.MaximumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		targetDir := "."
		if len(args) > 0 {
			targetDir = args[0]
		}

		return initializeWorkspace(targetDir)
	},
}

func initializeWorkspace(targetDir string) error {
	// Create .work directory
	workDir := filepath.Join(targetDir, ".work")
	if err := os.MkdirAll(workDir, 0755); err != nil {
		return fmt.Errorf("failed to create .work directory: %w", err)
	}

	// Create status folders
	cfg := &config.DefaultConfig
	for _, folder := range cfg.StatusFolders {
		folderPath := filepath.Join(workDir, folder)
		if err := os.MkdirAll(folderPath, 0755); err != nil {
			return fmt.Errorf("failed to create folder %s: %w", folder, err)
		}
	}

	// Create templates directory and default templates
	if err := templates.CreateDefaultTemplates(workDir); err != nil {
		return fmt.Errorf("failed to create default templates: %w", err)
	}

	// Create IDEAS.md file
	ideasPath := filepath.Join(workDir, "IDEAS.md")
	ideasContent := `# Ideas

This file is for capturing quick ideas and thoughts that don't fit into formal work items yet.

## How to use
- Add ideas with timestamps using ` + "`kira idea \"your idea here\"`" + `
- Or manually add entries below

## Ideas

`
	if err := os.WriteFile(ideasPath, []byte(ideasContent), 0644); err != nil {
		return fmt.Errorf("failed to create IDEAS.md: %w", err)
	}

    // Create kira.yml config file under the target directory
    if err := config.SaveConfigToDir(&config.DefaultConfig, targetDir); err != nil {
		return fmt.Errorf("failed to create kira.yml: %w", err)
	}

	fmt.Printf("Initialized kira workspace in %s\n", targetDir)
	return nil
}
