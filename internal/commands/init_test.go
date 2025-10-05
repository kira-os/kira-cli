package commands

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestInitializeWorkspace(t *testing.T) {
	t.Run("creates workspace structure", func(t *testing.T) {
		tmpDir := t.TempDir()
		
		err := initializeWorkspace(tmpDir)
		require.NoError(t, err)
		
		// Check that .work directory was created
		workDir := filepath.Join(tmpDir, ".work")
		assert.DirExists(t, workDir)
		
		// Check that status folders were created
		statusFolders := []string{"0_backlog", "1_todo", "2_doing", "3_review", "4_done", "z_archive"}
		for _, folder := range statusFolders {
			assert.DirExists(t, filepath.Join(workDir, folder))
		}
		
		// Check that templates directory was created
		assert.DirExists(t, filepath.Join(workDir, "templates"))
		
		// Check that IDEAS.md was created
		ideasPath := filepath.Join(workDir, "IDEAS.md")
		assert.FileExists(t, ideasPath)
		
		// Check that kira.yml was created
		configPath := filepath.Join(workDir, "kira.yml")
		assert.FileExists(t, configPath)
	})
	
	t.Run("preserves existing files", func(t *testing.T) {
		tmpDir := t.TempDir()
		
		// Create a pre-existing file
		existingFile := filepath.Join(tmpDir, "existing.txt")
		err := os.WriteFile(existingFile, []byte("existing content"), 0644)
		require.NoError(t, err)
		
		err = initializeWorkspace(tmpDir)
		require.NoError(t, err)
		
		// Check that existing file is still there
		assert.FileExists(t, existingFile)
		content, err := os.ReadFile(existingFile)
		require.NoError(t, err)
		assert.Equal(t, "existing content", string(content))
	})
}

