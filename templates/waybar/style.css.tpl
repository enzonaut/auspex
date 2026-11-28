* {
  font-family: "{{ font_data }}";
  font-size: 13px;
  border: none;
  border-radius: {{ radius }}px;
  box-shadow: none;
  text-shadow: none;
  min-height: 0;
}

window#waybar {
  background-color: {{ bg_dark }};
  color: {{ text }};
  border-top: {{ border_width }}px solid {{ border }};
  border-bottom: {{ border_width }}px solid {{ border }};
  background-image: repeating-linear-gradient(90deg, {{ bronze_dark }} 0px, {{ bronze_dark }} 6px, transparent 6px, transparent 10px);
  background-size: 100% 3px;
  background-position: left bottom;
  background-repeat: no-repeat;
}

#workspaces button {
  font-family: "{{ font_display }}";
  letter-spacing: 0.12em;
  padding: 0 12px;
  color: {{ text_muted }};
  background: transparent;
  transition: color {{ motion_ms }}ms;
}

#workspaces button.active {
  background-color: {{ porphyry }};
  color: {{ text_bright }};
}

#workspaces button.urgent {
  color: {{ accent }};
}

#clock {
  font-family: "{{ font_display }}";
  color: {{ gold }};
  letter-spacing: 0.12em;
}

#pulseaudio,
#network,
#tray {
  font-family: "{{ font_data }}";
  color: {{ text_muted }};
  padding: 0 12px;
  transition: color {{ motion_ms }}ms;
}

#custom-legio {
  font-family: "{{ font_data }}";
  color: {{ text_muted }};
  padding: 0 12px;
  transition: color {{ motion_ms }}ms;
}

#custom-legio.blocked {
  color: {{ accent }};
}
