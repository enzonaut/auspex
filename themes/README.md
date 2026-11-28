# themes

Each folder in `themes/` is 1 theme. `themes/current` holds the name of the theme that `auspex apply` uses. The name must be a folder in `themes/`. Only `avgvr` exists now.

## Palette

`themes/<name>/colors.toml` is the palette. `auspex_render` (`lib/render.sh`) reads it for each `render` row of the manifest.

A palette line has 1 of these forms. An empty line is also permitted. Another line form stops the render.

```
# comment
key = "#RRGGBB"
key = "text"
```

- A key matches `^[a-z][a-z0-9_]*$`. A key occurs 1 time.
- A value that matches `#RRGGBB` is a color. Another value is text.

## AVGVR palette keys

`themes/avgvr/colors.toml` has these keys:

| Group | Keys |
|---|---|
| Design record (`design/directions/c/colors.toml`, same values) | `accent`, `selection`, `muted`, `cursor`, `darker_background`, `dark_background`, `background`, `lighter_background`, `foreground`, `dark_foreground`, `darker_foreground`, `lighter_foreground`, `black` to `white`, `bright_black` to `bright_white`, `porphyry`, `bronze`, `bronze_dark`, `gold`, `verdigris`, `border`, `crest`, `helmet_gold`, `gold_shadow`, `laurel_bronze` |
| ANSI colors (same values as `black` to `bright_white`, in ANSI order) | `color0` to `color15` |
| DIRECTION.md tokens | `bg`, `bg_dark`, `bg_darker`, `surface`, `text`, `text_muted`, `text_faint`, `text_bright` |
| Font and shape tokens (text) | `font_display`, `font_body`, `font_data`, `border_width`, `radius`, `motion_ms` |

Do not edit `design/directions/c/`. To change a color, change the palette, then run `auspex apply`. 1 generation changes all `render` targets.
