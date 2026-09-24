# AFV2 — AutoFarmingV2

Load it with one line. `init.lua` fetches the sources below, joins them into a
single chunk and runs it.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/zeroschth38-jpg/svgrbxtest/refs/heads/main/AFV2/init.lua"))()
```

`../AutoFarmingV2.lua` is the same chunk, prebuilt, kept as a fallback entry
point. It is generated; refresh it with `node AFV2/verify.js` and copy
`dist/AutoFarmingV2.lua` over it.

## Architecture

Seven modules, each named after what it is responsible for. A module may use
anything above it in this list and nothing below it.

| module | file | lines | responsibility |
|---|---|---:|---|
| `AFConfig` | `config.lua` | 145 | place presets, config shapes, value helpers |
| `AFCombatUtils` | `combatutils.lua` | 714 | geometry, world queries, blade maths, movement primitives |
| `AFCombat` | `combat.lua` | 2946 | targeting, approach, retreat, attack execution |
| `AFFeature` | `feature.lua` | 1008 | route, patrol, zone return, blocking, character upkeep |
| `AFProfile` | `profile.lua` | 747 | serialise, file IO, import and export |
| `AFDebug` | `debug.lua` | 528 | in-world waypoint and zone visualiser |
| `AFUI` | `ui.lua` | 489 | tabs, controls, status readouts |

The direction is enforced, not just described:

```
node AFV2/verify.js --graph     print the graph
node AFV2/verify.js             fails the build on an upward call
```

## Composition root

These four are not modules. They hold no domain logic; they wire the modules
together and are allowed to reach anywhere.

| file | lines | contents |
|---|---:|---|
| `header.lua` | 59 | services, module tables, Utils window, shared character handles |
| `state.lua` | 625 | `CONFIG`, `PLACE_CONFIG`, and the initial value of every state field |
| `build.lua` | 1230 | window, controls, visualiser, profile restore |
| `wire.lua` | 42 | subscriptions to the world: the mob folder and its replacement |
| `main.lua` | 454 | the two frame loops, nothing else |

## State

Every module keeps its mutable state on its own `S` table:

```lua
AFCombat.S.ClosestTarget
AFFeature.S.BlockCache
AFProfile.S.ActiveProfileName
```

Ownership is then readable from the name, and resetting an area is one
`table.clear`. It also costs no local registers, which matters: Luau allows
200 per chunk and this file once hit exactly that and stopped compiling
entirely. It now sits at 36.

A handful of things stay plain shared locals because nothing owns them — they
describe the world or the settings rather than one module's bookkeeping:
`CONFIG`, `PLACE_CONFIG`, `PlaceConfig`, `Character`, `Humanoid`, `RootPart`,
`FaceOrientation`, `InputBindableFunction`, `Feature`.

## Load order

`ORDER` in `init.lua` is the only place load order is recorded. Filenames carry
no numbers on purpose: two sources of truth for order is one too many.

## Why concatenation and not modules

The seven are namespaces, not modules. They all close over the same top-level
declarations in `state.lua`, which Lua binds as upvalues where a function is
defined, so those declarations have to sit lexically above every module in one
chunk.

Calling `loadstring` per file would give each file its own copy of that state.
Nothing would error; the script would just quietly fail to work. So `init.lua`
concatenates the source text first and calls `loadstring` exactly once.

Each source holds its slice plus one terminating newline. The loader strips
exactly one newline per part and joins with `\n`, which reproduces the
reviewed file byte for byte.

## Cost and failure mode

The loader makes 12 requests, fired in parallel. Sequentially they cost about
half a second each; in parallel the set costs roughly the slowest single
request. `header.lua` then fetches `Utils.lua`, so a run makes 14 requests in
total including `init.lua` itself.

A missing slice would not always be a syntax error — it could silently drop a
whole module. So the loader retries each file three times, rejects responses
under 64 bytes (a cache or error page can arrive with a 200), and refuses to
load anything unless every source arrived.

## Rules

1. **Declarations belong in `state.lua`.** A new top-level variable added
   anywhere else will not be visible to modules defined above it.
2. **Module files define functions only.** Nothing in the seven may execute at
   load time; put the call in `build.lua`.
3. **`build.lua`, `wire.lua` and `main.lua` are order-sensitive.** UI
   construction, profile restore and the event connections depend on running
   in the sequence they appear in.
4. **Adding or renaming a source means editing `ORDER` in `init.lua`.**
5. **Never call upward.** If a module needs to tell a higher one something,
   raise a hook it assigns, the way `AFCombat.OnMobSetChanged` works.

## Checking changes offline

```
node AFV2/verify.js
node AFV2/verify.js --graph
node AFV2/verify.js --compare ../AutoFarmingV2.lua
```

It assembles the chunk the same way `init.lua` does, so the result can be
parsed or diffed, and its output goes to `dist/`, which is gitignored.

## Known constraints

- `init.lua` hardcodes the branch it loads from. Merging elsewhere means
  updating `BRANCH` there.
- `header.lua` fetches `Utils.lua` from a branch tip, so the UI library can
  change under the script between runs.
