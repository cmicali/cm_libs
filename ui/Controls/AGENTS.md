# ui/Controls

Controls an app draws itself. It depends on `core/Graphics`. **Today it holds what Vibe moved here, and it is macOS only**: the symbol button, the drawn slider and switch, the detent slider, two image views, and the link label. They sit in its `Mac/` half. The loading and equalizer indicators, which both platforms draw, join it later as shared files. It gains an iOS target then.

## Mac/

AppKit controls drawn with CALayers or in `drawRect:`. None reads an app's settings, strings, or types. An app pushes in what a control shows.

### SymbolButton

A borderless momentary push button (`NSControl`) that draws an SF Symbol. It rasterizes the symbol at the backing scale into a CALayer **mask** over a flat color layer. CALayer cannot tint its contents. The mask keeps the hover, press, and disabled transitions as color fades on the render server.

It fades to its highlight color on hover and dims to half that while pressed. It tracks a drag off and back, sends its action on mouse-up inside, and lets clicks through when disabled. Swapping `symbolName` redraws at once with no fade. Each button sets its own `symbolPointSize`, and the icon draws centered in the frame.

**The state colors keep one relationship**: the factory ratios of the resting alpha (0.55) to hover (0.8), pressed (half of hover), and disabled (0.19). `setSymbolColorsFromRestingColor:` derives all of them from one color, alpha included. So an app dresses a button with one color. **A custom `image` replaces the symbol.** A second layer draws the picture in its own colors, aspect-fit into the box a glyph of the configured size fills. The same states fade its opacity by the same ratios, over full strength at hover. While an image is set, the symbol and colors are ignored. nil returns to the mask.

### Drawn controls

`DrawnControls.h` holds controls drawn in `drawRect:` in place of AppKit's, to AppKit's measured metrics and colors. They draw gray while the window is not key, and at half alpha when disabled.

**TRAP: draw a control yourself to avoid AppKit's SwiftUI control hosts and their Metal startup cost on macOS 26.** A slider subclass that draws itself stays unhosted. `VibeDetentSlider` uses that path. Check the view tree for `_NSCoreHostingView` before changing a control.

- **`VibeSlider`** runs from 0 to 1. Its fill is `trackFillColor`, or the system accent when that is nil. `knobColor` replaces the system knob. It is a VoiceOver slider that steps 5%. Its spoken value is whatever `accessibilityValueFormatter` returns, so the control formats nothing. It sends its action from the mouse-down, from every drag that moves it, and always from the mouse-up, each from its own event handler. So `NSApp.currentEvent` tells a target which one it was. `moveBySteps:` moves it by whole or fractional 5% steps, and sends the action when it moved.
- **`VibeSwitch`** matches the small `NSSwitch`, with its slide, Space under full keyboard access, and a VoiceOver checkbox of the switch subrole. Setting `state` neither slides nor sends the action.
- **`VibeDetentSlider`** is an `NSSlider` with a detent, in a file of its own. It draws ticks above and below the track at `detentValue`, where its action snaps.

### Image views

- **`CrossfadingImageView`** is a layer-backed `NSImageView`. `setImage:` cross-fades the new image over the old. It vends `kVibeArtCrossfadeDuration`, so an app can fade other views on the same clock. The new image sits beneath the outgoing fade layers. At most two outgoing layers remain, and a third drops the oldest. An in-flight fade never resets to opaque. It is opted out of drag and drop, so file drops fall through to the window.
- **`ScaledImageView`** is an `NSImageView` with a `drawImageOverlayInRect:` hook for subclasses.

### VibeLinkLabel

An `NSTextField` with **one clickable range**, hit-tested against the link's own glyphs. A selectable `NSTextField` would give links for free. But a label can span its window's full width while its text is short and centered. Selectability would turn that strip into an I-beam that also swallows the window's background drag. Hit-testing the glyphs means only those characters take the click, the pointing-hand cursor, and the focus ring.

With no link set it is an ordinary label. It is not focusable, not an accessibility link, and transparent to hits. With a link it is a link named by its visible line, focusable *only* while it carries one, and activated by Return and Space alone. The link's glyphs take the click, and the rest of the line does not.

**TRAP: a reused window (`releasedWhenClosed = NO`) keeps its first responder across a close.** A focused link would come back with its ring drawn on a window the user just opened. The window's owner clears it in `windowWillClose:` with `makeFirstResponder:nil`.

## Tests

`Tests/ui/Controls/Mac/` holds the drawn-control, symbol-button, and link-label tests. They run on macOS with no window server. A view renders into a bitmap (`DrawnViewTestSupport.h`), and the tests assert facts about the pixels. They never compare against a stored image, which breaks on every OS change. A deferred window is never key, so the fills drawn here are the not-key ones. NSApp is nil, so a sent action is not asserted. A dragging session and a key window need a window server, so the app checks them in its running build. `DrawnViewTestSupport.h` is a copy of Vibe's, whose other view tests keep using it.
