#!/bin/bash
# Sync claude-config repo to ~/.claude/
# Run this after updating the repo to apply changes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "Syncing claude-config to ~/.claude/"
echo "Source: $SCRIPT_DIR"
echo "Target: $CLAUDE_DIR"
echo ""

# Ensure target directories exist
mkdir -p "$CLAUDE_DIR/agents"
mkdir -p "$CLAUDE_DIR/skills"
mkdir -p "$CLAUDE_DIR/commands"

# Sync agents
if [ -d "$SCRIPT_DIR/agents" ]; then
    echo -e "${YELLOW}Syncing agents...${NC}"

    # Copy from source
    for file in "$SCRIPT_DIR/agents"/*.md; do
        [ -e "$file" ] || continue
        filename=$(basename "$file")
        cp "$file" "$CLAUDE_DIR/agents/$filename"
        echo -e "  ${GREEN}✓${NC} $filename"
    done

    # Remove stale files
    for file in "$CLAUDE_DIR/agents"/*.md; do
        [ -e "$file" ] || continue
        filename=$(basename "$file")
        if [ ! -e "$SCRIPT_DIR/agents/$filename" ]; then
            rm "$file"
            echo -e "  ${RED}✗${NC} $filename (removed)"
        fi
    done
fi

# Sync skills (entire directories)
if [ -d "$SCRIPT_DIR/skills" ]; then
    echo -e "${YELLOW}Syncing skills...${NC}"

    # Copy from source
    for skill_dir in "$SCRIPT_DIR/skills"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        rm -rf "$CLAUDE_DIR/skills/$skill_name"
        cp -r "$skill_dir" "$CLAUDE_DIR/skills/$skill_name"
        echo -e "  ${GREEN}✓${NC} $skill_name/"
    done

    # Remove stale skills
    for skill_dir in "$CLAUDE_DIR/skills"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        if [ ! -d "$SCRIPT_DIR/skills/$skill_name" ]; then
            rm -rf "$skill_dir"
            echo -e "  ${RED}✗${NC} $skill_name/ (removed)"
        fi
    done
fi

# Sync commands
if [ -d "$SCRIPT_DIR/commands" ]; then
    echo -e "${YELLOW}Syncing commands...${NC}"

    # Copy from source
    for file in "$SCRIPT_DIR/commands"/*.md; do
        [ -e "$file" ] || continue
        filename=$(basename "$file")
        cp "$file" "$CLAUDE_DIR/commands/$filename"
        echo -e "  ${GREEN}✓${NC} $filename"
    done

    # Remove stale files
    for file in "$CLAUDE_DIR/commands"/*.md; do
        [ -e "$file" ] || continue
        filename=$(basename "$file")
        if [ ! -e "$SCRIPT_DIR/commands/$filename" ]; then
            rm "$file"
            echo -e "  ${RED}✗${NC} $filename (removed)"
        fi
    done
fi

echo ""
echo -e "${GREEN}Sync complete!${NC}"
