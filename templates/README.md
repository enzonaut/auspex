# templates

A template is a file that `auspex_render` (`lib/render.sh`) fills with values from the palette of the current theme (`themes/$(cat themes/current)/colors.toml`). A manifest row with mode `render` names a template as its source:

```
templates/waybar/style.css.tpl	~/.config/waybar/style.css	render	hyprland
```

## Syntax

| Form | Output for `bronze = "#C9A05A"` |
|---|---|
| `{{ bronze }}` | `#C9A05A` |
| `{{ bronze \| bare }}` | `C9A05A` |
| `{{ bronze \| rgba:ff }}` | `C9A05Aff` |
| `{{ bronze \| dec }}` | `201, 160, 90` |
| `{{ font_body }}` | `Jost` (a text value) |

- Spaces inside `{{ }}` are optional. `{{bronze|bare}}` is correct.
- `rgba:` takes 2 hex digits for the alpha value, for example `rgba:ff` or `rgba:80`.
- The filters `bare`, `rgba:<aa>` and `dec` work only on a color value (`#RRGGBB`).
- All other text goes to the output with no change. The output keeps the final newline of the template, or has no final newline when the template has none. The output file has the mode of the template.

## Errors

These errors stop the render. The message gives the file path and the line number. The renderer does not write the output file.

- An unknown key.
- An unknown filter.
- A color filter on a text value.
- A bad palette line, or a palette key that occurs 2 times.
- A `{{` that is still in a line after the render.

## Rules

- The renderer reads only the palette and the template. It reads no environment value. The same inputs give the same bytes.
- `auspex apply`, `auspex plan` and `auspex status` render each `render` row into `$AUSPEX_STATE/rendered/<target path>`. Then the row works as a `copy` row.
- Do not edit a rendered target. Edit the template or the palette, commit, then run `auspex apply`.
