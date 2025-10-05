#!/bin/bash

# Kira Integration Test Script
# This script tests the basic functionality of Kira

set -e

echo "🧪 Testing Kira CLI Tool"
echo "========================="

# Build the tool
echo "📦 Building kira..."
go build -o kira cmd/kira/main.go
echo "✅ Build successful"

# Create test directory
TEST_DIR="test-kira-$(date +%s)"
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

# Test 6: Create a work item manually
echo ""
echo "📋 Test 6: Create a work item"
cat > .work/1_todo/001-test-feature.prd.md << 'EOF'
---
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
EOF

if [ -f ".work/1_todo/001-test-feature.prd.md" ]; then
    echo "✅ Work item created successfully"
else
    echo "❌ Work item creation failed"
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
if [ -f ".work/2_doing/001-test-feature.prd.md" ] && [ ! -f ".work/1_todo/001-test-feature.prd.md" ]; then
    echo "✅ Work item moved successfully"
else
    echo "❌ Work item move failed"
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
echo "🧹 Cleaning up..."
cd ..
rm -rf "$TEST_DIR"
rm -f kira
echo "✅ Cleanup complete"

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

