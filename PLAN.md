# VTT Open — TaleSpire-Inspired Enhancement Plan

> **Philosophy:** This VTT aims to feel like TaleSpire — a beautiful 3D tabletop with an infinite-feeling base board where you build rooms with floor tiles, walls, and props on a grid canvas.

---

## ✅ Done: Infinite Base Floor (Like TaleSpire's Board)

The base floor is now **massive** (2000×2000 in editor) — like TaleSpire's endless table surface. You never see its edges.

**Changes made:**
- `world.tscn`: Floor `PlaneMesh` + `CollisionShape3D` sized in editor (not code)
- `world.gd` lines 28-29: Removed `@onready var floor_mesh` and `floor_col` (unused)
- `world.gd` line 491-497: `sync_floor()` simplified — no longer recreates the plane geometry. Only syncs fog + grid.

The floor gets a dark parchment/asphalt texture. Grid overlay sits on top of it (finite grid area controlled by slider). Floor tiles placed on the parchment define rooms.

---

## Phase 1: Floor Tiles + Tile Fusion

### Goal
Place stone/grass/water/wood floor tiles on the parchment base to define rooms. Adjacent same-type tiles fuse together seamlessly (no visible seam).

### Changes

| File | Action | What |
|------|--------|------|
| `terrain/pieces/floor_tile.gd` | **Enhance** | Add `tile_type`, detection of neighbors for fusion |
| `terrain/pieces/floor_stone.tscn` | Edit | Optionally give slight thickness (volumetric look) |
| `terrain/pieces/*.tscn` | Edit | Set tile_type accordingly |
| `Scripts/terrain_placer.gd` | Edit | After placing a tile, trigger fusion check on neighbors |
| `world.gd` | Edit | Store tile grid in `tile_grid: Dictionary` for neighbor lookups |
| `tile_fusion.gd` (new) | **New** | Logic: when same-type tiles are adjacent, merge/remove the shared edge |

### Tile Fusion Approach (Shader-Based)
- When a tile is placed, check all 4 neighbors
- If neighbor exists + same `tile_type` → hide the edge between them
- **Method:** Use a shader param per tile edge (N/S/E/W) that hides the border mesh
- Or simpler: use a single flat mesh per tile type with a texture that has no visible edges, and just let them overlap naturally

---

## Phase 2: Slab System (Copy/Paste/Share Selections)

### Goal
TaleSpire-style slab system: select any 3D region of tiles/walls/props, copy as encoded string to clipboard, paste elsewhere. Share slabs with others.

### New Files

| File | Purpose |
|------|---------|
| `Scripts/slab_codec.gd` | Encode slab data → base64 string. Decode ← base64 → slab data |
| `Scripts/slab_manager.gd` | Handles slab selection, copy, paste preview, place |

### Modified Files

| File | Changes |
|------|---------|
| `Scripts/selection_manager.gd` | Add multi-select mode (rubber-band drag) |
| `Scripts/input_handler.gd` | Ctrl+C (copy), Ctrl+V (paste), R (rotate slab) |
| `world.gd` | Add SlabManager ref |
| `world.tscn` | Add SlabManager node |

### Slab Data Format
```json
{
  "version": 1,
  "tiles": [
	{"type": "floor_stone", "cell_x": 3, "cell_y": 5, "rotation": 0}
  ],
  "walls": [
	{"cell_x": 3, "cell_y": 5, "dir": "N", "wall_type": 0}
  ],
  "props": [
	{"model_path": "...", "pos": [x,y,z], "rot": 0, "scale": 1.0}
  ]
}
```
Encode → JSON → base64 → clipboard.

---

## Phase 3: Multilevel Building

### Goal
Build multi-level structures with a layer slider to see inside (like TaleSpire's green cut-plane slider).

### New Files

| File | Purpose |
|------|---------|
| `Scripts/floor_manager.gd` | Floor levels (ground=0, first=1, etc.), N/P key switching |
| `Scripts/layer_slider.gd` | Build-mode clip plane slider (hides everything above Y) |
| `Scripts/water_slider.gd` | Water level slider + animated water shader |
| `water.gdshader` | Animated semi-transparent water surface |

### Modified Files

| File | Changes |
|------|---------|
| `input_handler.gd` | B key toggle build mode, N/P floor switching |
| `library_panel.gd` | Build mode toggle button, floor indicator, slider UI |
| `world.gd` | Add FloorManager, LayerSlider, WaterSlider refs |

---

## Phase 4: Token Movement Controls

### Goal
Click-to-move pathfinding, movement grid overlay, initiative tracker.

### New Files

| File | Purpose |
|------|---------|
| `Scripts/movement_controller.gd` | A* pathfinding, click-to-move, path preview |
| `Scripts/movement_grid.gd` | Reachable-cells overlay (green/yellow/orange) |
| `Scripts/initiative_tracker.gd` | Turn order management |
| `ui/initiative_panel.tscn` + `.gd` | Initiative tracker UI |

### Modified Files

| File | Changes |
|------|---------|
| `token.gd` | Add `movement_budget`, `initiative_score` |
| `token_editor.gd` | Add movement speed, initiative fields |
| `input_handler.gd` | M key toggle movement grid, click-to-move in MOVE tool |
| `library_panel.gd` | Initiative toggle, End Turn button |
| `drag_controller.gd` | Show reachable radius during drag |

---

## Phase 5: Props & Items

### Goal
Free-form prop placement (non-grid-snapped). Items that tokens can pick up and carry.

### New Files

| File | Purpose |
|------|---------|
| `Scripts/item.gd` | Pickable item scene (key, potion, treasure) |
| `ui/inventory_panel.tscn` + `.gd` | Token inventory UI |

### Modified Files

| File | Changes |
|------|---------|
| `prop_placer.gd` | Free-form placement mode (no grid snap), 15° rotation snap |
| `token.gd` | Add `inventory: Array`, `pick_up(item)`, `drop_item()` |
| `context_menu.gd` | "Pick Up" option for items near token |
| `token_editor.gd` | Show inventory list |

---

## Implementation Order

```
Step 0 — Phase 0:  ✅ DONE - Infinite parchment floor
Step 1 — Phase 1:  Floor tile placement + fusion
Step 2 — Phase 2:  Slab copy/paste system
Step 3 — Phase 3a: Floor manager + floor switching
Step 4 — Phase 3b: Layer slider (build mode clip plane)
Step 5 — Phase 3c: Water level slider + shader
Step 6 — Phase 4a: Click-to-move pathfinding
Step 7 — Phase 4b: Movement grid overlay
Step 8 — Phase 4c: Initiative tracker
Step 9 — Phase 5a: Free-form prop placement
Step 10 — Phase 5b: Item system + inventory
```
