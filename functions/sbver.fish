# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

###############################################################################
# Purpose: Verifies Secure Boot status of EFI binaries using 'sbctl'.
# 
# Behavior: 
#   - Filters out 'invalid PE header' noise from sbctl output.
#   - Parsers output to count successfully signed vs. unsigned images.
#   - Color-codes output: Green for verified (✓), Red for failed (✗).
#   - Provides a final summary of the system's signature status.
#
# Arguments:
#   --brief : Suppresses individual file status and only shows the final summary.
###############################################################################

function sbver --description 'Verifies Secure Boot status of EFI binaries using sbctl'
  if not type -q sbctl
    echo "Error: 'sbctl' is not installed."
    return 1
  end

  # ANSI color codes (Fish uses set_color for easier management)
  set RED (set_color red)
  set GREEN (set_color green)
  set NC (set_color normal)

  # Flags
  set brief_mode false
  if test "$argv[1]" = "--brief"
      set brief_mode true
  end

  # Counters
  set pass_count 0
  set fail_count 0

  # Run and process sbctl output
  # Fish doesn't use 'done < <()'; we pipe directly into the while loop
  sudo sbctl verify 2>&1 | grep -v -i 'invalid pe header' | while read -l line
      if string match -q "*✓*" -- "$line"
          set pass_count (math $pass_count + 1)
          if not $brief_mode
              echo -e "$GREEN$line$NC"
          end
      else if string match -q "*✗*" -- "$line"
          set fail_count (math $fail_count + 1)
          if not $brief_mode
              echo -e "$RED$line$NC"
          end
      else
          if not $brief_mode
              echo "$line"
          end
      end
  end

  # Summary
  echo
  if test $fail_count -eq 0
      echo -e "$GREEN✅ All images are signed ($pass_count verified)$NC"
  else
      echo -e "$RED❌ Some images are not signed ($fail_count failed, $pass_count passed)$NC"
  end
end
