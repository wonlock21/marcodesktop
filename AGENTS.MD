# AGENTS.md

## Project role
This repository is the Flutter operator GUI for the MarCO robot.

## Related ROS repository
The sibling `marco_ws` repository is the authoritative ROS 2 Humble implementation.

`marco_ws` is READ-ONLY during GUI integration work.

Never modify ROS files unless explicitly instructed by the user.

## Source of truth
When GUI assumptions conflict with ROS:

1. marco_msgs .msg/.srv/.action
2. Current ROS node implementation
3. Current route/mission/localization implementation
4. yarisma_plani.md
5. Existing Flutter code

## Architecture rules
- Do not implement navigation logic in Flutter.
- Do not hard-code station mappings.
- Do not hard-code q5/q6 IDs or coordinates.
- Production mission submit and mission start are separate user actions.
- rosbridge uses port 9090.
- web_video_server uses port 8080.
- Preserve existing working GUI behavior where possible.
- Avoid large refactors.
- Android and Windows share the same ROS/model/service layer.

## Repository boundaries
Implementation target:
`marcodesktop`

Read-only reference:
`marco_ws`

## Verification
After changes run where supported:
- dart format
- flutter analyze
- flutter test
