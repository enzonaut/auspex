
fun rgb(r, g, b) {
    c.r = r / 255;
    c.g = g / 255;
    c.b = b / 255;
    return c;
}

bg = rgb({{ bg | dec }});
muted = rgb({{ text_muted | dec }});

Window.SetBackgroundTopColor(bg.r, bg.g, bg.b);
Window.SetBackgroundBottomColor(bg.r, bg.g, bg.b);

W = Window.GetWidth();
H = Window.GetHeight();
S = H / 2160;
BLOCKS = 40;
BULLETS = 24;
GAP = Math.Int(56 * S + 0.5);
FONT = "Sans " + Math.Int(28 * S + 0.5);

fun scaled(img) {
    return img.Scale(Math.Int(img.GetWidth() * S + 0.5), Math.Int(img.GetHeight() * S + 0.5));
}

mark = scaled(Image("mark.png"));
word = scaled(Image("wordmark.png"));

num_off[0] = scaled(Image("numeral-I-off.png"));
num_off[1] = scaled(Image("numeral-II-off.png"));
num_off[2] = scaled(Image("numeral-III-off.png"));
num_off[3] = scaled(Image("numeral-IV-off.png"));
num_off[4] = scaled(Image("numeral-V-off.png"));
num_off[5] = scaled(Image("numeral-VI-off.png"));
num_off[6] = scaled(Image("numeral-VII-off.png"));
num_off[7] = scaled(Image("numeral-VIII-off.png"));
num_off[8] = scaled(Image("numeral-IX-off.png"));
num_off[9] = scaled(Image("numeral-X-off.png"));
num_on[0] = scaled(Image("numeral-I-on.png"));
num_on[1] = scaled(Image("numeral-II-on.png"));
num_on[2] = scaled(Image("numeral-III-on.png"));
num_on[3] = scaled(Image("numeral-IV-on.png"));
num_on[4] = scaled(Image("numeral-V-on.png"));
num_on[5] = scaled(Image("numeral-VI-on.png"));
num_on[6] = scaled(Image("numeral-VII-on.png"));
num_on[7] = scaled(Image("numeral-VIII-on.png"));
num_on[8] = scaled(Image("numeral-IX-on.png"));
num_on[9] = scaled(Image("numeral-X-on.png"));

bar_w = Math.Int(W * 0.4);
pitch = bar_w / BLOCKS;
block_h = Math.Int(Image("dentil-off.png").GetHeight() * S + 0.5);
dentil_off = Image("dentil-off.png").Scale(Math.Int(pitch * 0.7), block_h);
dentil_on = Image("dentil-on.png").Scale(Math.Int(pitch * 0.7), block_h);

num_h = num_off[0].GetHeight();
stack_h = mark.GetHeight() + GAP + word.GetHeight() + GAP + num_h + GAP + block_h;
y = Math.Int((H - stack_h) / 2);
bar_x = Math.Int((W - bar_w) / 2);

mark_sprite = Sprite(mark);
mark_sprite.SetPosition(Math.Int((W - mark.GetWidth()) / 2), y, 1);
y = y + mark.GetHeight() + GAP;

word_sprite = Sprite(word);
word_sprite.SetPosition(Math.Int((W - word.GetWidth()) / 2), y, 1);
y = y + word.GetHeight() + GAP;

slot = bar_w / 10;
for (k = 0; k < 10; k = k + 1) {
    num_sprite[k] = Sprite(num_off[k]);
    num_sprite[k].SetPosition(Math.Int(bar_x + k * slot + (slot - num_off[k].GetWidth()) / 2), y, 1);
}
y = y + num_h + GAP;

for (i = 0; i < BLOCKS; i = i + 1) {
    block[i] = Sprite(dentil_off);
    block[i].SetPosition(Math.Int(bar_x + i * pitch + pitch * 0.15), y, 1);
}
bar_bottom = y + block_h;

message_y = bar_bottom + GAP;
message_sprite = Sprite();
message_sprite.SetPosition(0, message_y, 2);

fun progress(p) {
    if (p < 0) p = 0;
    if (p > 1) p = 1;
    lit = Math.Int(p * BLOCKS);
    for (i = 0; i < BLOCKS; i = i + 1) {
        if (i < lit) global.block[i].SetImage(global.dentil_on);
        else global.block[i].SetImage(global.dentil_off);
    }
    for (k = 0; k < 10; k = k + 1) {
        if (p >= (k + 1) / 10) global.num_sprite[k].SetImage(global.num_on[k]);
        else global.num_sprite[k].SetImage(global.num_off[k]);
    }
}

fun boot_progress(duration, p) {
    progress(p);
}

// plymouth gives the system update progress in percent.
fun system_update(percent) {
    progress(percent / 100);
}

fun show_message(text) {
    img = Image.Text(text, global.muted.r, global.muted.g, global.muted.b, 1, global.FONT);
    global.message_sprite.SetImage(img);
    global.message_sprite.SetX(Math.Int((global.W - img.GetWidth()) / 2));
}

Plymouth.SetBootProgressFunction(boot_progress);
Plymouth.SetSystemUpdateFunction(system_update);
Plymouth.SetMessageFunction(show_message);

entry = scaled(Image("entry.png"));
bullet = scaled(Image("bullet.png"));
entry_x = Math.Int((W - entry.GetWidth()) / 2);
entry_y = message_y + GAP * 2;
entry_sprite = Sprite(entry);
entry_sprite.SetPosition(entry_x, entry_y, 3);
entry_sprite.SetOpacity(0);
bullet_pitch = bullet.GetWidth() * 1.6;
for (i = 0; i < BULLETS; i = i + 1) {
    bullet_sprite[i] = Sprite(bullet);
    bullet_sprite[i].SetPosition(Math.Int(entry_x + GAP / 2 + i * bullet_pitch),
        Math.Int(entry_y + (entry.GetHeight() - bullet.GetHeight()) / 2), 4);
    bullet_sprite[i].SetOpacity(0);
}

fun show_password(prompt, bullets) {
    show_message(prompt);
    global.entry_sprite.SetOpacity(1);
    for (i = 0; i < global.BULLETS; i = i + 1) {
        if (i < bullets) global.bullet_sprite[i].SetOpacity(1);
        else global.bullet_sprite[i].SetOpacity(0);
    }
}

fun display_normal() {
    global.entry_sprite.SetOpacity(0);
    for (i = 0; i < global.BULLETS; i = i + 1)
        global.bullet_sprite[i].SetOpacity(0);
}

Plymouth.SetDisplayPasswordFunction(show_password);
Plymouth.SetDisplayNormalFunction(display_normal);

progress(0);
