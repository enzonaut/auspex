background {
    monitor =
    color = rgb({{ bg_darker | bare }})
    blur_passes = 0
}

shape {
    monitor =
    size = 100%, 1
    color = rgb({{ bronze | bare }})
    position = 0, 0
    halign = center
    valign = center
}

image {
    monitor =
    path = /usr/share/sddm/themes/avgvr/mark.png
    size = 64
    border_size = 0
    position = 0, 140
    halign = center
    valign = center
}

label {
    monitor =
    text = $TIME
    color = rgb({{ gold | bare }})
    font_family = {{ font_display }}
    font_size = 48
    position = 0, 60
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:60000] date +"%A %d %B"
    color = rgb({{ text_muted | bare }})
    font_family = {{ font_body }}
    font_size = 16
    position = 0, -40
    halign = center
    valign = center
}

input-field {
    monitor =
    size = 400, 48
    position = 0, -140
    halign = center
    valign = center
    outer_color = rgb({{ bronze | bare }})
    inner_color = rgb({{ bg_darker | bare }})
    font_color = rgb({{ text_bright | bare }})
    font_family = {{ font_body }}
    check_color = rgb({{ gold | bare }})
    fail_color = rgb({{ accent | bare }})
    rounding = 0
    outline_thickness = 1
    fade_on_empty = true
}
