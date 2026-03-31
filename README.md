# Ell's Tales: Chairbound - LiveSplit Auto Splitter

Auto splitter for [Ell's Tales: Chairbound](https://store.steampowered.com/app/3281410/) (Steam App ID: 3281410).

## Features

- **Auto Start/Reset** - Timer starts when entering the game, resets on new game
- **Clear Split** - Splits when both levers are pulled and bomb timer stops (exact in-game clear timing)
- **ESC Pause** - Game Time pauses when ESC menu is open
- **Load Removal** - Game Time pauses during map transitions
- **Bomb Timer Display** - Shows bomb remaining time and elapsed time via Text components (reflects item effects like time freeze)

## Setup

### Auto Splitter
1. Open LiveSplit
2. Right click -> **Edit Layout** -> **+** -> **Control** -> **Scriptable Auto Splitter**
3. Browse to `EllsTalesChairbound.asl`

### Bomb Timer Display (Optional)
1. **Edit Layout** -> **+** -> **Information** -> **Text** (add twice)
2. First Text component = Bomb Elapsed Time
3. Second Text component = Bomb Remaining Time
4. The script will automatically populate them

### Timer
- Set Timer component to **Game Time** for accurate timing (excludes ESC pause and loading)

### Splits
- Add 1 segment (e.g., "Clear") in Splits Editor
- Timer stops automatically when clear is detected

## Layout Reference

The included `.lsl` file is a sample LiveSplit layout with the recommended configuration.

## Technical Details

- Engine: Unreal Engine 4.27
- Dynamically scans actor list for `BP_FinalMechanism_C` and `BP_Hero_C`
- Resolves property offsets at runtime via UE4 FField chain (session-stable)
- Reads `StateIsOn` (lever state), `CheckTimer` (clear detection), `RemainedSeconds` (bomb timer)
- FName resolution via FNamePool for class identification

## Files

| File | Description |
|------|-------------|
| `EllsTalesChairbound.asl` | Auto splitter script |
| `Ells Tales Chairbound.lsl` | Sample LiveSplit layout |
| `Ells Tales Chairbound.lss` | Sample splits file |
