package config

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestLoadConfig(t *testing.T) {
	t.Run("loads default config when no file exists", func(t *testing.T) {
		// Remove any existing config file
		os.Remove(".work/kira.yml")
		
		config, err := LoadConfig()
		require.NoError(t, err)
		assert.Equal(t, "1.0", config.Version)
		assert.NotEmpty(t, config.Templates)
		assert.NotEmpty(t, config.StatusFolders)
	})

	t.Run("loads config from file when exists", func(t *testing.T) {
		// Create a test config file
		testConfig := `version: "2.0"
templates:
  prd: "custom/prd.md"
status_folders:
  todo: "custom_todo"
`
		
		os.MkdirAll(".work", 0755)
		os.WriteFile(".work/kira.yml", []byte(testConfig), 0644)
		defer os.RemoveAll(".work")
		
		config, err := LoadConfig()
		require.NoError(t, err)
		assert.Equal(t, "2.0", config.Version)
		assert.Equal(t, "custom/prd.md", config.Templates["prd"])
		assert.Equal(t, "custom_todo", config.StatusFolders["todo"])
	})
}

func TestSaveConfig(t *testing.T) {
	t.Run("saves config to file", func(t *testing.T) {
		os.MkdirAll(".work", 0755)
		defer os.RemoveAll(".work")
		
		config := &Config{
			Version: "1.0",
			Templates: map[string]string{
				"prd": "test/prd.md",
			},
		}
		
		err := SaveConfig(config)
		require.NoError(t, err)
		
		// Verify file was created
		_, err = os.Stat(".work/kira.yml")
		assert.NoError(t, err)
	})
}

