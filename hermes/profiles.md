# Hermes profiles

Hermes agents may run different profiles that control which skills and tools are active.

## Current profiles

| Profile | Description | Status |
|---|---|---|
| default | General-purpose assistant with Telegram and LLM | active |

## Adding a profile

1. Create a profile configuration file in `/opt/data/profiles/` (inside the container or volume).
2. Reference the profile in `config.yaml`.
3. Restart the container.
4. Update this file with the new profile entry.

## Notes

Profile files may contain tool configurations that reference credential names.
They must not contain raw credential values — those come from the `.env` file.
