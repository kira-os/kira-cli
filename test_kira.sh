#!/bin/bash

# Kira Integration Test Script
# This script tests the basic functionality of Kira

set -e

# Flags
KEEP=0
for arg in "$@"; do
  case "$arg" in
    -k|--keep)
      KEEP=1
      ;;
    -h|--help)
      echo "Usage: $0 [--keep|-k]"
      echo "  --keep, -k  Preserve the generated test directory (skip cleanup)"
      exit 0
      ;;
  esac
done

ROOT_DIR="$(pwd)"
KIRA_BIN="$ROOT_DIR/kira"

echo "🧪 Testing Kira CLI Tool"
echo "========================="

# Build the tool
echo "📦 Building kira..."
go build -o "$KIRA_BIN" cmd/kira/main.go
echo "✅ Build successful"

# Create test directory
BASE_DIR="e2e-test"
mkdir -p "$BASE_DIR"
TEST_DIR="$BASE_DIR/test-kira-$(date +%s)"
TEST_DIR_ABS="$ROOT_DIR/$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "📁 Created test directory: $TEST_DIR"

# Test 1: Initialize workspace
echo ""
echo "🔧 Test 1: Initialize workspace"
"$KIRA_BIN" init
if [ -d ".work" ]; then
    echo "✅ Workspace initialized successfully"
else
    echo "❌ Workspace initialization failed"
    exit 1
fi

# Test 2: Check directory structure
echo ""
echo "📂 Test 2: Check directory structure"
REQUIRED_DIRS=("0_backlog" "1_todo" "2_doing" "3_review" "4_done" "z_archive" "templates")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d ".work/$dir" ]; then
        echo "✅ Directory .work/$dir exists"
    else
        echo "❌ Directory .work/$dir missing"
        exit 1
    fi
done

# Ensure .gitkeep files exist in each directory
echo ""
echo "📄 Test 2b: Check .gitkeep files"
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -f ".work/$dir/.gitkeep" ]; then
        echo "✅ .gitkeep exists in .work/$dir"
    else
        echo "❌ .gitkeep missing in .work/$dir"
        exit 1
    fi
done

# Test 3: Check required files
echo ""
echo "📄 Test 3: Check required files"
REQUIRED_FILES=("IDEAS.md" "kira.yml")
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f ".work/$file" ]; then
        echo "✅ File .work/$file exists"
    else
        echo "❌ File .work/$file missing"
        exit 1
    fi
done

# Test 4: Check templates
echo ""
echo "📝 Test 4: Check templates"
TEMPLATE_FILES=("template.prd.md" "template.issue.md" "template.spike.md" "template.task.md")
for template in "${TEMPLATE_FILES[@]}"; do
    if [ -f ".work/templates/$template" ]; then
        echo "✅ Template .work/templates/$template exists"
    else
        echo "❌ Template .work/templates/$template missing"
        exit 1
    fi
done

# Test 5: Add an idea
echo ""
echo "💡 Test 5: Add an idea"
"$KIRA_BIN" idea "Test idea for integration testing"
if grep -q "Test idea for integration testing" .work/IDEAS.md; then
    echo "✅ Idea added successfully"
else
    echo "❌ Idea addition failed"
    exit 1
fi

# Test 6: Create a work item via 'kira new' with explicit inputs
echo ""
echo "📋 Test 6: Create a work item via 'kira new' (with --input, default status)"
"$KIRA_BIN" new prd "Test Feature From Inputs" \
  --input assigned=qa@example.com \
  --input estimate=5 \
  --input due=2025-12-31 \
  --input tags="frontend,api" \
  --input criteria1="Login works" \
  --input criteria2="Logout works" \
  --input context="Context text" \
  --input requirements="Requirements text" \
  --input implementation="Implementation notes" \
  --input release_notes="Release notes here"

# Determine created file path dynamically (prefer backlog default, then todo)
WORK_ITEM_PATH=$(find .work/0_backlog -maxdepth 1 -type f -name "*.prd.md" | head -n 1)
if [ -z "$WORK_ITEM_PATH" ]; then
  WORK_ITEM_PATH=$(find .work/1_todo -maxdepth 1 -type f -name "*.prd.md" | head -n 1)
fi
if [ -n "$WORK_ITEM_PATH" ] && [ -f "$WORK_ITEM_PATH" ]; then
    echo "✅ Work item created successfully: $WORK_ITEM_PATH"
else
    echo "❌ Work item creation failed"
    exit 1
fi

# Validate template fields were filled
if grep -q "^title: Test Feature From Inputs$" "$WORK_ITEM_PATH" && \
   grep -q "^status: backlog$" "$WORK_ITEM_PATH" && \
   grep -q "^kind: prd$" "$WORK_ITEM_PATH" && \
   grep -q "^assigned: qa@example.com$" "$WORK_ITEM_PATH" && \
   grep -q "^estimate: 5$" "$WORK_ITEM_PATH" && \
   grep -q "^due: 2025-12-31$" "$WORK_ITEM_PATH" && \
   grep -q "^tags: frontend,api$" "$WORK_ITEM_PATH" && \
   grep -q "^# Test Feature From Inputs$" "$WORK_ITEM_PATH"; then
    echo "✅ Template fields filled correctly from inputs"
else
    echo "❌ Template fields not filled as expected"
    echo "----- File contents -----"
    cat "$WORK_ITEM_PATH"
    echo "-------------------------"
    exit 1
fi

# Test 7: Lint check
echo ""
echo "🔍 Test 7: Lint check"
if "$KIRA_BIN" lint; then
    echo "✅ Lint check passed"
else
    echo "❌ Lint check failed"
    exit 1
fi

# Test 8: Doctor check
echo ""
echo "🩺 Test 8: Doctor check"
if "$KIRA_BIN" doctor; then
    echo "✅ Doctor check passed"
else
    echo "❌ Doctor check failed"
    exit 1
fi

# Test 9: Move work item
echo ""
echo "🔄 Test 9: Move work item"
"$KIRA_BIN" move 001 doing
MOVED_PATH=".work/2_doing/$(basename "$WORK_ITEM_PATH")"
if [ -f "$MOVED_PATH" ] && [ ! -f "$WORK_ITEM_PATH" ]; then
    echo "✅ Work item moved successfully"
else
    echo "❌ Work item move failed"
    echo "Expected moved path: $MOVED_PATH"
    echo "Original path: $WORK_ITEM_PATH"
    exit 1
fi

# Test 10: Help commands
echo ""
echo "❓ Test 10: Help commands and init flags"
if "$KIRA_BIN" --help > /dev/null; then
    echo "✅ Main help works"
else
    echo "❌ Main help failed"
    exit 1
fi

if "$KIRA_BIN" new --help > /dev/null; then
    echo "✅ New command help works"
else
    echo "❌ New command help failed"
    exit 1
fi

# Test init flags: fill-missing and force
echo ""
echo "🧪 Test 11: init --fill-missing and --force"
# Remove a folder and create sentinel
rm -rf .work/3_review
touch .work/1_todo/sentinel.txt
if "$KIRA_BIN" init --fill-missing; then
  if [ -d .work/3_review ] && [ -f .work/1_todo/sentinel.txt ]; then
    echo "✅ fill-missing restored folder without overwriting existing files"
  else
    echo "❌ fill-missing behavior incorrect"
    exit 1
  fi
else
  echo "❌ init --fill-missing failed"
  exit 1
fi

if "$KIRA_BIN" init --force; then
  if [ ! -f .work/1_todo/sentinel.txt ] && [ -f .work/3_review/.gitkeep ]; then
    echo "✅ force overwrote workspace and recreated structure"
  else
    echo "❌ force behavior incorrect"
    exit 1
  fi
else
  echo "❌ init --force failed"
  exit 1
fi

# Cleanup
echo ""
if [ "$KEEP" -eq 1 ] || [ "${KEEP_TEST_DIR:-0}" -ne 0 ]; then
  echo "ℹ️ Skipping cleanup; test directory preserved at: $TEST_DIR_ABS"
else
  echo "🧹 Cleaning up..."
  cd "$ROOT_DIR"
  rm -rf "$TEST_DIR"
  rm -f "$KIRA_BIN"
  echo "✅ Cleanup complete"
fi

echo ""
echo "🎉 All tests passed! Kira is working correctly."
echo ""
echo "📊 Test Summary:"
echo "  ✅ Workspace initialization"
echo "  ✅ Directory structure"
echo "  ✅ Required files"
echo "  ✅ Template system"
echo "  ✅ Idea capture"
echo "  ✅ Work item creation"
echo "  ✅ Lint validation"
echo "  ✅ Doctor check"
echo "  ✅ Work item movement"
echo "  ✅ Help system"
echo ""
echo "🚀 Kira is ready for use!"

