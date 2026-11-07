# Crazy Mad Scientist Zombie & Knox Virus Cure

Project Zomboid **Build 42** mod. Spawns a rare "Mad Scientist" zombie carrying
the cure to the Knox Virus. The scientist is a configurable sprinter, tougher
and hits harder than normal, and wears the Mad Scientist outfit. Using the cure
clears the Knox infection but inflicts a random negative trait.

- **Mod ID:** `MadScientistKnoxCure`
- **Repo:** `ewpeters/mad-scientist-mod-pz`
- Fully configurable via **Sandbox Options** (spawn chance, sprinter %, health/damage
  multipliers, guaranteed cure drop, per-trait cure-side-effect weights).

## Testing: clone into the Workshop folder

Test deploys are done by cloning the repo **directly into the game's Workshop
folder, with the mod ID as the folder name**. The repo root already is the
Workshop item layout (`workshop.txt` + `Contents/mods/MadScientistKnoxCure/42/...`),
so the clone folder becomes a live, working Workshop item.

Clone it into your `Zomboid/Workshop/` directory as `MadScientistKnoxCure`:

```bash
# macOS
cd ~/Zomboid/Workshop
git clone <repo-url> MadScientistKnoxCure

# Windows
cd %USERPROFILE%\Zomboid\Workshop
git clone <repo-url> MadScientistKnoxCure
```

The folder name **must** be `MadScientistKnoxCure` — the Host/listen-server mod
loader resolves the mod at
`Zomboid/Workshop/MadScientistKnoxCure/Contents/mods/MadScientistKnoxCure/42/...`.
Do **not** clone into `Zomboid/mods/` — the Host loader won't find it there.

To update an existing clone, just pull:

```bash
cd ~/Zomboid/Workshop/MadScientistKnoxCure
git pull
```

**Restart Project Zomboid after cloning or pulling** — it caches the mod scan at
launch. Then enable the mod in-game and start/load a Build 42 world.

## Notes

- The "MadScientist" outfit the zombie wears is provided by another mod in the
  test setup, not vanilla B42. On a clean install without that outfit, the
  zombie spawns without the outfit (the call is guarded and will not error).
