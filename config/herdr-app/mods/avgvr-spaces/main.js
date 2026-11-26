import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, run, theme } from "herdr";

export function tone(t, status) {
  if (status === "blocked") return t.blocked;
  if (status === "working") return t.working;
  if (status === "done") return t.done;
  return t.idle;
}

export function label(name) {
  return `[ ${String(name ?? "").toUpperCase()} ]`;
}

export default class AvgvrSpaces extends View {
  cell(w, t) {
    const on = w.active;
    return div()
      .id(`avgvr-space-${w.id}`)
      .flex_none()
      .h_full()
      .px(10)
      .flex()
      .items_center()
      .font_family("Marcellus SC")
      .text_size(13)
      .text_color(on ? t.foreground : tone(t, w.status))
      .when(on, (el) => el.bg(t.selected).font_bold())
      .when(!on, (el) => el.hover((s) => s.bg(t.surface)))
      .on_click(() => run("space.select", { id: w.id }))
      .child(label(w.name));
  }

  render() {
    const t = theme();
    return h_flex()
      .size_full()
      .min_w(0)
      .items_center()
      .bg(t.chrome)
      .border_b_1()
      .border_color(t.border)
      .overflow_x_scroll()
      .children(spaces().map((w) => this.cell(w, t)))
      .child(
        div()
          .id("avgvr-space-new")
          .flex_none()
          .h_full()
          .px(10)
          .flex()
          .items_center()
          .font_family("Marcellus SC")
          .text_size(13)
          .text_color(t.muted)
          .hover((s) => s.bg(t.surface).text_color(t.foreground))
          .on_click(() => run("space.new"))
          .child("[ + ]"),
      );
  }
}
