return {
  config = {
    general = {
      border_size = {{ border_width }},
      gaps_in = 6,
      gaps_out = 12,
      col = {
        active_border = "rgb({{ bronze | bare }})",
        inactive_border = "rgb({{ border | bare }})",
      },
    },
    decoration = {
      rounding = {{ radius }},
      shadow = { enabled = false },
      blur = { enabled = false },
    },
    group = {
      col = {
        border_active = "rgb({{ bronze | bare }})",
        border_inactive = "rgb({{ border | bare }})",
      },
      groupbar = {
        col = {
          active = "rgb({{ surface | bare }})",
          inactive = "rgb({{ surface | bare }})",
        },
        text_color = "rgb({{ gold | bare }})",
      },
    },
    animations = { enabled = true },
    misc = {
      background_color = "rgb({{ bg_darker | bare }})",
      disable_hyprland_logo = true,
      disable_splash_rendering = true,
      allow_session_lock_restore = true,
    },
  },
  curve = { name = "linear_out", points = { { 0, 0 }, { 1, 1 } } },
  animation_speed = {{ motion_ms }} / 100,
}
