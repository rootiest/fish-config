function __interactive_history_sub
    set -l current_line (commandline -b)
    set -l last_cmd $history[1]
    
    if string match -qr '(.+)/(.+)' -- "$current_line"
        set -l parts (string split '/' -- "$current_line")
        set -l old $parts[1]
        set -l new $parts[2]
        set -l expanded (string replace -a -- "$old" "$new" "$last_cmd")
        commandline -r "$expanded"
    else
        if test -z "$current_line"
            commandline -r "sudo $last_cmd"
        end
    end
    commandline -f repaint
end
