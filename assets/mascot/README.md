# Mascot poses — drop-in convention

`widgets/mascot.dart` looks for files named exactly:

```
assets/mascot/mascot_greeting.svg
assets/mascot/mascot_pointing.svg
assets/mascot/mascot_celebrating.svg
assets/mascot/mascot_standing.svg
```

   Any subset works — `Mascot` probes for each pose's file at runtime and
   paints the existing procedural character for whichever poses aren't present
   yet, so you can drop poses in one at a time.

   ## Sourcing (Blush)

   1. `blush.design` — sign in yourself; a plain unauthenticated visit hits
      their bot-check page, so I can't browse this one for you.
   2. Search collections tagged **Character** that offer a *composer* —
      swappable pose/arms/expression, not a single static illustration. Blush's
      free tier historically caps vector (SVG) export behind Pro; PNG export is
      usually free. Either works here — see the note on transparency below.
   3. Recolor the character's fill(s) to match the rest of the app, **unlike**
      the decor shapes — the mascot is multi-part (body/face/accent) and never
      gets force-tinted, so get the color right in Blush's editor itself:
      - body → `#FD4401` (brand orange)
      - face → `#F3EFE0` (cream)
      - accent/highlight (if the collection has one) → `#FDCB40` (warm yellow)
   4. Compose the 4 poses below, using whatever arm/expression variants the
      collection offers, matched by *meaning* rather than exact label:
      - `greeting` — waving hello, arm raised
      - `pointing` — one arm extended, giving an instruction
      - `celebrating` — both arms up, correct-answer beat
      - `standing` — a neutral resting pose, arms down. Does double duty as
        both the idle state and the "try again" moment — there's no separate
        discouraging pose; `Mascot` plays a small jump animation on every
        pose change, so the *reaction* to a wrong answer is the hop into this
        pose, not a sadder-looking character.
   5. Export each at reasonable size (SVG any size; if PNG, export **at least
      384×384** so it holds up at the 2-3x scale factors phones render at —
      this renders at 80-120px logical but needs the pixel density headroom).
   6. If you can only get PNG: still name them `mascot_<pose>.png` in this
      folder and tell me — `Mascot`'s loader takes a one-line change to also
      probe the `.png` extension; SVG is preferred only because it scales
      without a fixed source resolution.
   7. **Transparent background only** — no card/frame baked into the export;
      the mascot sits directly on whatever the screen's background is.

   Restart the app (not just hot reload) after adding files.
