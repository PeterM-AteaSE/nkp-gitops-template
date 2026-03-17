#!/bin/bash
# Kubernetes Context Renaming Script
# Renames contexts to standard aliases
# Usage: ./rename-contexts.sh

echo "================================================"
echo "Kubernetes Context Renaming Script"
echo "================================================"
echo ""
echo "Current contexts:"
kubectl config get-contexts -o name
echo ""

read -p "Proceed with renaming? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "🔄 Renaming contexts..."
echo ""

renamed=0
skipped=0

# Function to rename if exists
rename_if_exists() {
    local old="$1"
    local new="$2"
    
    if kubectl config get-contexts "$old" &>/dev/null; then
        echo "  Renaming: $old → $new"
        if kubectl config rename-context "$old" "$new" &>/dev/null; then
            echo "  ✓ Success"
            ((renamed++))
        else
            echo "  ✗ Failed (may already exist or other error)"
            ((skipped++))
        fi
    else
        echo "  ⚠️  Context '$old' not found, skipping"
        ((skipped++))
    fi
}

# Perform renames
rename_if_exists "hbg-platform-prod01-admin@hbg-platform-prod01" "platform-p01"
rename_if_exists "hbg-platform-test01-admin@hbg-platform-test01" "platform-t01"
rename_if_exists "hbg-shared-prod01-admin@hbg-shared-prod01" "shared-p01"
rename_if_exists "hbg-shared-test01-admin@hbg-shared-test01" "shared-t01"
rename_if_exists "management-admin@management" "nkp-admin"

echo ""
echo "================================================"
echo "✅ Done!"
echo "   Renamed: $renamed"
echo "   Skipped: $skipped"
echo "================================================"
echo ""
echo "New contexts:"
kubectl config get-contexts -o name
echo ""
echo "Current context: $(kubectl config current-context)"
