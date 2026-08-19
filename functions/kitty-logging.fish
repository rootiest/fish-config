# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

# CATEGORY
#   14-miscellaneous
#
# COMPONENT
#   logging/terminal-capture
#
# SYNOPSIS
#   kitty-logging [install | uninstall | status | dismiss] [-h]
#
# DESCRIPTION
#   Manages the fish-config Kitty scrollback watcher that powers C5 logging.
#   `install` symlinks the canonical watcher into the Kitty config dir (so it
#   always tracks the source) and wires it into kitty.conf via a
#   sentinel-marked managed block, commenting out any conflicting active
#   watcher line to avoid double-capture. `uninstall` reverses it. `status`
#   reports wiring, installed watcher version, and C5 logging state. `dismiss`
#   silences the per-session setup reminder.
#
#   Runtime capture stays governed by the C5 .logging_disabled sentinel, so
#   disabling __fish_config_op_logging makes the watcher inert without
#   uninstalling. Install affects new Kitty windows only.
#
# ARGUMENTS
#   install    Symlink the watcher and add the managed block to kitty.conf
#   uninstall  Remove the managed block and the watcher symlink
#   status     Report wiring, watcher version, and C5 logging state
#   dismiss    Stop the per-session reminder
#   -h, --help Show this help
#
# EXIT STATUS
#   0  Success
#   1  Unknown subcommand/flag, kitty missing, or a write failure
#
# EXAMPLE
#   kitty-logging install
#   kitty-logging status
function kitty-logging --description 'Install/manage the fish-config Kitty scrollback watcher'
    set -l c_head (set_color --bold cyan)
    set -l c_cmd (set_color --bold white)
    set -l c_flag (set_color yellow)
    set -l c_ok (set_color green)
    set -l c_warn (set_color yellow)
    set -l c_err (set_color red)
    set -l c_dim (set_color brblack)
    set -l c_reset (set_color normal)

    set -l cmd $argv[1]

    if test -z "$cmd"; or contains -- "$cmd" -h --help
        echo "$c_head""Usage:$c_reset $c_cmd""kitty-logging$c_reset $c_flag""[install|uninstall|status|dismiss]$c_reset $c_flag""[-h]$c_reset"
        echo
        echo "  Manage the fish-config Kitty scrollback watcher (C5 logging)."
        echo
        echo "$c_head""Commands:$c_reset"
        echo "  $c_flag""install$c_reset    Copy the watcher and wire it into kitty.conf"
        echo "  $c_flag""uninstall$c_reset  Remove the managed block and the watcher file"
        echo "  $c_flag""status$c_reset     Show wiring, watcher version, and C5 state"
        echo "  $c_flag""dismiss$c_reset    Stop the per-session reminder"
        echo "  $c_flag""-h$c_reset, $c_flag""--help$c_reset  Show this help message"
        return 0
    end

    # dismiss only sets a universal variable — it must work even where kitty is
    # absent (e.g. shared dotfiles on a non-kitty machine), so handle it before
    # the kitty guard.
    if test "$cmd" = dismiss
        set -U __fish_config_kitty_watcher_dismissed 1
        echo "$c_ok""→ Reminder dismissed.$c_reset Run $c_cmd""kitty-logging install$c_reset anytime to enable."
        return 0
    end

    if not type -q kitty
        echo "$c_err""kitty-logging: kitty is not installed$c_reset" >&2
        return 1
    end

    set -l kitty_dir (__kitty_logging_dir)
    set -l conf "$kitty_dir/kitty.conf"
    set -l src "$__fish_config_dir/scripts/kitty-fish-config-watcher.py"
    set -l dst "$kitty_dir/fish-config-watcher.py"
    set -l blk_begin "# >>> fish-config logging (managed — do not edit) >>>"
    set -l blk_end "# <<< fish-config logging (managed) <<<"

    switch $cmd
        case status
            echo "$c_head""Kitty logging status$c_reset"
            echo "  Config dir:    $kitty_dir"
            if test -f $conf; and command grep -qF -- "$blk_begin" $conf
                echo "  Managed block: $c_ok""present$c_reset"
            else if __kitty_logging_has_watcher
                echo "  Managed block: $c_warn""absent$c_reset (a non-managed watcher line is present)"
            else
                echo "  Managed block: $c_warn""absent$c_reset"
            end
            if test -f $dst
                echo "  Watcher file:  $c_ok""installed$c_reset (version "(__kitty_logging_version $dst)")"
            else
                echo "  Watcher file:  $c_warn""not installed$c_reset"
            end
            if __fish_config_op_enabled (status current-function)
                echo "  C5 logging:    $c_ok""enabled$c_reset"
            else
                echo "  C5 logging:    $c_warn""disabled$c_reset (capture is currently inert)"
            end
            return 0

        case install
            if not test -f $src
                echo "$c_err""kitty-logging: watcher source not found at $src$c_reset" >&2
                return 1
            end
            if not command mkdir -p $kitty_dir
                echo "$c_err""kitty-logging: cannot create $kitty_dir$c_reset" >&2
                return 1
            end

            # Symlink the watcher into the kitty config dir so it always tracks
            # the canonical source (no copy, no staleness). ln -sfn replaces a
            # stale link or a legacy copied file. A failed link must abort:
            # otherwise we would wire a managed block pointing at a missing
            # watcher and report success.
            if not command ln -sfn $src $dst
                echo "$c_err""kitty-logging: failed to symlink watcher to $dst$c_reset" >&2
                return 1
            end

            # Already wired: idempotent no-op.
            if test -f $conf; and command grep -qF -- "$blk_begin" $conf
                echo "$c_ok""→ Already installed.$c_reset"
                return 0
            end

            # Comment any active (non-managed) watcher line to avoid double-capture.
            if __kitty_logging_has_watcher
                command sed -i 's/^\([[:space:]]*\)\(watcher[[:space:]].*\)$/\1# disabled by fish-config: \2/' $conf
                echo "$c_warn""→ Commented an existing watcher line in kitty.conf to avoid double-capture.$c_reset"
            end

            # Append the managed block.
            if not printf '%s\n' "" "$blk_begin" "watcher fish-config-watcher.py" "$blk_end" >>$conf
                echo "$c_err""kitty-logging: failed to write $conf$c_reset" >&2
                return 1
            end
            echo "$c_ok""→ Installed.$c_reset Watcher wired into $conf"
            echo "  $c_dim""Restart Kitty (new windows) for it to take effect.$c_reset"
            if not __fish_config_op_enabled (status current-function)
                echo "  $c_warn""Note: C5 logging is disabled, so capture is currently inert.$c_reset"
            end
            return 0

        case uninstall
            # Require both markers before the range-delete: a sed range with a
            # missing end marker would delete from the begin marker to EOF.
            if test -f $conf; and command grep -qF -- "$blk_begin" $conf; and command grep -qF -- "$blk_end" $conf
                command sed -i '/^# >>> fish-config logging/,/^# <<< fish-config logging/d' $conf
                echo "$c_ok""→ Removed managed block from $conf$c_reset"
            else if test -f $conf; and command grep -qF -- "$blk_begin" $conf
                echo "$c_warn""→ Managed block in $conf looks malformed (missing end marker); left it untouched.$c_reset" >&2
            else
                echo "$c_dim""→ No managed block found in $conf$c_reset"
            end
            # -L catches the symlink (even if dangling); -f catches a legacy copy.
            if test -L $dst; or test -f $dst
                command rm -f $dst
                echo "$c_ok""→ Removed $dst$c_reset"
            end
            return 0

        case '*'
            echo "$c_err""kitty-logging: unknown command '$cmd'$c_reset" >&2
            echo "Run $c_cmd""kitty-logging --help$c_reset for usage." >&2
            return 1
    end
end
