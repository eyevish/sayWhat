#!/bin/bash
source scripts/common/dialog_ui.sh

run_dialog_data(){
    METADATA_FILE="scripts/common/dialogs.json"
    [[ -f "$1" ]]  && METADATA_FILE="$1" || return 11
    diag_id=$2
    RESULTS_FILE=$(mktemp)
    trap 'rm -f "$RESULTS_FILE"' EXIT

    while [ -n "$diag_id" ]; do

        row="$(jq --arg id "$diag_id"  '.[] | select (.id==$id)' $METADATA_FILE )"
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
                NEXTID=$(echo $row | jq --arg t $RESULT -r ' select (.tag==$t) | .next')
                ;;
            "menu")
                readarray -t OPTS < <(echo $row | jq -r '.options[] | (.tag, .item)')
                # OPTS=$(echo $row | jq -r '.options[] | "\"\(.tag)\" \"\(.item)\""')
                # OPTS=${OPTS//$'\n'/ }
                # RESULT=$(dialog "${ARGS[@]}" --menu "$TEXT" "$H" "$W" 5 "${OPTS[@]}" 2>&1 >/dev/tty)

                RESULT=$(ui_menu "$(echo $row | jq -r '.text')" "${OPTS[@]}")
                NEXTID=$(echo $row | jq --arg t $RESULT -r '.options[] | select (.tag==$t) | .next ')

                ;;
            "form")
                readarray -t OPTS < <(echo $row | jq -r '.options[] | (.tag, .variable, .default)')
                RESULT=$(ui_form "$(echo $row | jq -r '.text')" "${OPTS[@]}")
                echo $RESULT
                ;;
        esac

        # Capture the exit code to know which button was clicked
        EXIT_CODE=$?
        case $EXIT_CODE in
            0) BUTTON="ok" ;;
            1) BUTTON="cancel" ;;
            3) BUTTON="extra" ;;
            *) BUTTON="esc" ;;
        esac

        # Store both the value and the button pressed
        echo "${ID}_val=$RESULT" >> "$RESULTS_FILE"
        echo "${ID}_btn=$BUTTON" >> "$RESULTS_FILE"

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
outcome="$(run_dialog_data 'scripts/common/dialogs.json' 'values_yaml')"
echo $outcome