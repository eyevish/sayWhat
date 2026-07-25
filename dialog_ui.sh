#!/bin/bash

# --- Global Defaults ---
# Standardize UI dimensions and titles
G_DIALOG_BACKTITLE="Magic IMM installer [Airgapped]"
G_DIALOG_TITLE="System Management"
G_DIALOG_WIDTH=50
G_DIALOG_HEIGHT=15

# A internal helper to run the dialog with standardized styling
_run_dialog() {
  # Usage: _run_dialog <box_type> <text> [extra_args...]
  local type=$1
  local text=$2
  shift 2
  dialog --backtitle "$G_DIALOG_BACKTITLE" \
    --title "$G_DIALOG_TITLE" \
    --stdout \
    "$type" "$text" "$@"
  local status=$?
  set +x
  return $status
}

# --- Standardized Wrappers ---

# 1. Message Box (No return value needed)
ui_msg() {
  local msg_width = $((${#1} + 7))
  #_run_dialog --msgbox "$1" 10 "$(( ${#1} + 7 ))"
  _run_dialog --msgbox "$1" 0 0 #0 0 auto sizes the box
}

# 2. Input Box (Returns the text entered)
ui_input() {
  # 2 args - Prompt_message and Default_text
  local prompt=$1
  local default_text=$2
  _run_dialog --inputbox "$prompt" 0 0 "$default_text"
}

# 3. Menu (Auto adjust width and height)
ui_menu() {
  local prompt="$1"
  shift # Remaining args are tag/item pairs
  local menu_height=$(($# / 2))
  menu_height=$(($menu_height + 7))
  #_run_dialog --menu "$prompt"  $(calc_menu_size "$@") 1 "$@"
  _run_dialog --menu "$prompt" 0 0 0 "$@"
}

# 4. Yes/No (Returns exit status in $?)
ui_yesno() {
  # We don't use _run_dialog here because we need the exit status, not stdout
  dialog --backtitle "$DIALOG_BACKTITLE" \
    --title "$DIALOG_TITLE" \
    --yesno "$1" 0 0 #Autosize
  return $?
}

ui_form() {
  local prompt=$1
  shift
  local fields=("$@")
  local form_args=()
  local row=1

  local total_args=${#fields[@]}

  # Dynamically compute the max label length to set the perfect label_width
  local max_label_len=0
  for ((i = 0; i < total_args; i += 2)); do
    local label="${fields[i]}"
    if (( ${#label} > max_label_len )); then
      max_label_len=${#label}
    fi
  done

  # label_width needs to cover the label and some padding (e.g., +2)
  local label_width=$((max_label_len + 2))
  # Use a standard field_width of 30, which can easily be configured or grow
  local field_width=30

  # Loop through arguments in pairs (Label, DefaultValue)
  for ((i = 0; i < total_args; i += 2)); do
    local label="${fields[i]}"
    local value="${fields[i + 1]}"

    # Define the 8 required params per field:
    # Label, L_Y, L_X, InitValue, F_Y, F_X, F_Width, MaxInput
    form_args+=("$label" $row 1 "$value" $row $label_width $field_width 100)
    ((row++))
  done

  # Execute dialog using the standardized wrapper _run_dialog
  local results
  results=$(_run_dialog --form "$prompt" 0 0 0 "${form_args[@]}")
  local exit_status=$?

  # If user pressed OK (exit 0), print results to stdout (newline separated)
  if [[ $exit_status -eq 0 ]]; then
    echo "$results"
    return 0
  else
    return 1
  fi
}

calc_menu_size() {
  #not used - but retained for futures yes.
  local args=("$@")
  local max_len_tag=0
  local max_len_text=0
  local lines=$#
  # Loop through every argument in $@
  for ((i = 0; i < $lines; i += 2)); do
    current_len_tag=${#args[i]}
    current_len_text=${#args[i + 1]}
    (($current_len_tag > $max_len_tag)) && max_len_tag=$current_len_tag
    (($current_len_text > $max_len_text)) && max_len_text=$current_len_text
  done
  echo $(($lines + 4)) $(($max_len_tag + $max_len_text + 10))
}
