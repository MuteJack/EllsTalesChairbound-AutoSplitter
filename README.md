# Ell's Tales: Chairbound - LiveSplit Auto Splitter

Auto splitter for [Ell&#39;s Tales: Chairbound](https://store.steampowered.com/app/3281410/) (Steam App ID: 3281410).

## Features

- **Auto Start/Reset** - Timer starts when entering the game, resets on new game
- **Clear Split** - Splits when both levers are pulled and bomb timer stops (exact in-game clear timing)
- **ESC Pause** - Game Time pauses when ESC menu is open
- **Load Removal** - Game Time pauses during map transitions
- **Bomb Timer Display** - Shows bomb remaining/elapsed time via Custom Variables (reflects item effects like time freeze)
- **Bomb as Game Time** - Optional mode to use bomb elapsed time as Game Time (matches leaderboard timing)
- **Debug Log** - Optional logging for troubleshooting

## Setup

### Auto Splitter

1. Open LiveSplit
2. Right click -> **Edit Layout** -> **+** -> **Control** -> **Scriptable Auto Splitter**
3. Browse to `EllsTalesChairbound.asl`

### Bomb Timer Display (Optional)

1. **Edit Layout** -> **+** -> **Information** -> **Text**
2. In Text component settings, set right side to **Custom Variable**
3. Set variable name to `BombRemain` (bomb remaining time) or `BombElapsed` (bomb elapsed time)
4. Repeat for the other variable if desired

### Timer

- Set Timer component to **Game Time** for accurate timing (excludes ESC pause and loading)

### Splits

- Add 1 segment (e.g., "Clear") in Splits Editor
- Timer stops automatically when clear is detected

## Advanced Options

| Type     | Option                   | Default | Description                                              |
| -------- | ------------------------ | ------- | -------------------------------------------------------- |
| Default  | Split on clear           | On      | Split when both levers are pulled                        |
| Debug  | Pause timer on ESC menu  | Off     | Pause Game Time when ESC menu is open                    |
| Advanced | Game Time = bomb elapsed | Off     | Use bomb elapsed time as Game Time (matches leaderboard) |
| Advanced | Show bomb remaining time | On      | Update Custom Variable `BombRemain`                    |
| Advanced | Show bomb elapsed time   | On      | Update Custom Variable `BombElapsed`                   |
| Debug    | Enable debug log         | Off     | Write debug log to `{LiveSplit Dir}/logs/`             |

## Layout Reference

The included `.lsl` file is a sample LiveSplit layout with the recommended configuration.

## Technical Details

- Engine: Unreal Engine 4.27
- Dynamically scans actor list for `BP_FinalMechanism_C` and `BP_Hero_C`
- Resolves property offsets at runtime via UE4 FField chain (session-stable)
- Reads `StateIsOn` (lever state), `CheckTimer` (clear detection), `RemainedSeconds` (bomb timer)
- FName resolution via FNamePool for class identification
- Because of the "Bomb Remaining" is integer type, and "Bomb Ellapsed"

## Files

| File                          | Description             |
| ----------------------------- | ----------------------- |
| `EllsTalesChairbound.asl`   | Auto splitter script    |
| `Ells Tales Chairbound.lsl` | Sample LiveSplit layout |
| `Ells Tales Chairbound.lss` | Sample splits file      |
