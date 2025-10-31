#!/bin/bash

is_container_process() {
    local pid=$1
    
    # check the namespace
    # if PID namespace and init are different it's a container
    local proc_ns
    local init_ns
    
    proc_ns=$(stat -L -c "%i" /proc/"$pid"/ns/pid 2>/dev/null)
    init_ns=$(stat -L -c "%i" /proc/1/ns/pid 2>/dev/null)
    
    # skip if couldnt read
    [[ -z "$proc_ns" || -z "$init_ns" ]] && return 1
    
    # if PID namespace is different it's a container
    if [[ "$proc_ns" != "$init_ns" ]]; then
        return 0
    fi
    
    # mount namespace check
    local proc_mnt_ns
    local init_mnt_ns
    
    proc_mnt_ns=$(stat -L -c "%i" /proc/"$pid"/ns/mnt 2>/dev/null)
    init_mnt_ns=$(stat -L -c "%i" /proc/1/ns/mnt 2>/dev/null)
    
    [[ -z "$proc_mnt_ns" || -z "$init_mnt_ns" ]] && return 1
    
    # if mount namespace is different it's a container
    if [[ "$proc_mnt_ns" != "$init_mnt_ns" ]]; then
        return 0
    fi
    
    return 1
}

pids=$(find /proc -maxdepth 1 -type d -name "[0-9]*" | grep -o '[0-9]*' | sort -n)

# arrays for strings of a proc
declare -a container_lines
declare -a host_lines

# title
header="USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND"

# divide the processes for containered and not containered
for pid in $pids; do
    if [[ ! -d "/proc/$pid" ]]; then
        continue
    fi
    
    process_info=$(ps -p "$pid" -o user,pid,%cpu,%mem,vsz,rss,tty,stat,start,time,comm --no-headers 2>/dev/null)
    
    if [[ -n "$process_info" ]]; then
        if is_container_process "$pid"; then
            container_lines+=("Process running in the container ---> $process_info")
        else
            host_lines+=("$process_info")
        fi
    fi
done

#print the table
{
    echo "$header"
    for line in "${host_lines[@]}"; do
        echo "$line"
    done
    if [[ ${#container_lines[@]} -gt 0 ]]; then
        echo ""
        for line in "${container_lines[@]}"; do
            echo "$line"
        done
        echo ""
    fi
} | column -t