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

echo "🧪 Testing Kira CLI Tool"
echo "========================="

# Build the tool
echo "📦 Building kira..."
go build -o kira cmd/kira/main.go
echo "✅ Build successful"

# Create test directory
ROOT_DIR="$(pwd)"
TEST_DIR="test-kira-$(date +%s)"
TEST_DIR_ABS="$ROOT_DIR/$TEST_DIR"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "📁 Created test directory: $TEST_DIR"

# Test 1: Initialize workspace
echo ""
echo "🔧 Test 1: Initialize workspace"
../kira init
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
../kira idea "Test idea for integration testing"
if grep -q "Test idea for integration testing" .work/IDEAS.md; then
    echo "✅ Idea added successfully"
else
    echo "❌ Idea addition failed"
    exit 1
fi

# Test 6: Create a work item via 'kira new' with explicit inputs
echo ""
echo "📋 Test 6: Create a work item via 'kira new' (with --input)"
../kira new prd "Test Feature From Inputs" todo \
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

# Determine created file path dynamically (first PRD in 1_todo)
WORK_ITEM_PATH=$(find .work/1_todo -maxdepth 1 -type f -name "*.prd.md" | head -n 1)
if [ -n "$WORK_ITEM_PATH" ] && [ -f "$WORK_ITEM_PATH" ]; then
    echo "✅ Work item created successfully: $WORK_ITEM_PATH"
else
    echo "❌ Work item creation failed"
    exit 1
fi

# Validate template fields were filled
if grep -q "^title: Test Feature From Inputs$" "$WORK_ITEM_PATH" && \
   grep -q "^status: todo$" "$WORK_ITEM_PATH" && \
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
if ../kira lint; then
    echo "✅ Lint check passed"
else
    echo "❌ Lint check failed"
    exit 1
fi

# Test 8: Doctor check
echo ""
echo "🩺 Test 8: Doctor check"
if ../kira doctor; then
    echo "✅ Doctor check passed"
else
    echo "❌ Doctor check failed"
    exit 1
fi

# Test 9: Move work item
echo ""
echo "🔄 Test 9: Move work item"
../kira move 001 doing
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
echo "❓ Test 10: Help commands"
if ../kira --help > /dev/null; then
    echo "✅ Main help works"
else
    echo "❌ Main help failed"
    exit 1
fi

if ../kira new --help > /dev/null; then
    echo "✅ New command help works"
else
    echo "❌ New command help failed"
    exit 1
fi

# Cleanup
echo ""
if [ "$KEEP" -eq 1 ] || [ "${KEEP_TEST_DIR:-0}" -ne 0 ]; then
  echo "ℹ️ Skipping cleanup; test directory preserved at: $TEST_DIR_ABS"
else
  echo "🧹 Cleaning up..."
  cd ..
  rm -rf "$TEST_DIR"
  rm -f kira
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

