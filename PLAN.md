# CAD — native Mac solid modeller

A Fusion-style parametric modeller, cut down to solids for 3D printing. Native AppKit, macOS 26 Tahoe+, Apple Silicon only.

**Working name:** CAD  
**Bundle ID:** `dev.brackenbury.CAD`  
**Document type:** `dev.brackenbury.cad` / `.cad`  
**Units:** millimetres, always

The app, target, and menus are called CAD until a real name exists. Do not invent another placeholder.

---

## What v1 is

A document-based Mac app where you:

1. Create a part from primitives and/or a sketch-extrude.
2. Fillet, chamfer, union, and cut.
3. Edit earlier features; the body rebuilds.
4. Save a `.cad` file and export STL + 3MF.

No slicer, printer bed, CAM, assemblies, drawings, or simulation.

### v1 tools

| Tool | Notes |
|---|---|
| Select | Bodies, faces, edges. Shift-add. |
| Box / Cylinder / Sphere | Parametric primitives. |
| Sketch | Line, rectangle, circle on XY / XZ / YZ (and on a face if picking is ready). |
| Extrude | New body, join, or cut. |
| Move / Rotate / Scale | Stored as a transform feature. |
| Fillet / Chamfer | Selected edges, radius/distance in the inspector. |
| Combine | Union / cut / intersect of two bodies. |

### Explicitly not v1

Constrained sketches (full GCS), revolve, loft, sweep, shell, hole, patterns, threads, construction geometry beyond origin planes, STEP, assemblies, mesh repair, slicer handoff.

Those wait. The document model must not block them.

---

## Product decisions

### Parametric, even though the toolset is small

The source of truth is a **feature timeline**, not a mesh. Editing a box width or extrude depth rebuilds everything after it. The left sidebar *is* the timeline (plus bodies). Fusion’s bottom timeline is a HIG miss — critical controls do not live on the window’s bottom edge.

### Kernel: OCCT via OCCTSwift

Use [OCCTSwift](https://github.com/SecondMouseAU/OCCTSwift) (OCCT 8.0.1, Swift API, prebuilt `OCCT.xcframework`, arm64). Do **not** wrap Open CASCADE ourselves and do **not** use Manifold as the modeller.

Why OCCT, not a mesh boolean library: fillets, chamfers, and parametric rebuilds are B-rep problems. Manifold is the right export-time mesh library, not the kernel.

Related packages, used narrowly:

- **OCCTSwift** — primitives, extrude, fillet, chamfer, booleans, tessellation, STL write.
- **OCCTSwiftTools** — `Shape` → `ViewportBody` plus face/edge pick IDs.
- **OCCTSwiftViewport** — Metal camera, grid, shaded/wire display.

Do **not** adopt OCCTSwiftAIS or OCAF as the document store. The app owns the part file and the UI. The kernel is a geometry calculator.

License: OCCT / OCCTSwift are LGPL-2.1 with the Open CASCADE exception. Keep them as SPM dependencies; do not copy kernel sources into the app target.

Intel Macs are out of scope (OCCTSwift is arm64-only). That matches Apple Silicon + Tahoe.

### Sketches in v1 are dimension-driven, not Fusion-constrained

A rectangle has width/height. A circle has radius. A polyline has point coordinates. Shift-constrains horizontal/vertical while drawing.

There is **no geometric constraint solver** in v1 (SolveSpace is GPL; a real GCS is its own product). Leave a `SketchSolver` seam so one can be dropped in later. Do not fake a solver.

### Inspector is the command UI

Fusion-style modal command dialogs in the viewport are out. Starting Extrude puts the app in a tool state; distance, direction, and join/cut live in the inspector and update a live preview. Enter/Return commits, Escape cancels. Every tool is also a menu command with a shortcut.

### Viewport chrome vs AppKit chrome

The **window** is AppKit: `NSDocument`, `NSSplitViewController`, `NSToolbar`, `NSMenu`, `NSOutlineView`, inspector as a trailing split. No Electron, no GPUI, no Tauri, no SwiftUI app lifecycle.

The **3D view** may host OCCTSwiftViewport’s `MTKView` (via the existing NSView path, or `NSHostingView` *only* for that pane if the package’s public API is SwiftUI-only). Sketch overlays, dimensions, and gizmos can be sibling NSViews or Metal overlays. Do not wrap the sidebar, toolbar, or inspector in SwiftUI unless AppKit has no equivalent (it does).

---

## HIG (Tahoe)

Follow the system. Do not invent a CAD skin.

- **Window:** standard titlebar, traffic lights, unified toolbar. No custom frame.
- **Toolbar:** `NSToolbar` in the titlebar. Group related tools with `NSToolbarItemGroup` / spacers. Leading: sidebar toggle. Trailing: inspector toggle. Every toolbar item has a menu-bar equivalent. Allow customization.
- **Sidebar:** leading `NSSplitViewItem` with `.sidebar` behavior (Liquid Glass comes for free on 26). `NSOutlineView` / `NSCollectionView` in sidebar size. SF Symbols, system accent colour. View → Show/Hide Sidebar.
- **Inspector:** trailing split, not a floating panel, unless the user detaches it later (not v1). View → Show/Hide Inspector. Contents always match the selection or the active tool.
- **Menus:** standard order — App, File, Edit, View, Insert (or Solid / Sketch as app menus), Window, Help. Cmd-based shortcuts. No Ctrl-as-primary. Delete, not Backspace-only. Space can hold-to-orbit (CAD convention) *in addition to* Option-drag.
- **Document:** `NSDocument` with Versions, dirty state, Open Recent, Duplicate, Revert, iCloud-safe file coordination. File → Export… for STL/3MF (`NSSavePanel`, not a custom exporter window unless needed for options).
- **Settings:** Settings window (not “Preferences”). Grid snap, orbit style, tessellation quality. Units are not a setting.
- **Appearance:** follow light/dark automatically. No forced dark CAD theme.
- **Full keyboard access / accessibility:** labels on every control, VoiceOver on inspector fields, reduced-motion on camera animations.
- **Do not:** ribbon, bottom-of-window tool palettes as the only way to invoke a tool, nonstandard cursors except for the current tool, blocking modal sheets for numeric input.

### Viewport navigation

Left-drag is selection, not orbit.

| Input | Action |
|---|---|
| Click | Select |
| Shift-click | Add to selection |
| Scroll / pinch | Zoom to cursor |
| Option-drag or middle-drag | Orbit |
| Shift-Option-drag | Pan |
| Space (hold) | Temporary orbit |
| F | Frame selection / all |
| 1–7 or View menu | Front, back, left, right, top, bottom, iso |
| Escape | Cancel tool / clear selection |

Trackpad and mouse both work. Perspective default; View menu toggles orthographic.

---

## Architecture

```
AppKit chrome (document, menus, split, toolbar, inspector)
        │
        ▼
   PartDocument  ── Codable feature graph (.cad JSON)
        │ rebuild on serial queue
        ▼
   Kernel (OCCTSwift Shape per body)
        │ tessellate + pick IDs
        ▼
   Viewport (Metal) + Inspector bindings
```

### Document model

```swift
struct PartFile: Codable {
  var version: Int            // 1
  var units: Units            // mm
  var features: [Feature]
}

enum Feature: Codable {
  case box(BoxParams)
  case cylinder(CylinderParams)
  case sphere(SphereParams)
  case sketch(Sketch)
  case extrude(ExtrudeParams)      // refs a sketch feature id
  case fillet(FilletParams)        // refs body + edge ids
  case chamfer(ChamferParams)
  case combine(CombineParams)      // union/cut/intersect
  case transform(TransformParams)
}
```

Each feature has a stable UUID. Bodies are derived. Edge/face references for fillet are stored as topology names from the kernel (OCCTSwiftTools identity tables). If a rebuild cannot resolve a name, that feature fails closed: show the error on the timeline row, keep the last good solid on screen, do not corrupt the file.

Undo: `NSUndoManager` records whole-graph replacements (or feature-level inverse). Do not invent a second undo stack.

Rebuild: one dedicated serial queue (OCCT is not freely concurrent). Main thread never waits on a boolean. Live extrude preview may use a cheaper tessellation.

### File format

Versioned JSON, pretty-printed, UTF-8, `.cad`. Easy to diff and debug. Gzip later if it matters. Not a wrapper around BREP — BREP is a cache, never the source of truth.

### Export

- **STL** via OCCTSwift’s writer.
- **3MF** written by us from the tessellation (ZIP + the 3MF mesh XML). Do not take a lib3mf dependency for triangle-only export. Prefer 3MF in the Export menu; STL is the compatibility item.

No import in v1.

### Sketch data

```
Sketch
  plane: origin XY | XZ | YZ | (face ref)
  entities: [line | rect | circle | polyline]
  dimensions: stored on the entity (width, height, radius, …)
```

Finish Sketch is a menu/toolbar command. An unfinished sketch is still a feature (you can reopen it from the timeline).

---

## Window layout

```
┌ traffic ─┬ CAD — Bracket.cad ──────── toolbar (tools | view | inspector) ┐
├ sidebar ─┼──────────────────────────── viewport ──────────────┼─ inspector ───┤
│ Bodies   │  grid, triad, shaded body                          │ Box           │
│  Body 1  │  sketch overlay when in sketch                     │ Width  40 mm  │
│ Timeline │                                                    │ Depth  20 mm  │
│  Box 1   │                                                    │ Height 10 mm  │
│  Sketch  │                                                    │               │
│  Extrude │                                                    │               │
│  Fillet  │                                                    │               │
└──────────┴────────────────────────────────────────────────────┴───────────────┘
```

No permanent bottom timeline. A thin status area (units, snap, selection count) is acceptable, Finder-style, and must stay non-critical.

---

## Project shape

Empty repo today. One Xcode app, Swift 6, AppKit, macOS 26 deployment.

```
CAD.xcodeproj
CAD/
  App/                 @main AppDelegate, MainMenu.xib or programmatic menu
  Document/            CADDocument, PartFile, Feature, Sketch
  Window/              split controller, toolbar factory
  Browser/             bodies + timeline outline
  Inspector/           AppKit form for selection / active tool
  Viewport/            host MTKView, camera, selection hit-test
  Tools/               Select, Sketch, Extrude, Fillet, Combine, Transform
  Kernel/              OCCTSwift rebuild + tessellate + export
  Resources/           Assets, Info.plist, entitlements
CADTests/              feature rebuild, file round-trip, 3MF/STL smoke
```

No extra frameworks, no helper packages, no “core” / “domain” / “presentation” split beyond the folders above.

SPM deps on the app target: `OCCTSwift`, `OCCTSwiftTools`, `OCCTSwiftViewport`.

Sandbox: on, so Open/Save/Export stay `NSOpenPanel` / `NSSavePanel`. Hardened runtime as Xcode defaults.

---

## Commits

Commit as you go. Many small conventional commits, not one dump at the end of a phase.

Use the `git-commit` skill (`/git-commit`) for every commit: it stages, writes the message, and does **not** push unless asked.

- Prefixes: `feat:`, `fix:`, `refactor:`, `test:`, `chore:`, `docs:`
- Split when a change is more than one concern (e.g. document model vs toolbar chrome)
- Message describes the user-facing change, not the diff (`feat: save and reopen .cad files`, not `add Codable conformance to PartFile`)
- Technical detail belongs in the body if it helps
- Init the git repo at the start of step 1 if it is not already a repo

---

## Build order

Each step should leave a runnable app. Do not start step N+1 with a broken N. Commit at each working increment inside a step, not only at the step boundary.

### 1. AppKit document shell

New Xcode project: AppKit app, document-based, Swift, macOS 26. Split view (sidebar | empty content | inspector). Standard menus. Toolbar with sidebar/inspector toggles. New / Open / Save of an empty `.cad` JSON. About + Settings stubs.

### 2. Viewport

Host the Metal view. Grid, origin triad, orbit/pan/zoom as specified. Fit-all. Front/iso. Empty scene must feel like a CAD viewport, not a game scene.

### 3. First solid

`box` feature → kernel → mesh on screen. Inspector edits width/depth/height; body updates. Undo. Save/reopen restores the box. Timeline shows “Box”.

### 4. More primitives and transform

Cylinder, sphere. Move/rotate/scale as a feature. Selection highlight.

### 5. Sketch + extrude

Sketch on origin plane: rectangle and circle first, then line/polyline. Finish Sketch. Extrude with live preview and join/cut/new-body. This is the Fusion-like loop; get it right before booleans.

### 6. Combine

Union / cut / intersect two bodies. Timeline entries. Failed boolean surfaces as an error on that feature, previous solid kept.

### 7. Fillet and chamfer

Edge picking via OCCTSwiftTools IDs. Radius in inspector, live preview. If edge pick is not reliable in time, ship “all sharp edges of selected body” as a fallback *and* keep the edge-id data model so picking can land without a format change.

### 8. Export and HIG pass

File → Export STL / 3MF. Toolbar customization. Keyboard shortcuts complete. Light/dark. VoiceOver on inspector. No leftover Fusion-isms (ribbons, in-viewport command strips, un-menu’d tools).

---

## Tests

Swift Testing on the model, not UI snapshots:

- Encode/decode `.cad` v1
- Rebuild box / extrude / cut / fillet produces a solid (non-zero volume)
- Editing an early feature invalidates later kernel shapes and rebuilds
- Failed fillet does not drop the file’s feature list
- STL and 3MF writers emit a readable mesh from a known box (40×20×10 mm → expected bounds)

Viewport/HIG checked in the running app (Xcode). No Electron, no browser.

---

## Risks

| Risk | Mitigation |
|---|---|
| OCCTSwiftViewport is SwiftUI-first | Host only the 3D pane; chrome stays AppKit. If the NSView path is awkward, `NSHostingView` for that pane alone. |
| Topology IDs break after a rebuild (fillet edges move) | Name edges relative to the feature that created them; fail that feature instead of silently filleting the wrong edge. |
| OCCT rebuild too slow for live drag | Debounce inspector sliders; coarse tessellation while dragging; full tessellation on mouse-up. Serial queue, never main. |
| Sketch-on-face slips | Ship origin planes first. Face-sketch is additive. |
| LGPL + static SPM link | Depend on the official packages; do not vendor OCCT sources. Keep the exception files in the tree if the packages require attribution. |

---

## Out of scope until v1 ships

Revolve, loft, sweep, shell, hole, pattern, threads, GCS, STEP, multi-body assemblies, printer bed, overhang analysis, slicer, iPad/Catalyst, Intel, custom window chrome, SwiftUI app structure.

