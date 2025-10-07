package commands

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/spf13/cobra"
	"kira/internal/config"
	"kira/internal/templates"
	"kira/internal/validation"
)

var newCmd = &cobra.Command{
	Use:   "new [template] [work-item] [status] [description]",
	Short: "Create a new work item",
	Long: `Creates a new work item from a template in the specified status folder.
All arguments are optional - will prompt for selection if not provided.`,
	Args: cobra.MaximumNArgs(4),
	RunE: func(cmd *cobra.Command, args []string) error {
		if err := checkWorkDir(); err != nil {
			return err
		}

		cfg, err := config.LoadConfig()
		if err != nil {
			return fmt.Errorf("failed to load config: %w", err)
		}

		ignoreInput, _ := cmd.Flags().GetBool("ignore-input")
		inputValues, _ := cmd.Flags().GetStringToString("input")
		helpInputs, _ := cmd.Flags().GetBool("help-inputs")

		return createWorkItem(cfg, args, ignoreInput, inputValues, helpInputs)
	},
}

func init() {
	newCmd.Flags().Bool("ignore-input", false, "Skip interactive input prompts")
    newCmd.Flags().StringToStringP("input", "i", nil, "Provide input values directly (e.g., --input due=2025-10-01)")
	newCmd.Flags().Bool("help-inputs", false, "List available input variables for a template")
}

func createWorkItem(cfg *config.Config, args []string, ignoreInput bool, inputValues map[string]string, helpInputs bool) error {
	var template, title, status string

	// Parse arguments
	if len(args) > 0 {
		template = args[0]
	}
	if len(args) > 1 {
		title = args[1]
	}
	if len(args) > 2 {
		status = args[2]
	}

	// Get template if not provided
	if template == "" {
		if helpInputs {
			return fmt.Errorf("template must be specified when using --help-inputs")
		}
		var err error
		template, err = selectTemplate(cfg)
		if err != nil {
			return err
		}
	}

	// Show help for template inputs if requested
	if helpInputs {
		return showTemplateInputs(cfg, template)
	}

	// Get title if not provided
	if title == "" && !ignoreInput {
		var err error
		title, err = promptString("Enter work item title: ")
		if err != nil {
			return err
		}
	}

	// Get status if not provided
	if status == "" {
		if ignoreInput {
			status = "todo" // default
		} else {
			var err error
			status, err = selectStatus(cfg)
			if err != nil {
				return err
			}
		}
	}

	// Get next ID
	nextID, err := validation.GetNextID()
	if err != nil {
		return fmt.Errorf("failed to get next ID: %w", err)
	}

	// Prepare input values
	inputs := make(map[string]string)
	inputs["id"] = nextID
	inputs["title"] = title
	inputs["status"] = status
	inputs["created"] = time.Now().Format("2006-01-02")

	// Add any provided input values
	for k, v := range inputValues {
		inputs[k] = v
	}

	// Get template inputs and prompt for missing ones
	if !ignoreInput {
		templatePath := filepath.Join(".work", cfg.Templates[template])
		templateInputs, err := templates.GetTemplateInputs(templatePath)
		if err != nil {
			return fmt.Errorf("failed to get template inputs: %w", err)
		}

		for _, input := range templateInputs {
			if _, exists := inputs[input.Name]; !exists {
				value, err := promptForInput(input)
				if err != nil {
					return err
				}
				inputs[input.Name] = value
			}
		}
	}

	// Generate work item content
	templatePath := filepath.Join(".work", cfg.Templates[template])
	content, err := templates.ProcessTemplate(templatePath, inputs)
	if err != nil {
		return fmt.Errorf("failed to process template: %w", err)
	}

	// Create filename
	filename := fmt.Sprintf("%s-%s.%s.md", nextID, kebabCase(title), template)
	statusFolder := cfg.StatusFolders[status]
	filePath := filepath.Join(".work", statusFolder, filename)

	// Write file
	if err := os.WriteFile(filePath, []byte(content), 0644); err != nil {
		return fmt.Errorf("failed to write work item file: %w", err)
	}

	fmt.Printf("Created work item %s in %s\n", nextID, statusFolder)
	return nil
}

func selectTemplate(cfg *config.Config) (string, error) {
	fmt.Println("Available templates:")
	var templates []string
	for template := range cfg.Templates {
		templates = append(templates, template)
	}

	for i, template := range templates {
		fmt.Printf("%d. %s\n", i+1, template)
	}

	fmt.Print("Select template (number): ")
	reader := bufio.NewReader(os.Stdin)
	input, err := reader.ReadString('\n')
	if err != nil {
		return "", err
	}

	choice, err := strconv.Atoi(strings.TrimSpace(input))
	if err != nil || choice < 1 || choice > len(templates) {
		return "", fmt.Errorf("invalid template selection")
	}

	return templates[choice-1], nil
}

func selectStatus(cfg *config.Config) (string, error) {
	fmt.Println("Available statuses:")
	var statuses []string
	for status := range cfg.StatusFolders {
		statuses = append(statuses, status)
	}

	for i, status := range statuses {
		fmt.Printf("%d. %s\n", i+1, status)
	}

	fmt.Print("Select status (number): ")
	reader := bufio.NewReader(os.Stdin)
	input, err := reader.ReadString('\n')
	if err != nil {
		return "", err
	}

	choice, err := strconv.Atoi(strings.TrimSpace(input))
	if err != nil || choice < 1 || choice > len(statuses) {
		return "", fmt.Errorf("invalid status selection")
	}

	return statuses[choice-1], nil
}

func showTemplateInputs(cfg *config.Config, template string) error {
	templatePath := filepath.Join(".work", cfg.Templates[template])
	inputs, err := templates.GetTemplateInputs(templatePath)
	if err != nil {
		return fmt.Errorf("failed to get template inputs: %w", err)
	}

	fmt.Printf("Available inputs for template '%s':\n", template)
	for _, input := range inputs {
		fmt.Printf("- %s (%s): %s\n", input.Name, input.Type, input.Description)
		if len(input.Options) > 0 {
			fmt.Printf("  Options: %s\n", strings.Join(input.Options, ", "))
		}
	}

	return nil
}

func promptForInput(input templates.Input) (string, error) {
	prompt := fmt.Sprintf("Enter %s (%s): ", input.Name, input.Description)

	switch input.Type {
	case templates.InputString:
		if len(input.Options) > 0 {
			return promptStringOptions(prompt, input.Options)
		}
		return promptString(prompt)
	case templates.InputNumber:
		return promptNumber(prompt)
	case templates.InputDateTime:
		return promptDateTime(prompt, input.DateFormat)
	default:
		return promptString(prompt)
	}
}

func promptString(prompt string) (string, error) {
	fmt.Print(prompt)
	reader := bufio.NewReader(os.Stdin)
	input, err := reader.ReadString('\n')
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(input), nil
}

func promptStringOptions(prompt string, options []string) (string, error) {
	fmt.Println(prompt)
	for i, option := range options {
		fmt.Printf("%d. %s\n", i+1, option)
	}
	fmt.Print("Select option (number): ")

	reader := bufio.NewReader(os.Stdin)
	input, err := reader.ReadString('\n')
	if err != nil {
		return "", err
	}

	choice, err := strconv.Atoi(strings.TrimSpace(input))
	if err != nil || choice < 1 || choice > len(options) {
		return "", fmt.Errorf("invalid option selection")
	}

	return options[choice-1], nil
}

func promptNumber(prompt string) (string, error) {
	fmt.Print(prompt)
	reader := bufio.NewReader(os.Stdin)
	input, err := reader.ReadString('\n')
	if err != nil {
		return "", err
	}

	// Validate it's a number
	_, err = strconv.Atoi(strings.TrimSpace(input))
	if err != nil {
		return "", fmt.Errorf("invalid number: %v", err)
	}

	return strings.TrimSpace(input), nil
}

func promptDateTime(prompt, format string) (string, error) {
	fmt.Printf("%s (format: %s): ", prompt, format)
	reader := bufio.NewReader(os.Stdin)
	input, err := reader.ReadString('\n')
	if err != nil {
		return "", err
	}

	// Validate date format
	_, err = time.Parse(format, strings.TrimSpace(input))
	if err != nil {
		return "", fmt.Errorf("invalid date format: %v", err)
	}

	return strings.TrimSpace(input), nil
}

func kebabCase(s string) string {
	// Simple kebab case conversion
	s = strings.ToLower(s)
	s = strings.ReplaceAll(s, " ", "-")
	s = strings.ReplaceAll(s, "_", "-")
	return s
}
