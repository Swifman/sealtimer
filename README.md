# sealtimer

An Ashita v4 addon for FFXI that shows when Beastmen's and Kindred's Seals can drop again.

Built for the Phoenix private server, which runs LandSandBoat.

## How seal drops work (LandSandBoat)

- After a seal drops, nobody in the killer's party who is in the zone can get another seal for 5 minutes.
- While nobody is on cooldown, each eligible kill has a 20% chance to drop a seal.
- Mobs level 50 and up can drop a Kindred's Seal instead, on the same timer.
- Seals never drop from NMs, mobs that con Too Weak, BCNMs or Dynamis.
- On Phoenix the cooldown carries through zoning. Some other servers reset it on zone; use `/st zone on` there.

## What it does

The addon shows a small window with **READY**, or a countdown and progress bar while the cooldown runs. It also lists the last seal and how long ago it dropped, plus a count for the session. A chat line tells you when seals can drop again.

It reads the treasure pool packet (0x00D2) the server already sends when loot drops. Seals that were already in the pool when you zoned in, and seals from chests or boxes, are ignored. **It sends nothing to the server.**

## Screenshots

![sealtimer showing READY](media/ready.png)

<!-- cooldown screenshot: media/cooldown.png -->

## Download

Get **sealtimer.zip** from the [Releases page](https://github.com/Swifman/sealtimer/releases/latest).

## Install

1. Unzip it so the folder sits at `Ashita/addons/sealtimer/sealtimer.lua`.
2. In game: `/addon load sealtimer`

## Source

The whole addon is one plain Lua file, `sealtimer.lua`. There are no DLLs, binaries or other compiled parts, and it uses only Ashita v4's built-in libraries (`imgui`, `settings`, `chat`).

## Commands (`/sealtimer` or `/st`)

| Command | What it does |
|---|---|
| `/st` | Show or hide the window |
| `/st reset` | Clear the timer |
| `/st start` | Start the timer by hand |
| `/st zone on\|off` | Reset the timer when you zone (default off) |
| `/st duration 300` | Cooldown length in seconds (default 300) |
| `/st hide on\|off` | Hide the window while seals are ready |
| `/st alert on\|off` | Chat message when the timer is up (default on) |

Settings and the window position are saved per character. The timer is saved as a clock time, so it keeps counting through zoning, logout and addon reloads.

## Note

Check your server's rules on addons before using this. Phoenix asks that new addons be approved by staff.
