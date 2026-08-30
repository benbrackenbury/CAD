# CAD

Native Mac solid modeller for 3D printing. AppKit, millimetres, `.cad` files.

Fusion-style parametric modelling, without CAM, assemblies, or a slicer. Open `CAD.xcodeproj` in Xcode and run the CAD scheme on My Mac. Apple Silicon, macOS 26+.

The first build pulls [OCCTSwiftViewport](https://github.com/SecondMouseAU/OCCTSwiftViewport) and compiles its Metal shaders. If Xcode complains about a missing Metal toolchain:

```
xcodebuild -downloadComponent MetalToolchain
```

## Using it

File, Edit, View, and Solid are the menus that matter.

**Solid → Box** (⌥⌘B) drops a 40×20×10 mm box. Cylinder and Sphere are in the same menu. Select a feature in the Timeline sidebar and change sizes in the inspector. ⌘Z undoes. Delete removes the selected feature.

Navigation:

| Input | Action |
| --- | --- |
| Click | Select |
| Option-drag | Orbit |
| Shift-drag | Pan |
| Scroll or pinch | Zoom |
| ⌘⇧F | Frame all |
| ⌘1–⌘7 | Front, back, left, right, top, bottom, isometric |

View also toggles orthographic projection and the grid. The view cube in the viewport snaps to those same cameras.

Save as `.cad`. That is pretty-printed JSON of the feature list, not a mesh. Export to STL/3MF is not in yet.

## What is in the file

```json
{
  "features" : [],
  "units" : "mm",
  "version" : 1
}
```

A box looks like `{ "type": "box", "width": 40, "depth": 20, "height": 10, ... }`. Cylinders and spheres use `radius` (and height for cylinders). Origins are millimetres in a Z-up world.

## What is not built yet

Sketch and extrude. Move, rotate, scale as features. Union, cut, fillet, chamfer. STL and 3MF export. The Open CASCADE kernel; the viewport currently tessellates primitives itself, so fillets and booleans cannot be real until that lands.

## Tests

```
xcodebuild -project CAD.xcodeproj -scheme CAD -destination 'platform=macOS,arch=arm64' test -only-testing:CADTests
```
