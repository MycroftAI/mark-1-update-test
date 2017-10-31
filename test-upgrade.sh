#!/usr/bin/env bash

log_dir="/var/log"

num_failed=0
num_succeeded=0

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

    echo "$log"

    if [ "$code" != "0" ]; then
        echo ":: FAILED to run $cmd_name"
        if [ -n "$log" ]; then
            echo
            echo "Output: $log"
            echo
        fi
        num_failed=$((num_failed + 1))
    else
        num_succeeded=$((num_succeeded + 1))
        echo ":: SUCCESS running $cmd_name"
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
    [ -n "$pid" ] && ps aux | grep "$pid"
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

# Send a message to the mycroft messagebus
# Usage: send_message MSG DATA_JSON
send_message() {
    msg="$1"
    data="${2:-\{\}}"
    python -c "from threading import Thread; from mycroft.messagebus.client.ws import WebsocketClient; from mycroft import Message; from time import sleep; ws = WebsocketClient(); Thread(target=ws.run_forever).start(); sleep(0.2); ws.emit(Message('$msg', data=$data)); ws.close()"
}

# Waits $3 seconds for $1 to appear in $2 log
# Usage: wait_for_str_in_log STRING LOG_NAME [TIMEOUT]
wait_for_str_in_log() {
    str="$1"
    log_name="$2"
    timeout="${3-10}"
    for i in $(seq 0 0.1 "$timeout"); do
        if grep -q "$str" "$log_dir/$log_name"; then
            return 0 
        fi
        sleep 0.1
    done
    return 1
}

# Checks if the query causes the output in the logs
# Usage: check_behavior QUERY OUTPUT
check_behavior() {
    query="$1"
    output="$2"

    reset_logs
    send_message 'recognizer_loop:utterance' '{"utterances": ["'"$1"'"]}'
    wait_for_str_in_log "$2" 'mycroft-*.log'
}

apt_is_locked() {
    fuser /var/lib/dpkg/lock >/dev/null 2>&1
}

wait_for_apt() {
    if apt_is_locked; then
        echo "Waiting to obtain dpkg lock file..."
        while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do echo .; sleep 0.5; done
    fi
}

set -e

mkdir -p logs

if [ "$1" != "-s" ]; then
    run wait_for_apt
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

run wait_for_str_in_log "Waiting for wake word" mycroft-voice.log

run check_behavior "what is the weather" "a high of"
run check_behavior "what time is it" "[AP]M"

echo
[ "$num_failed" -gt "0" ] && echo   "$   Failed: $num_failed"
[ "$num_succeeded" -gt "0" ] && echo "Succeeded: $num_succeeded"
echo

[ "$num_failed" = 0 ]
