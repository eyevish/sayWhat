#!/usr/bin/env bash
# ==============================================================================
# agbuild/validate_project_name.sh - Sample validation hook script
# ==============================================================================

RESULTS_FILE="$1"
DIALOG_ID="$2"

if [[ "$DIALOG_ID" == "web_config" ]]; then
  # Read project name from results file
  PROJECT_NAME=$(grep "^web_config_name=" "$RESULTS_FILE" | cut -d'=' -f2-)
  
  # Fail validation if project name contains spaces or special characters
  if [[ "$PROJECT_NAME" =~ [^a-zA-Z0-9_-] ]]; then
    exit 1
  fi
fi

exit 0
