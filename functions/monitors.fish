# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later

function monitors
    # 0. Capture the ID of the pane we are starting in (Top-Left)
    set local_id $KITTY_WINDOW_ID
    
    # Define remote commands
    set racknerd_cmd "ssh -t racknerd btop"
    set server_cmd "ssh -t rootiest-server btop"
    set mini_cmd "ssh -t racknerd-mini btop"

    # 1. Split vertically from Top-Left to create Top-Right (RackNerd)
    set rack_id (kitty @ launch --location=vsplit --cwd=current sh -c "$racknerd_cmd")

    # 2. Return focus to Top-Left and split horizontally to create Bottom-Left (Server)
    kitty @ focus-window --match "id:$local_id"
    set server_id (kitty @ launch --location=hsplit --cwd=current sh -c "$server_cmd")

    # 3. Focus Top-Right (RackNerd) and split horizontally to create Bottom-Right (Mini)
    kitty @ focus-window --match "id:$rack_id"
    set mini_id (kitty @ launch --location=hsplit --cwd=current sh -c "$mini_cmd")

    # 4. Final focus back to the Top-Left to launch local btop
    kitty @ focus-window --match "id:$local_id"
    
    # Run local btop
    btop
end
