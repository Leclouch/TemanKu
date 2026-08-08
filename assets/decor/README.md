# Decor shapes — drop-in convention

`core/design/components/tk_decor.dart` looks for files named exactly:

```
assets/decor/decor_1.svg
assets/decor/decor_2.svg
...
assets/decor/decor_8.svg
```

Any subset works — you don't need all 8 before this does anything; `TkDecor`
probes for each file at runtime and paints its procedural fallback shape for
whichever numbers aren't present yet.

## Sourcing (Haikei)

1. `app.haikei.app` — no login needed for the generators below.
2. Use a **flat vector generator**: "Blob Corners" or "Bubble" match this
   app's organic-shape vocabulary best. Skip the blurry gradient-mesh
   generators — they only export as PNG, and flat vector is what lets the
   app recolor them.
3. Color doesn't matter — export in whatever color the generator defaults
   to. `TkDecor` force-tints every decor SVG to a token color via
   `ColorFilter` (`srcIn` blend mode) at render time, the same way the
   procedural shapes already take their color from a caller-supplied token
   rather than a literal. This also means a single shape can be reused in
   different washes on different screens without re-exporting.
4. Export → SVG, download, rename to `decor_N.svg`, drop it in this folder.
5. One-color, filled shapes only — no gradients, no strokes-as-decoration,
   no embedded text. A gradient survives the `srcIn` tint as a flat color
   (Flutter tints the whole alpha mask), so it'll just look wrong, not
   broken — but it defeats the point of choosing vector here.

Restart the app (not just hot reload) after adding files — Flutter's asset
bundle is rebuilt at launch, not on file-system change.
