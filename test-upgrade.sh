#!/usr/bin/env bash

log_folder="logs"
log_dir="/var/logs"

num_failed=0
num_succeeded=0

# Checks if the binary executable exists in the PATH
# Usage: found_exe EXE_NAME
found_exe() {
    hash "$1" 2>/dev/null
}

setup_colors() {
    if found_exe tput; then
        green="$(tput setaf 2; tput bold)"
        red="$(tput setaf 1; tput bold)"
        white="$(tput setaf 7; tput bold)"

        reset="$(tput sgr0)"
    fi
}

# Runs a command, tracking the status of success or failure
# Usage: run CMD_NAME CMD_ARGS
run() {
    cmd_name="$@"
    cmd=''
    for i in "$@"; do
        if [ "$i" = "!" ]; then
            cmd="$cmd $i"
        else
            i="${i//\\/\\\\}"
            cmd="$cmd \"${i//\"/\\\"}\""
        fi
    done
    local log
    printf "$cmd_name..."
    set +e
    log="$(set -e; eval "$cmd" 2>&1 )"
    local code="$?"
    set -e
    printf "\r\t\t\t\t\r"

    echo "$log" > "$log_folder/$cmd.log"

    if [ "$code" != "0" ]; then
        echo "${red}Failed$reset to run $white$cmd_name$reset"
        if [ -n "$log" ]; then
            echo
            echo "${white}Output:$reset $log"
            echo
        fi
        num_failed=$((num_failed + 1))
    else
        num_succeeded=$((num_succeeded + 1))
        echo "${green}Success$reset running $white$cmd_name$reset"
    fi
}

setup_keys() {
    sudo apt-get install -y apt-transport-https
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys F3B1AA8B
}

# Usage: set_repo stable|unstable
set_repo() {
    if [ "$1" = "stable" ]; then
        repo_name="debian"
    elif [ "$1" = "unstable" ]; then
        repo_name="debian-unstable"
    fi
    sudo bash -c "echo \"deb http://repo.mycroft.ai/repos/apt/debian $repo_name main\" > /etc/apt/sources.list.d/repo.mycroft.ai.list"
    sudo apt-get update
}

# Usage: check_process skills|speech-client|...
check_process() {
    file="/var/run/mycroft-$1.pid"
    pid="$(cat "$file")"
    num_processes="$(ps aux | grep "$pid" | grep "python.*" | wc -l)"
    [ -f "$file" ] && ps -p "$pid" && [ "$num_processes" = "1" ]
}

# Usage: check_processes [dead]
check_processes() {
    [ "$1" = "dead" ] && local flag="!"
    run $flag check_process audio
    run $flag check_process enclosure-client
    run $flag check_process messagebus
    run $flag check_process skills
    run $flag check_process speech-client
    run $flag check_process wifi-setup-client
}

# Usage: reset_logs [skills|speech-client|...]
reset_logs() {
    proc="${proc:-*}"
    for i in $log_dir/mycroft-$proc; do
        echo "Clearing $i..."
        sudo bash -c "echo > \"$i\""
    done
}

# Usage: is_in_logs REGEX
is_in_logs() {
    regex="$1"
    cat $log_dir/mycroft-* | grep "$regex"
}

# Send a message to the mycroft messagebus
# Usage: send_message MSG DATA_JSON
send_message() {
    msg="$1"
    data="${2:-\{\}}"
    python -c "from threading import Thread; from mycroft.messagebus.client.ws import WebsocketClient; from mycroft import Message; from time import sleep; ws = WebsocketClient(); Thread(target=ws.run_forever).start(); sleep(0.2); ws.emit(Message('$msg', data=$data)); ws.close()"
}

# Checks if the query causes the output in the logs
# Usage: check_behavior QUERY OUTPUT
check_behavior() {
    query="$1"
    output="$2"

    reset_logs
    send_message 'recognizer_loop:utterance' '{"utterances": ["'"$1"'"]}'
    sleep 2
    is_in_logs "$2"
}

set -e

mkdir -p logs
setup_colors

if [ "$1" != "-s" ]; then
    run setup_keys

    run set_repo stable
    if dpkg --list | grep -q "mycroft-*"; then
        run sudo apt-get remove -y mycroft-*
    fi
    check_processes dead

    run sudo apt-get install -y mycroft-mark-1
    check_processes

    run set_repo unstable
    run sudo apt-get install -y mycroft-mark-1
    check_processes
else
    shift
fi

log_dir="${1:-$log_dir}"

run check_behavior "what is the weather" "a high of"
run check_behavior "what time is it" "[AP]M"

echo
[ "$num_failed" -gt "0" ] && echo   "${red}   Failed${reset}: $num_failed"
[ "$num_succeeded" -gt "0" ] && echo "${green}Succeeded${reset}: $num_succeeded"
echo

[ "$num_failed" = 0 ]
