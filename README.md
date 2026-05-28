# VTT Open

A **Virtual Tabletop** application built in **Godot 4.6** for playing tabletop RPGs (D&D, Pathfinder, etc.) in a 3D environment.

## Features

- **3D grid-based battle map** with configurable grid size and shading
- **Fog of war** with dynamic vision blocking by walls, doors, and windows
- **Token system** — player tokens, NPCs, monsters, and props/decorations with HP bars, initiative tracking, and distance measurement
- **Physics-based dice rolling** — 3D dice (d4, d6, d8, d10, d12, d20) using Jolt physics with face-detection result reading
- **Terrain building** — walls and floor tiles (stone, grass, water) with snap-to-grid placement
- **Modular terraform system** — stackable 3D blocks for elevation
- **Asset library** — import your own GLB/GLTF 3D models with automatic thumbnail generation
- **Token editor** — edit HP, AC, move speed, vision radius, blinded state
- **Right-click context menus** — cycle wall types, edit/delete tokens

## Getting Started

1. Open the project in **Godot 4.6+**
2. Set the renderer to **GL Compatibility** (already configured)
3. Run the main scene (`world.tscn`)
4. If prompted, install the **Jolt Physics** plugin (required for dice physics)

## Controls

| Input | Action |
|---|---|
| **Left-click** | Place selected piece / token |
| **Right-click** | Context menu |
| **Left-drag** | Move token or piece |
| **Scroll wheel** | Zoom camera |
| **Middle mouse drag** | Orbit camera |
| **WASD** | Pan camera |

## Controls reference panel

Use the **Library Panel** (top toolbar) to:
- Select wall, floor, or terraform block types for placement
- Switch between **Move**, **Demolish**, and **Place** tools
- Browse and import custom 3D assets
- Open the dice roller panel
- Toggle GM mode (reveal fog of war)

## Architecture

```
world.tscn (coordinator)
  ├── world.gd              # Thin coordinator — owns shared state dictionaries
  ├── camera.gd             # Orbital camera controller
  ├── grid.gd + shader      # Grid rendering
  ├── fog_of_war.gd + shader # Fog of war with vision blocking
  ├── Scripts/
  │   ├── input_handler.gd           # Raw input routing
  │   ├── drag_controller.gd         # Drag state machine
  │   ├── selection_manager.gd       # Tool/mode state
  │   ├── terrain_placer.gd          # Wall/floor placement
  │   ├── token_manager.gd           # Token management
  │   ├── modular_terraform_manager.gd # 3D block stacking
  │   ├── block_tile.gd              # Stackable block class
  │   └── aabb_util.gd               # Shared AABB helper
  ├── ui/                             # UI panels
  │   ├── library_panel.gd/.tscn     # Main toolbar
  │   ├── dice_panel.gd/.tscn        # Dice roller
  │   ├── token_editor.gd/.tscn      # Token stats editor
  │   ├── context_menu.gd/.tscn      # Right-click menu
  │   └── thumbnail_studio.gd/.tscn  # Asset thumbnail generator
  ├── terrain/                        # Wall/floor prefabs
  ├── terraform/                      # Stackable block prefabs
  └── tokens/                         # Token prefab
```

The project follows a **coordinator pattern**: `world.gd` owns shared state (two dictionaries: `placed_pieces` and `placed_tokens`) and utility methods (`get_world_hit`, `world_to_cell`). All domain logic lives in dedicated handler scripts.

## Importing Custom Assets

Place `.glb` or `.gltf` files in the `assets/` subfolders (walls, props, tokens/monsters). The `DefaultLibrary` autoload scans these folders on startup. You can also use the **Import** button in the library panel.

## Running Tests

```bash
godot --headless --script test/run_tests.gd
```

## Project Configuration

- **Engine**: Godot 4.6
- **Renderer**: GL Compatibility
- **Physics**: Jolt Physics 3D
- **Language**: GDScript

## License

Copyright (c) 2026 Magd Essam

All Rights Reserved.
