We need to decide how we want our libs to be packaged/installed.

1. Just run `gem install iron_mq` (and similar for other langs) in install/setup script (and uninstall in teardown, though it'll leave deps installed). Easiest way, but virtually no controll on what's going on.
2. Package libs with cartridge (in data dir or similar) modify GEM_PATH (and similar for other langs) in start hook. Will force us to update cartridge on every affected lib update. Not good.
3. Make gems (and pips etc) packaged as RPM, add them as deps to cartridge as all other cartridges do. Easiest for us way, granular updates.

Provision. On setup time we can ask user for iron.io project_id/token and if he is new - ask for email (can't find it in env) and create new account. Problem is - we'll need to depend on ruby cartridge to do that (or spend some time doing provisioning using shell/curl).
