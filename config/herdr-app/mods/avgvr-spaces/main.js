import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, run, theme } from "herdr";

const STATUS_COLOR = { blocked: "blocked", working: "working", done: "done" };

export function tone(t, status) {
  return t[STATUS_COLOR[status] ?? "idle"];
}

export function label(name) {
  return `[ ${String(name ?? "").toUpperCase()} ]`;
}

function tab(id) {
  return div()
    .id(id)
    .flex_none()
    .h_full()
    .px(10)
    .flex()
    .items_center()
    .font_family("Marcellus SC")
    .text_size(13);
}

function activeCell(el, t) {
  return el.text_color(t.foreground).bg(t.selected).font_bold();
}

function idleCell(el, t, w) {
  return el.text_color(tone(t, w.status)).hover((s) => s.bg(t.surface));
}

function newCell(t) {
  return tab("avgvr-space-new")
    .text_color(t.muted)
    .hover((s) => s.bg(t.surface).text_color(t.foreground))
    .on_click(() => run("space.new"))
    .child("[ + ]");
}

export default class AvgvrSpaces extends View {
  cell(w, t) {
    const el = tab(`avgvr-space-${w.id}`);
    const styled = w.active ? activeCell(el, t) : idleCell(el, t, w);
    return styled.on_click(() => run("space.select", { id: w.id })).child(label(w.name));
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
      .child(newCell(t));
  }
}
