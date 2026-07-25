#!/bin/bash
# ==============================================================================
# dialogDynamic.sh - Dynamic Dialog Flow Runner
# Author: eyeVish  2026-06-15
#
#
# Purpose:
#   This script dynamically renders a sequence of interactive TUI dialogs
#   (input boxes, menus, forms) based on a JSON metadata configuration file.
#   It processes user inputs, handles navigation flows between dialogs, and
#   outputs the final responses as a structured JSON object.
#
# Usage:
#   ./dialogDynamic.sh [metadata_file.json] [initial_dialog_id]
# ==============================================================================
source ./dialog_ui.sh

run_dialog_data() {
  METADATA_FILE="./dialogs.json"
  [[ -f "$1" ]] && METADATA_FILE="$1" || return 11
  diag_id=$2
  RESULTS_FILE=$(mktemp)
  trap 'rm -f "$RESULTS_FILE"' EXIT

  while [ -n "$diag_id" ]; do

    row="$(jq --arg id "$diag_id" '.[] | select (.id==$id)' $METADATA_FILE)"
    ID=$(echo "$row" | jq -r '.id')
    TYPE=$(echo "$row" | jq -r '.type')
    TEXT=$(echo "$row" | jq -r '.text')
    H=$(echo "$row" | jq -r '.height // 10')
    W=$(echo "$row" | jq -r '.width // 40')

    # Build button arguments dynamically
    ARGS=()
    OK_L=$(echo "$row" | jq -r '.ok_label // empty')
    [[ -n "$OK_L" ]] && ARGS+=(--ok-label "$OK_L")

    CAN_L=$(echo "$row" | jq -r '.cancel_label // empty')
    [[ -n "$CAN_L" ]] && ARGS+=(--cancel-label "$CAN_L")

    EXTRA_L=$(echo "$row" | jq -r '.extra_label // empty')
    [[ -n "$EXTRA_L" ]] && ARGS+=(--extra-button --extra-label "$EXTRA_L")

    case "$TYPE" in
    "inputbox")
      RESULT=$(dialog "${ARGS[@]}" --inputbox "$TEXT" "$H" "$W" 2>&1 >/dev/tty)
      EXIT_CODE=$?
      NEXTID=$(echo $row | jq --arg t $RESULT -r ' select (.tag==$t) | .next')
      ;;
    "menu")
      readarray -t OPTS < <(echo $row | jq -r '.options[] | (.tag, .item)')
      # OPTS=$(echo $row | jq -r '.options[] | "\"\(.tag)\" \"\(.item)\""')
      # OPTS=${OPTS//$'\n'/ }
      # RESULT=$(dialog "${ARGS[@]}" --menu "$TEXT" "$H" "$W" 5 "${OPTS[@]}" 2>&1 >/dev/tty)

      RESULT=$(ui_menu "$(echo $row | jq -r '.text')" "${OPTS[@]}")
      EXIT_CODE=$?
      NEXTID=$(echo $row | jq --arg t $RESULT -r '.options[] | select (.tag==$t) | .next ')

      ;;
    "form")
      num_options=$(echo "$row" | jq '.options | length')
      local form_fields=()
      for ((i = 0; i < num_options; i++)); do
        local tag=$(echo "$row" | jq -r ".options[$i].tag")
        local default=$(echo "$row" | jq -r ".options[$i].default")
        form_fields+=("$tag" "$default")
      done

      RESULT=$(ui_form "$(echo "$row" | jq -r '.text')" "${form_fields[@]}")
      EXIT_CODE=$?
      ;;
    esac

    # Capture the exit code to know which button was clicked
    case $EXIT_CODE in
    0) BUTTON="ok" ;;
    1) BUTTON="cancel" ;;
    3) BUTTON="extra" ;;
    *) BUTTON="esc" ;;
    esac

    # Store the value based on dialog type
    if [[ "$TYPE" == "form" ]]; then
      if [[ "$BUTTON" == "ok" ]]; then
        readarray -t RES_LINES <<<"$RESULT"
        for ((i = 0; i < num_options; i++)); do
          local var_name=$(echo "$row" | jq -r ".options[$i].variable")
          local val="${RES_LINES[i]}"
          echo "${ID}_${var_name}=$val" >>"$RESULTS_FILE"
        done
      fi
      echo "${ID}_btn=$BUTTON" >>"$RESULTS_FILE"
    else
      echo "${ID}_val=$RESULT" >>"$RESULTS_FILE"
      echo "${ID}_btn=$BUTTON" >>"$RESULTS_FILE"
    fi

    diag_id=$NEXTID

  done
  #jq -R -s 'split("\n") | map(select(length > 0) | split("=")) | map({(.): .}) | add' "$RESULTS_FILE"
  jq -R -s '
    split("\n") | 
    map(select(length > 0)) | 
    map(capture("(?<key>[^=]+)=(?<val>.*)")) | 
    map({(.key): .val}) | 
    add' "$RESULTS_FILE"
}
pwd
outcome="$(run_dialog_data './dialogs.json' 'values_yaml')"
echo $outcome
