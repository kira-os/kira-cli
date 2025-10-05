package commands

import (
	"os"
	"os/exec"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestCLIIntegration(t *testing.T) {
	t.Run("full workflow test", func(t *testing.T) {
		tmpDir := t.TempDir()
		os.Chdir(tmpDir)
		defer os.Chdir("/")
		
		// Build the kira binary for testing
		buildCmd := exec.Command("go", "build", "-o", "kira", "../../cmd/kira/main.go")
		err := buildCmd.Run()
		require.NoError(t, err)
		defer os.Remove("kira")
		
		// Test kira init
		initCmd := exec.Command("./kira", "init")
		output, err := initCmd.CombinedOutput()
		require.NoError(t, err, "init failed: %s", string(output))
		assert.Contains(t, string(output), "Initialized kira workspace")
		
		// Check that .work directory was created
		assert.DirExists(t, ".work")
		assert.DirExists(t, ".work/1_todo")
		assert.DirExists(t, ".work/2_doing")
		assert.DirExists(t, ".work/3_review")
		assert.DirExists(t, ".work/4_done")
		assert.DirExists(t, ".work/z_archive")
		assert.DirExists(t, ".work/templates")
		assert.FileExists(t, ".work/IDEAS.md")
		assert.FileExists(t, ".work/kira.yml")
		
		// Test kira idea
		ideaCmd := exec.Command("./kira", "idea", "Test idea for integration")
		output, err = ideaCmd.CombinedOutput()
		require.NoError(t, err, "idea failed: %s", string(output))
		assert.Contains(t, string(output), "Added idea: Test idea for integration")
		
		// Check that idea was added to IDEAS.md
		ideasContent, err := os.ReadFile(".work/IDEAS.md")
		require.NoError(t, err)
		assert.Contains(t, string(ideasContent), "Test idea for integration")
		
		// Test kira lint (should pass with no work items)
		lintCmd := exec.Command("./kira", "lint")
		output, err = lintCmd.CombinedOutput()
		require.NoError(t, err, "lint failed: %s", string(output))
		assert.Contains(t, string(output), "No issues found")
		
		// Test kira doctor (should pass with no duplicates)
		doctorCmd := exec.Command("./kira", "doctor")
		output, err = doctorCmd.CombinedOutput()
		require.NoError(t, err, "doctor failed: %s", string(output))
		assert.Contains(t, string(output), "No duplicate IDs found")
	})
	
	t.Run("work item creation and management", func(t *testing.T) {
		tmpDir := t.TempDir()
		os.Chdir(tmpDir)
		defer os.Chdir("/")
		
		// Build the kira binary for testing
		buildCmd := exec.Command("go", "build", "-o", "kira", "../../cmd/kira/main.go")
		err := buildCmd.Run()
		require.NoError(t, err)
		defer os.Remove("kira")
		
		// Initialize workspace
		initCmd := exec.Command("./kira", "init")
		output, err := initCmd.CombinedOutput()
		require.NoError(t, err, "init failed: %s", string(output))
		
		// Create a work item using template input
		// We'll create a simple work item by writing it directly since interactive input is hard to test
		workItemContent := `---
id: 001
title: Test Feature
status: todo
kind: prd
assigned: test@example.com
estimate: 3
created: 2024-01-01
---

# Test Feature

## Context
This is a test feature for integration testing.

## Requirements
- Implement user authentication
- Add login/logout functionality

## Acceptance Criteria
- [ ] User can log in with email/password
- [ ] User can log out
- [ ] Session is maintained across page refreshes

## Implementation Notes
Use JWT tokens for authentication.

## Release Notes
Added user authentication system.
`
		os.WriteFile(".work/1_todo/001-test-feature.prd.md", []byte(workItemContent), 0644)
		
		// Test kira lint
		lintCmd := exec.Command("./kira", "lint")
		output, err = lintCmd.CombinedOutput()
		require.NoError(t, err, "lint failed: %s", string(output))
		assert.Contains(t, string(output), "No issues found")
		
		// Test kira move
		moveCmd := exec.Command("./kira", "move", "001", "doing")
		output, err = moveCmd.CombinedOutput()
		require.NoError(t, err, "move failed: %s", string(output))
		assert.Contains(t, string(output), "Moved work item 001 to doing")
		
		// Check that file was moved
		assert.FileExists(t, ".work/2_doing/001-test-feature.prd.md")
		assert.NoFileExists(t, ".work/1_todo/001-test-feature.prd.md")
		
		// Test kira save (this will fail if git is not initialized, which is expected)
		saveCmd := exec.Command("./kira", "save", "Test commit")
		output, err = saveCmd.CombinedOutput()
		// We expect this to fail because git is not initialized
		assert.Error(t, err)
	})
	
	t.Run("template system test", func(t *testing.T) {
		tmpDir := t.TempDir()
		os.Chdir(tmpDir)
		defer os.Chdir("/")
		
		// Build the kira binary for testing
		buildCmd := exec.Command("go", "build", "-o", "kira", "../../cmd/kira/main.go")
		err := buildCmd.Run()
		require.NoError(t, err)
		defer os.Remove("kira")
		
		// Initialize workspace
		initCmd := exec.Command("./kira", "init")
		output, err := initCmd.CombinedOutput()
		require.NoError(t, err, "init failed: %s", string(output))
		
		// Check that templates were created
		templateFiles := []string{
			".work/templates/template.prd.md",
			".work/templates/template.issue.md",
			".work/templates/template.spike.md",
			".work/templates/template.task.md",
		}
		
		for _, templateFile := range templateFiles {
			assert.FileExists(t, templateFile)
			
			// Check that template contains input placeholders
			content, err := os.ReadFile(templateFile)
			require.NoError(t, err)
			assert.Contains(t, string(content), "<!--input-")
		}
		
		// Test help-inputs command
		helpCmd := exec.Command("./kira", "new", "prd", "--help-inputs")
		output, err = helpCmd.CombinedOutput()
		require.NoError(t, err, "help-inputs failed: %s", string(output))
		assert.Contains(t, string(output), "Available inputs for template 'prd'")
	})
}
