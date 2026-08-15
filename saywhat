#!/usr/bin/env bash
# ==============================================================================
# agbuild/run.sh - Generic Builder / Scaffolder TUI Flow runner
# ==============================================================================

# Ensure dialog is installed
if ! command -v dialog &>/dev/null; then
  echo "Error: 'dialog' utility is required to run this script. Please install it." >&2
  exit 1
fi

# Ensure jq is installed
if ! command -v jq &>/dev/null; then
  echo "Error: 'jq' utility is required to parse configurations. Please install it." >&2
  exit 1
fi

# ==============================================================================
# Standard TUI wrappers
# Standardizes the drawing parameters (backtitles, sizes, titles) for dialog TUI boxes.
# ==============================================================================

ui_menu() {
  local prompt="$1"
  shift
  dialog --backtitle "agbuild - Project Builder" \
    --title "Configuration Wizard" \
    --stdout \
    --menu "$prompt" 0 0 0 "$@"
}

ui_form() {
  # Parses option flags passed before actual prompt arguments (e.g. --extra-button)
  local extra_opts=()
  while [[ "$1" =~ ^- ]]; do
    extra_opts+=("$1")
    shift
  done
  
  local prompt="$1"
  shift
  local fields=("$@")
  local form_args=()
  local row=1
  local total_args=${#fields[@]}

  # Dynamically calculate label widths so fields align perfectly
  local max_label_len=0
  for ((i = 0; i < total_args; i += 2)); do
    local label="${fields[i]}"
    [[ ${#label} -gt max_label_len ]] && max_label_len=${#label}
  done

  local label_width=$((max_label_len + 2))
  local field_width=30

  # Build field descriptor parameters for dialog:
  # Label, L_Y, L_X, InitValue, F_Y, F_X, F_Width, MaxInput
  for ((i = 0; i < total_args; i += 2)); do
    local label="${fields[i]}"
    local value="${fields[i + 1]}"
    form_args+=("$label" $row 1 "$value" $row $label_width $field_width 100)
    ((row++))
  done

  dialog "${extra_opts[@]}" --backtitle "agbuild - Project Builder" \
    --title "Configuration Wizard" \
    --stdout \
    --form "$prompt" 0 0 0 "${form_args[@]}"
}

ui_input() {
  local prompt="$1"
  local default_text="$2"
  dialog --backtitle "agbuild - Project Builder" \
    --title "Configuration Wizard" \
    --stdout \
    --inputbox "$prompt" 0 0 "$default_text"
}

# ==============================================================================
# Main Runner Loop
# Sequentially steps through nodes defined in the JSON configuration schema.
# ==============================================================================

run_wizard() {
  local config_file="$1"
  local diag_id="$2"
  local results_file
  results_file=$(mktemp)
  trap 'rm -f "$results_file"' EXIT

  # History stack arrays track visited IDs to support Back navigation transitions
  local history_stack=()

  while [[ -n "$diag_id" && "$diag_id" != "null" ]]; do
    # Extract metadata properties for the current node using jq
    local row
    row=$(jq --arg id "$diag_id" '.[] | select(.id==$id)' "$config_file")
    if [[ -z "$row" ]]; then
      echo "Error: dialog ID '$diag_id' not found in configuration." >&2
      return 1
    fi

    local id type text h w ok_label cancel_label extra_label back_enabled
    id=$(echo "$row" | jq -r '.id')
    type=$(echo "$row" | jq -r '.type')
    text=$(echo "$row" | jq -r '.text')
    h=$(echo "$row" | jq -r '.height // 0')
    w=$(echo "$row" | jq -r '.width // 0')
    back_enabled=$(echo "$row" | jq -r '.back_button // false')

    # Resolve variables template placeholders dynamically inside text prompt
    # Replaces ${id_val} syntax with current values stored in results file
    if [[ "$text" =~ \$\{([a-zA-Z0-9_]+)\} ]]; then
      while [[ "$text" =~ \$\{([a-zA-Z0-9_]+)\} ]]; do
        local full_match="${BASH_REMATCH[0]}"
        local var_key="${BASH_REMATCH[1]}"
        local var_val=""
        if [[ -f "$results_file" ]]; then
          var_val=$(grep "^${var_key}=" "$results_file" | cut -d'=' -f2-)
        fi
        # Remove raw JSON prefixes and string quotation marks
        var_val=$(echo "$var_val" | sed -e 's/^JSON://' -e 's/^"//' -e 's/"$//')
        text="${text//$full_match/$var_val}"
      done
    fi

    # Build dynamic action button configurations
    local extra_args=()
    ok_label=$(echo "$row" | jq -r '.ok_label // empty')
    [[ -n "$ok_label" ]] && extra_args+=(--ok-label "$ok_label")
    cancel_label=$(echo "$row" | jq -r '.cancel_label // empty')
    [[ -n "$cancel_label" ]] && extra_args+=(--cancel-label "$cancel_label")

    # If back button is enabled and history exists, override extra button as "Back"
    if [[ "$back_enabled" == "true" && ${#history_stack[@]} -gt 0 ]]; then
      extra_args+=(--extra-button --extra-label "Back")
    else
      extra_label=$(echo "$row" | jq -r '.extra_label // empty')
      [[ -n "$extra_label" ]] && extra_args+=(--extra-button --extra-label "$extra_label")
    fi

    local result=""
    local exit_code=0
    local next_id=""

    # Render specific TUI box type
    case "$type" in
      "menu")
        readarray -t opts < <(echo "$row" | jq -r '.options[] | (.tag, .item)')
        result=$(dialog "${extra_args[@]}" --backtitle "agbuild" --title "Configuration Wizard" --stdout --menu "$text" "$h" "$w" 0 "${opts[@]}" 2>/dev/tty >/dev/stdout)
        exit_code=$?
        result=$(echo "$result" | tr -d '\n\r')
        next_id=$(echo "$row" | jq --arg t "$result" -r '.options[] | select(.tag==$t) | .next // empty')
        ;;
      "form")
        local num_options
        num_options=$(echo "$row" | jq '.options | length')
        local form_fields=()
        for ((i = 0; i < num_options; i++)); do
          local tag val
          tag=$(echo "$row" | jq -r ".options[$i].tag")
          val=$(echo "$row" | jq -r ".options[$i].default // empty")
          form_fields+=("$tag" "$val")
        done
        result=$(ui_form "${extra_args[@]}" "$text" "${form_fields[@]}" 2>/dev/tty >/dev/stdout)
        exit_code=$?
        ;;
      "inputbox")
        local default_val
        default_val=$(echo "$row" | jq -r '.default // empty')
        result=$(dialog "${extra_args[@]}" --backtitle "agbuild" --title "Configuration Wizard" --stdout --inputbox "$text" "$h" "$w" "$default_val" 2>/dev/tty >/dev/stdout)
        exit_code=$?
        ;;
      "passwordbox")
        local default_val
        default_val=$(echo "$row" | jq -r '.default // empty')
        result=$(dialog "${extra_args[@]}" --backtitle "agbuild" --title "Configuration Wizard" --stdout --passwordbox "$text" "$h" "$w" "$default_val" 2>/dev/tty >/dev/stdout)
        exit_code=$?
        ;;
      "msgbox")
        # Non-input widget types render directly to /dev/tty
        dialog "${extra_args[@]}" --backtitle "agbuild" --title "Configuration Wizard" --msgbox "$text" "$h" "$w" >/dev/tty </dev/tty
        exit_code=$?
        ;;
      "yesno")
        dialog "${extra_args[@]}" --backtitle "agbuild" --title "Configuration Wizard" --yesno "$text" "$h" "$w" >/dev/tty </dev/tty
        exit_code=$?
        ;;
      "textbox")
        local filepath
        filepath=$(echo "$row" | jq -r '.file // empty')
        dialog "${extra_args[@]}" --backtitle "agbuild" --title "Configuration Wizard" --textbox "$filepath" "$h" "$w" >/dev/tty </dev/tty
        exit_code=$?
        ;;
      "checklist")
        readarray -t opts < <(echo "$row" | jq -r '.options[] | (.tag, .item, .status)')
        result=$(dialog "${extra_args[@]}" --backtitle "agbuild" --title "Configuration Wizard" --stdout --checklist "$text" "$h" "$w" 0 "${opts[@]}" 2>/dev/tty >/dev/stdout)
        exit_code=$?
        ;;
      "radiolist")
        readarray -t opts < <(echo "$row" | jq -r '.options[] | (.tag, .item, .status)')
        result=$(dialog "${extra_args[@]}" --backtitle "agbuild" --title "Configuration Wizard" --stdout --radiolist "$text" "$h" "$w" 0 "${opts[@]}" 2>/dev/tty >/dev/stdout)
        exit_code=$?
        ;;
    esac

    # Map exit code to standard button action values
    local button="ok"
    case $exit_code in
      0) button="ok" ;;
      1) button="cancel" ;;
      3) button="extra" ;;
      *) button="esc" ;;
    esac

    # Back Navigation: Pop step from history stack and loop back immediately
    if [[ "$button" == "extra" && "$back_enabled" == "true" && ${#history_stack[@]} -gt 0 ]]; then
      local last_idx=$((${#history_stack[@]} - 1))
      diag_id="${history_stack[last_idx]}"
      unset "history_stack[last_idx]"
      history_stack=("${history_stack[@]}") # Re-index array indices
      continue
    fi

    # Save inputs dynamically to the temp results file
    if [[ "$button" == "ok" ]]; then
      # Make a temporary copy of the results file to allow rolling back on failed validations
      local rollback_file
      rollback_file=$(mktemp)
      [[ -f "$results_file" ]] && cp "$results_file" "$rollback_file"

      if [[ "$type" == "form" ]]; then
        readarray -t res_lines <<< "$result"
        for ((i = 0; i < num_options; i++)); do
          local var_name val
          var_name=$(echo "$row" | jq -r ".options[$i].variable")
          val="${res_lines[i]}"
          echo "${id}_${var_name}=$val" >> "$results_file"
        done
      elif [[ "$type" == "checklist" ]]; then
        # Map multi-select values list to a clean JSON array
        local json_arr
        json_arr=$(echo "$result" | jq -R -c 'split(" ") | map(select(length > 0) | gsub("^\"|\"$"; ""))')
        echo "JSON:${id}_val=$json_arr" >> "$results_file"
      else
        echo "${id}_val=$result" >> "$results_file"
      fi

      # Process validation hook scripts
      local val_hook
      val_hook=$(echo "$row" | jq -r '.validation_hook // empty')
      if [[ -n "$val_hook" ]]; then
        # If hook command exits non-zero, restore rollback file and repeat step
        if ! eval "$val_hook \"$results_file\" \"$id\"" >/dev/tty 2>&1; then
          cp "$rollback_file" "$results_file"
          rm -f "$rollback_file"
          dialog --backtitle "agbuild" --title "Validation Error" --msgbox "Validation failed for this step. Please review inputs." 0 0 >/dev/tty </dev/tty
          continue
        fi
      fi
      rm -f "$rollback_file"
    fi
    echo "${id}_btn=$button" >> "$results_file"

    # Push successful step ID to history
    history_stack+=("$diag_id")

    # Resolve next dialog target transition
    if [[ -z "$next_id" || "$next_id" == "null" ]]; then
      next_id=$(echo "$row" | jq -r '.next // empty')
    fi
    diag_id="$next_id"
  done

  # Compile results file into a single structured JSON object output
  jq -R -s '
    split("\n") |
    map(select(length > 0)) |
    map(capture("(?<prefix>JSON:)?(?<key>[^=]+)=(?<val>.*)")) |
    map({
      key: .key,
      value: (if .prefix == "JSON:" then (.val | fromjson) else .val end)
    }) |
    from_entries' "$results_file"
}

# ==============================================================================
# Script Entrypoint
# ==============================================================================

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
CONFIG="${1:-$SCRIPT_DIR/demo_flow.json}"
START_NODE="${2:-welcome}"

output=$(run_wizard "$CONFIG" "$START_NODE")
exit_status=$?

if [[ $exit_status -eq 0 ]]; then
  echo "$output"
else
  exit $exit_status
fi
