function _replace_command_token --description 'Remove first token from commandline and place cursor at start'
    set -l cmd (commandline)
    set -l rest (string replace -r '^\S+' '' -- $cmd)
    commandline -- $rest
    commandline -C 0
end
