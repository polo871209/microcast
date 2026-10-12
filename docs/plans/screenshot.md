# Screenshot capture plan

Status: phases 1 to 4 are built and covered by their harnesses, with window clicks that capture the window's own pixels. Their manual checks in the running app are open. The later work is next. [features/screenshot.md](../features/screenshot.md) describes what exists. Nanocast gets one command, **Capture Screenshot**, with no default hotkey. Every capability in this plan starts from that one command: area, window and full-display capture, annotation, pin and scrolling capture. The interaction follows Shottr's precision, and the look follows Lark's screenshot toolbar.

Decisions already taken:

- One hotkey starts everything. Scrolling capture and pin are toolbar buttons inside the capture, never separate hotkeys.
- No default hotkey. The user assigns it in Settings > Shortcuts.
- The screen freezes in-process. Phase 0 showed that the frozen frames are IOSurface-backed and are not charged to Nanocast's footprint, so the 100 MB budget holds without an exception. Only an export bitmap costs real memory, and only while it encodes.
- The first cut is the base editor, the Lark extras, the Shottr precision set and scrolling capture. Text recognition, QR codes and translation come later.

## The reference tools split capture and editing differently

### Shottr captures first and edits on a raster

Shottr is closed source, so this comes from its docs, changelog and reviews.

- The default flow takes a full-screen capture, then crops and annotates in an editor window. A freezing area grabber is opt-in since v1.9.
- Precision is the selling point: 1 px arrow-key nudging (Shift for 10 px), a pixel ruler that measures gaps between edges, and a color picker.
- Tools have single-letter keys (A arrow, R rectangle, T text, B blur, pixelate and erase), plus spotlight, step counter, highlighter and freehand.
- Scrolling capture posts scroll events, matches the overlap between frames with computer vision and stitches. The default cap is 20,000 px. Sticky headers repeat and moving content breaks the seams.
- The developer reports 17 ms to grab and about 165 ms to show the editor.

### macshot freezes every display and edits in the overlay

macshot is GPLv3. This comes from its source at <https://github.com/sw33tlie/macshot>.

- Capture uses `SCScreenshotManager.captureScreenshot(rect:configuration:)` on macOS 26 and later. It captures displays one at a time, cursor display first, and shows each overlay when its image lands, because `replayd` serializes concurrent requests and charges about 1.3 s per queued request instead of about 380 ms.
- Each display gets a borderless `.nonactivatingPanel` at level 257 with the frozen image in a `CALayer`, a dim mask with a hole, and 8 resize handles. Window snap reads the z-ordered `CGWindowListCopyWindowInfo` list. `animationBehavior = .none` stops the Reduce Motion zoom.
- Rect capture takes CoreGraphics display space, with the origin at the top-left of the primary display. Passing an AppKit frame shifts non-primary displays (their issues #291 and #294).
- Export snaps the selection to device pixels and draws with interpolation off, so the output is pixel-exact.
- Scrolling capture grabs frames with `CGWindowListCreateImage`, detects settle by comparing two frames byte for byte, measures the offset with Vision translational registration, and excludes the sticky header and the scrollbar. `CGWindowListCreateImage` is obsoleted in the macOS 15 SDK, so Nanocast cannot use this part.

Do not copy its structure. `OverlayView.swift` is one 10,405-line class that owns selection, drawing, tools, toolbars and output. Nanocast splits the same work across its Model, Service and UI layers.

### Lark defines the look

- A dimmed frozen screen, a 1 pt blue selection border with 8 round handles, and a dark size pill ("524 x 399", in points) above the top-left corner.
- One toolbar under the selection, aligned to its right edge, in this order: grip, rectangle, ellipse, line, arrow, pen, text, tag, then mosaic, highlight, watermark, pin, translate, extract text, QR code, scrolling capture, then undo, save, cancel, done.
- A second bar under the toolbar holds the active tool's options: stroke width on the left and color on the right.
- Mosaic has a brush mode and a box mode, each with pixelate or blur. Highlight is a rectangle or ellipse spotlight with adjustable opacity. Tag is a text label tied to an anchor dot, and a click on the dot flips its side.
- Done copies to the clipboard. Lark's default hotkey is ⌘⇧A.

## One capture runs from one hotkey

1. The hotkey, or the palette command, freezes every display. The cursor display appears first.
2. On hover, the window under the cursor highlights and a loupe follows the cursor. A click takes that window, or the whole display if no window is under the cursor. A drag draws an area.
3. The handles, arrow keys and size pill adjust the area.
4. A toolbar tool annotates the area. Pin floats it on screen. Scrolling capture extends it into a long image.
5. Return, Esc or ✓ copies the image and closes. ⌘S saves it to the save folder. ✗ discards it.

### The toolbar keeps Lark's order without the later items

| Item                                   | Key                                        | Phase |
| -------------------------------------- | ------------------------------------------ | ----- |
| Rectangle, ellipse, line, arrow        | R, O, L, A                                 | 2     |
| Pen, text                              | P, T                                       | 2     |
| Step, numbered circles                 | N                                          | 3     |
| Mosaic, brush or box, pixelate or blur | B                                          | 3     |
| Highlighter, straight or freehand      | H                                          | 3     |
| Ruler, Shottr's pixel ruler            | none, dropped                              | 3     |
| Pin                                    | none                                       | 3     |
| Scrolling capture                      | none                                       | 4     |
| Undo                                   | ⌘Z, and ⌘⇧Z to redo                        | 2     |
| Save                                   | ⌘S                                         | 1     |
| Discard                                | none                                       | 1     |
| Done                                   | Return, Esc, ⌘C, double-click with no tool | 1     |

Watermark, translate, extract text and QR code get no placeholder slot. Each one gets its slot when it is built.

### Keys and mouse

| When                    | Input                                        | Result                                                  |
| ----------------------- | -------------------------------------------- | ------------------------------------------------------- |
| Before an area exists   | click                                        | take the hovered window, or the whole display           |
| Before an area exists   | drag, Shift for a square, hold Space to move | draw the area                                           |
| Before an area exists   | Return                                       | restore the last area, Shottr's repeat area             |
| Before an area exists   | ⌘A                                           | take the whole display                                  |
| No tool is active       | C                                            | copy the hex color under the cursor                     |
| An area exists, no tool | drag a handle or the inside                  | resize or move                                          |
| An area exists, no tool | arrows, Shift+arrows                         | move 1 px, 10 px                                        |
| An area exists, no tool | ⌘+arrows, ⌘⇧+arrows                          | resize from the bottom-right corner, 1 px, 10 px        |
| An area exists, no tool | right-click                                  | drop the area and go back to hover, if nothing is drawn |
| An area exists          | click the size pill                          | switch it between points and pixels                     |
| A tool is active        | drag                                         | draw. Shift makes squares, circles and 45° lines        |
| A tool is active        | click an annotation, then Delete             | select it, delete it                                    |
| Text or tag editing     | Esc                                          | end the edit and keep the text                          |
| An area exists          | Esc                                          | copy, like Return                                       |
| Before an area exists   | Esc                                          | cancel the capture                                      |

## The architecture follows the Nanocast layers

### Ownership

`AppCore` owns one lazy `ScreenshotCoordinator`. The coordinator owns at most one `ScreenshotSession` (the state of one open capture), the `ScreenshotOverlayController` that shows it, the `PinController` with the open pins and, from phase 4, one `ScrollCaptureController`. Closing a session releases its frozen images. Closing a pin releases its image. Nothing else holds capture pixels.

### Coordinates

The model works in integer device pixels with a top-left origin per display, the same space as the frozen `CGImage`. One function in the canvas converts to view points. This removes sub-pixel crops and the AppKit-to-CoreGraphics flip bugs that macshot hit.

### Capture pipeline

1. Read every input before anything moves: `NSScreen.screens`, the mouse location, the window list (`WindowFrameProvider`) and the last area.
2. Hide the palette without restoring focus. A HUD stays up, and the filter in step 3 leaves it out of the image.
3. Capture the cursor display, show its panel, then capture the other displays one by one. The capture excludes Nanocast's palette and HUD windows through an `SCContentFilter`, so a fade or a late WindowServer commit cannot leak into the image. Phase 0 chose this over the faster rect API.
4. Use the completion-handler form of `SCScreenshotManager`. The async overload force-unwraps a nil image, which ScreenCaptureKit returns for DRM content (see `WindowPreviewCapture.swift`).
5. Set `showsCursor = false`, `ignoreShadows = false` and SDR output.
6. On a window click, capture that window alone with `SCContentFilter(desktopIndependentWindow:)` and `ignoreShadows = true`. The shot covers the frozen screen in the area, and copy, save and pin wait for it.

### One painter draws the screen and the export

`AnnotationPainter` draws every mark into a `CGContext`. The canvas's `AnnotationLayer` calls it in `draw(in:)`, and `ScreenshotRenderer` calls it on the export bitmap. A tool that looks right on screen therefore looks the same in the copied PNG. Mosaic comes first, then shapes and text, in both paths. The canvas composites mosaic as GPU layers from the painter's own paths, so a drag never repaints screen pixels.

### Windows and focus

- Each display gets one `ScreenshotPanel`: borderless, `.nonactivatingPanel`, `canBecomeKey`, `animationBehavior = .none`, `hidesOnDeactivate = false`, `[.canJoinAllSpaces, .fullScreenAuxiliary]`.
- Its level is a new `NSWindow.Level.screenshot` in `Platform/WindowLevel.swift`, `popUpMenu + 1`, above the menu bar and the Dock. The manual sweep checks that the Pinyin candidate window shows above it.
- Nanocast never activates. The panel under the cursor takes key, as the palette does.
- The chrome follows `AppSettings.appearance`, because ui.md lets only `AppCore.applyAppearance()` assign an appearance. In Dark it matches the Lark reference screenshot.

### Views

- AppKit and Core Animation draw the canvas: the frozen image layer, the dim layer, the selection border and handles, the annotation view and the loupe layer. These update on every mouse event, so they stay out of SwiftUI.
- SwiftUI in an `NSHostingView` draws the chrome: the toolbar, the options bar, the size pill and the scrolling HUD. They use `BarButton`, `SymbolImage`, `.tooltip(keyCap:)` and the HUD surface recipe (`panelScrim`, then `GlassEffectView`, then the clip).
- New `Theme` tokens: the capture dim, the handle size, the toolbar metrics and the annotation swatches. The capture dim stays the same in both appearances, because it darkens a photo of the screen and is not ink.
- The selection border uses `Theme.Colors.primaryAction`. Discard uses `destructive` and Done uses `success`, like Lark's red ✗ and green ✓.

### New files

All new files sit under `Nanocast/Features/Screenshot/`. The names follow the suffix table in standards.md. Each `Model/` file imports Foundation and CoreGraphics only.

| File                                                                             | Layer  | Phase | Job                                                            |
| -------------------------------------------------------------------------------- | ------ | ----- | -------------------------------------------------------------- |
| `Model/PixelRect.swift`, `PixelPoint.swift`, `DisplayArea.swift`                 | pure   | 1     | integer pixel rect and point math, an area on one display      |
| `Model/SelectionHandle.swift`                                                    | pure   | 1     | the 8 handles and which one a press hits                       |
| `Model/CapturedDisplay.swift`                                                    | pure   | 1     | one frozen display and its point-to-pixel conversion           |
| `Model/PixelColor.swift`                                                         | pure   | 1     | sRGB color of one pixel and its hex                            |
| `Model/SelectionEdit.swift`                                                      | pure   | 1     | create, move, resize by handle, nudge, clamp, Shift square     |
| `Model/ChromePlacement.swift`                                                    | pure   | 1     | where the toolbar, options bar, size pill and loupe go         |
| `Model/WindowSnapPolicy.swift`                                                   | pure   | 1     | frontmost window at a point, from the snapshot                 |
| `Model/ScreenshotTool.swift`                                                     | pure   | 2     | tools, symbols, keys and toolbar groups                        |
| `Model/ScreenshotFileName.swift`                                                 | pure   | 1     | `Screenshot 2026-05-11 at 14.03.22.png`, clock injected        |
| `Service/DisplayCapture.swift`                                                   | effect | 1     | ScreenCaptureKit freeze per display                            |
| `Service/WindowFrameProvider.swift`                                              | effect | 1     | window list snapshot                                           |
| `Service/ScreenshotRenderer.swift`                                               | effect | 2     | export bitmap with annotations                                 |
| `Service/ScreenshotOutputRunner.swift`                                           | effect | 1     | PNG encoding, pasteboard write and file save                   |
| `UI/ScreenshotCoordinator.swift`                                                 | UI     | 1     | command entry, permission, session and pin lifetime            |
| `UI/ScreenshotSession.swift`                                                     | UI     | 1     | `@Observable` state of one capture                             |
| `UI/ScreenshotOverlayController.swift`                                           | UI     | 1     | per-display panels, key routing, teardown                      |
| `UI/ScreenshotPanel.swift`                                                       | UI     | 1     | the panel                                                      |
| `UI/CaptureCanvasView.swift`                                                     | UI     | 1     | mouse and key input, layer updates                             |
| `UI/LoupeView.swift`, `UI/ScreenshotIntent.swift`                                | UI     | 1     | the magnifier, the actions the overlay asks for                |
| `UI/ScreenshotToolbar.swift`                                                     | UI     | 1     | SwiftUI toolbar                                                |
| `UI/SelectionSizePill.swift`                                                     | UI     | 1     | SwiftUI size pill                                              |
| `Settings/ScreenshotSettingsView.swift`                                          | UI     | 1     | save folder, the command and its hotkey                        |
| `Model/Annotation.swift`, `Model/AnnotationStyle.swift`                          | pure   | 2     | value types for every annotation kind and its style            |
| `Model/AnnotationBoard.swift`, `Model/AnnotationHistory.swift`                   | pure   | 2     | draw, select, move, type, delete, undo and redo                |
| `Model/AnnotationGeometry.swift`, `Model/AnnotationMetrics.swift`                | pure   | 2     | constraints, arrow outline, labels, frames, hit testing, sizes |
| `Model/ScreenWindow.swift`, `Model/WindowShot.swift`                             | pure   | 2     | a window from the list, and its own pixels after a click       |
| `Service/AnnotationPainter.swift`, `Service/AnnotationText.swift`                | effect | 2     | Core Graphics and Core Text drawing                            |
| `Service/ScreenshotRenderer.swift`, `Service/CGContext+Upright.swift`            | effect | 2     | export bitmap with annotations                                 |
| `Service/WindowCapture.swift`                                                    | effect | 2     | one window's own pixels                                        |
| `UI/AnnotationLayer.swift`, `UI/AnnotationAppearance.swift`                      | UI     | 2     | the marks layer, and the tokens turned into pixels             |
| `UI/TextEditOverlay.swift`                                                       | UI     | 2     | the `NSTextView` for text                                      |
| `UI/ToolOptionsBar.swift`, `UI/ScreenshotChrome.swift`, `UI/MarkupCommand.swift` | UI     | 2     | SwiftUI options bar, the shared card, toolbar edits            |
| `Service/MosaicSource.swift`                                                     | effect | 3     | the display shrunk into mosaic blocks and a blur               |
| `UI/PinController.swift`, `UI/PinPanel.swift`, `UI/PinView.swift`                | UI     | 3     | floating pins                                                  |
| `Model/RowProfile.swift`, `Model/ScrollStitch.swift`                             | pure   | 4     | row profiles, frame offset, sticky rows, stitch steps          |
| `Service/ScrollFrameCapture.swift`, `Service/ScrollFrame.swift`                  | effect | 4     | one capture of the area, as rows and a profile                 |
| `Service/ScrollStitchFile.swift`                                                 | effect | 4     | the stitched rows in a temporary file                          |
| `Service/AutoScrollRunner.swift`                                                 | effect | 4     | posts scroll-wheel events                                      |
| `UI/ScrollCaptureController.swift`, `UI/ScrollCaptureView.swift`                 | UI     | 4     | scrolling border and HUD                                       |
| `UI/ScrollCaptureSession.swift`, `UI/ScrollCapturePanel.swift`                   | UI     | 4     | the HUD's state, and the border and bar panels                 |

### Existing files that change

| File                                                                                               | Change                                                                                                      |
| -------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `Features/Launcher/Model/CommandID.swift`, `Features/Launcher/UI/LauncherCoordinator.swift`        | the `.captureScreenshot` command and its run case                                                           |
| `Features/Settings/SettingsTab.swift` and the detail, anchor and search catalog files              | a Screenshot pane that owns the command                                                                     |
| `AppSettings`, `AppSettingsKey`, `SettingsFileKey`, `SettingsFileSchema`, `SettingsBackupCoverage` | `screenshotSaveFolder`, with the `AppPaths.contentFolder` tilde-path rules                                  |
| `Platform/Permissions.swift`, `PermissionsSettingsView.swift`, `WindowSwitchCoordinator.swift`     | move the Screen Recording check out of `WindowPreviewCapture` into `Permissions`, and add a Permissions row |
| `Platform/WindowLevel.swift`, `DesignSystem/Theme.swift`, `App/AppCore.swift`                      | the `.screenshot` level, the new tokens, the lazy coordinator                                               |

The docs change in the same commits: a new `docs/features/screenshot.md` that opens with `## Invariants`, the docs index, architecture.md (layer lists and windows), ui.md (overlay chrome), testing.md (harnesses and the manual sweep), and the feature list at the top of AGENTS.md and README.md.

## Build it in five phases

Each phase ends with `./Scripts/run-tests.sh`, `./Scripts/lint.sh`, the Model purity grep and a Debug build without new warnings. Each phase is usable on its own.

### Phase 0 measures the unknowns before any feature code

A throwaway command-line spike on the 2560 × 1440 @2x display (5120 × 2880 pixels) measured these numbers:

| Measure                                                         | Result                          |
| --------------------------------------------------------------- | ------------------------------- |
| `SCScreenshotManager.captureScreenshot(rect:)`                  | 72.6 ms cold, 25–31 ms warm     |
| `SCShareableContent` enumeration plus `SCContentFilter` capture | 11–14 ms plus capture, 38–46 ms |
| `SCShareableContent.currentProcess`                             | 6.2 ms                          |
| Footprint while one 5K frame is held                            | 6.0 MB before, 7.2 MB during    |
| `SCStream` of a 600 × 400 region at 30 fps for 3 s              | 79 complete frames, 15 idle     |

The decisions that follow from the numbers:

- The filter capture ships. It costs about 15 ms more than the rect capture, and it excludes Nanocast's own palette-level windows, so the palette does not need a fade before the capture.
- The frozen `CGImage` is IOSurface-backed and is not charged to the footprint. The memory exception is not needed. A crop without annotations encodes the `CGImage` directly, with no extra bitmap.
- `SCStream` reports `.idle` frames when the region stops changing, so phase 4 uses them to detect settle.

### Phase 1 captures, selects and copies with Shottr's precision

New files: 23, plus the `screenshot-selection-test` harness for every file in `Model/`. A crop without annotations encodes the frozen `CGImage` directly, so `ScreenshotRenderer` moved to phase 2, and `PixelColor` reads the hex without a sampler service.

- The command, the Screenshot pane, the Permissions row, and a dialog when Screen Recording access is missing.
- `DisplayCapture`, the per-display panels, the dim, the selection with handles, and the size pill with its points and pixels switch.
- Window snap on hover, ⌘A for the whole display, Return for the last area, Space to move while drawing, arrow-key nudge and resize.
- The loupe: 15 × 15 px at 8× with a grid, the coordinates and the hex color. C copies the hex.
- The toolbar with save, cancel and done. Done writes PNG to the pasteboard without Nanocast's internal marker, so clipboard history records it, and a HUD confirms the copy. ⌘S saves to the save folder (default `~/Desktop`) and a HUD names the file.

Phase 1 is done when the overlay lines up 1:1 with the screen on two displays with different scales, a copied PNG has the exact pixel size of the area, a capture started from the palette never shows the palette, Reduce Motion shows no zoom, and the footprint returns to baseline after close.

### Phase 2 adds the annotation core

Phases 2 and 3 landed together with window-click capture: 24 new files, so `ls Nanocast/Features/Screenshot/*/*.swift | wc -l` counts 47. The `screenshot-annotation-test` harness covers the board, history, hit testing and arrow geometry. The `screenshot-render-test` harness compiles the painter and the renderer and probes pixels of rendered fixtures.

- Rectangle, ellipse, line, arrow, pen and text.
- The options bar with 4 stroke widths, 6 colors and 3 text sizes.
- Undo and redo, and select, move and delete for annotations.
- Text uses an `NSTextView` that keeps its undo inside the view. macshot learned that a disposable text view on the window's undo manager crashes on the next ⌘Z after the view is freed.

### Phase 3 adds the Lark extras

The planned pixel ruler was dropped after the first manual run, because it saw no use.

- Numbered steps, and a half-transparent highlighter that draws straight or freehand. They replaced the planned tag and spotlight highlight after the first manual run.
- Mosaic in brush or box mode, with pixelate or blur. The block size must be large enough that the text cannot be read back.
- Pin: a floating `.nonactivatingPanel` at `.floating` level on all Spaces. Drag moves it, scroll and pinch zoom it, ⌘C copies, ⌘S saves, and Esc or a double-click closes it. More than one pin can be open.

### Phase 4 adds scrolling capture

New files: 10, plus the `screenshot-stitch-test` harness. It slices a synthetic tall page into overlapping frames with a sticky header, a footer and a scrollbar, and requires a rebuild within one level. A probe in an unoptimized build captured a real 2,400 pt scroll view that animated each scroll. It rebuilt the page at 4,800 px with a worst row difference of 0.16 levels, about 0.5 s per scroll to settle and 3 ms to stitch.

1. The toolbar button hides the dim and the chrome, draws a click-through border just outside the area, and shows a bar with the stitched height, start and stop, save, discard and done. Nothing scrolls before Start.
2. Scrolling is automatic only. The first build stitched every stream frame during a scroll by hand. In an unoptimized build the stitch fell behind and lost the page, and the auto-scroll moved the pointer back on every tick.
3. Nanocast moves the pointer into the area for each scroll and posts pixel scroll-wheel events at it through `AutoScrollRunner`. A posted event goes where the pointer is, and one posted to the app's process scrolls nothing. Setting a scroll bar through Accessibility fails too, because browsers and Lark expose no scroll bar. An event with scroll phases gets momentum, so the event has none. A mouse-moved event puts the pointer back about 10 ms after each scroll, so the user keeps the mouse.
4. `ScrollFrameCapture` takes one capture of the area after each scroll, again until two in a row match. `ScrollStitch` matches the settled frame against the one before it by `RowProfile`, finds the sticky header and footer, and picks the offset nearest the scroll's own distance when several tie.
5. Strips go to a temporary file, and the PNG is encoded from that file at the end, so memory stays near two frames plus the PNG. The cap is 20,000 px, Shottr's default.

The long image opens in the editor, a scroll view whose document is the overlay's canvas, where it is cropped, marked up, copied or saved. Pinning a long image comes later.

### Later work, ranked

1. Read QR codes through the `screenshot` mode of `ClipboardTextHelper`, which already reads text. It needs a way to return barcodes.
2. Translate with `TranslationSession(installedSource:target:)`, which runs offline and without SwiftUI.
3. Watermark, edge snap (macshot's `BoundarySnapIndex`), accessibility-element snap, and a selection that spans displays.

## Check these risks early

1. Capture latency. macshot measured about 380 ms per display through `replayd` on macOS 26, against Shottr's 17 ms. Phase 0 measured 38–46 ms for the filter capture on macOS 27. The only lever is the choice of ScreenCaptureKit call, because `CGWindowListCreateImage` is obsoleted.
2. Memory. One frozen 5K frame is 59 MB of IOSurface memory outside the footprint. An export bitmap of the same size is inside it. Phase 1 must show the footprint back at baseline after close.
3. The cursor and the input method in a non-activating panel. An inactive app cannot always set the cursor, and candidate windows can draw below a high window level. Phase 1 checks the cursor and phase 2 checks the input method.
4. Scroll settle. Phase 4 captures after each scroll until two captures in a row match, so it does not depend on `.idle` frames.
5. Screen Recording prompts. macOS asks again from time to time for apps that capture the screen. The Window Switcher already holds this grant, so the screenshot feature shares the grant and its prompts.

## Licence

macshot is GPLv3 and Nanocast is AGPLv3. Section 13 of both licences allows the combination. The plan reimplements rather than copies. If a file adapts macshot code, it opens with a source link, as `RoomPreviewController.swift` does for Rooms, and NOTICE.md records it. Shottr is closed source, so only its behavior is used.
