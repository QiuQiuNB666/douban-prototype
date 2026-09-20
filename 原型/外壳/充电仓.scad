// 充电仓 v0.1（soundcore Work / D3200 的充电盒）—— 参考模型，不是拿来打印的
//
// 用途：① 渲染图里配齐一套；② 给「充电仓收纳架 / 桌面座」之类的外壳做干涉检查（见 装配检查.scad）。
// 坐标：盒子中心在原点，底面 z = 0，顶面朝 +Z。座舱在 +X +Y 那个角。
//
// 尺寸来源：
//   【专利】EUIPO 015107944-0001 七视图，把俯视图的边长当 60 mm 定标，逐像素量的：
//           外形 60×60、圆角 R13.5、盒体厚 8.12、顶盖接缝离顶面 1.03、
//           座舱 Ø24.0 且与转角圆弧同心；**座舱是开口的**：盒子这个角被切掉，只剩一段 C 形墙
//           （从俯视图量：墙从 116° 绕到 336°，开口正对角、半角 70°）和一片伸到角上的底板；
//           底板上 Ø18.3 的圆是磁铁
//   【官方】soundcore 规格表 60×60×14.95 —— 14.95 是「豆子坐在座舱里」的总高，不是盒体厚度：
//           8.12（盒体）+ 13.45（豆子）− 6.62（座舱深）= 14.95，三个来源就此自洽
//           （爱搞机写「8 mm 厚」说的是盒体，ITmedia 写「15 mm」说的是含豆子总高）
//   【实拍】52audio 评测：同一条侧边上，左边三颗指示灯、中间 USB-C、右边一颗功能键；
//           座舱底有圆形磁铁、侧壁有充电触点；盒底有 MagSafe 磁吸
//
// 对不上的地方（别当成已定稿）：接口在哪条边，见 port_side。
// v0.1 曾把座舱画成封闭圆孔，那样豆子的侧键会顶到舱壁；改成开口后侧键从开口伸出去，不再打架。
// 和录音豆.scad 一样，这是参考模型，不是拿来打印的。

include <录音豆.scad>
show_seat = false;
show_bean_model = false;

/* [看什么] */
// 单独打开本文件时画一个充电仓；别的文件 include 时设成 false
show_case_model = true;
// 把豆子也放进座舱里
show_bean_in_case = false;

/* [盒体] */
// 【专利/官方】边长
case_w = 60; // .1
// 【专利】盒体厚度（不含露在外面的豆子）
case_h = 8.12; // .01
// 【专利】四角圆角半径
corner_r = 13.5; // .1
// 【专利】顶盖接缝离顶面多深
seam_top = 1.03; // .01
// 上下棱的倒圆
edge_r = 0.6; // .1

/* [座舱] */
// 【专利】座舱直径（豆子 23.34，单边余量 0.33）
dock_d = 24.0; // .01
// 【推算】座舱深度 = 盒体厚 − 底板厚：8.12 + 豆子 13.45 − 6.62 = 官方总高 14.95。底板剩 1.5，和立体图上那片薄底板相符
dock_depth = 6.62; // .01
// 【专利】开口半角：C 形墙缺掉的那一段，以指向盒角的 45° 为中心
open_half = 70;
// 【推算】豆子坐进去时绑带指向的角度（0° = +X）。绑带和侧键都得落在开口里，触点得落在墙上：
//   绑带 90°±21° 在开口 (−25°~115°) 里，侧键在 0°±17.5° 也在开口里，触点在 270°±38° 正好压在墙上
bean_dir = 90;
// 【专利】座舱底那个圆（磁铁）的直径
magnet_d = 18.3; // .1

/* [侧边接口] */
// 【估】接口在哪条边：0 = -Y，1 = +X，2 = +Y，3 = -X（专利四个侧视图分不出朝向，实拍只说「同一条边」）
port_side = 0;
// 【专利】USB-C 口：宽 × 高
usb_w = 8.9; // .1
usb_h = 3.0; // .1
// 【专利】USB-C 中心离这条边的中点多远（正数 = 往 +X 方向）
usb_off = 0; // .1
// 【专利】功能键：宽 × 高
btn2_w = 6.2; // .1
btn2_h = 3.0; // .1
// 【专利】功能键中心相对 USB-C 的偏移
btn2_off = 13.9; // .1
// 【专利】三颗指示灯：直径、间距、第一颗相对 USB-C 的偏移
led_d = 0.9; // .1
led_gap = 1.5; // .1
led_off = -12.3; // .1

/* [盒底] */
// 【实拍】底面 MagSafe 磁吸环的中径，0 = 不画
magsafe_d = 45; // .1

/* [Hidden] */
c_case  = [0.20, 0.20, 0.22];
c_dock  = [0.13, 0.13, 0.14];
c_mag   = [0.26, 0.25, 0.24];
c_cu    = [0.80, 0.52, 0.32];
c_lite  = [0.85, 0.86, 0.88];

dock_c  = [case_w / 2 - corner_r, case_w / 2 - corner_r];   // 座舱圆心 = 转角圆弧的圆心
dock_z  = case_h - dock_depth;                              // 座舱底板上表面

assert(dock_d / 2 + 1.0 <= corner_r, "座舱比转角圆弧还大，转角会破口：调小 dock_d 或调大 corner_r");
assert(dock_depth < case_h, "座舱比盒体还深");
assert(dock_d > bean_d, "座舱塞不下豆子");
assert(open_half >= 60 && open_half < 90, "开口半角量出来是 70°，别离谱");
strap_half2 = asin((strap_w / 2 + 0.5) / (bean_d / 2));
btn_half2   = asin((btn_w / 2 + 0.5) / (bean_d / 2));
assert(bean_dir - strap_half2 >= 45 - open_half && bean_dir + strap_half2 <= 45 + open_half, "豆子的绑带撞墙：调 bean_dir");
assert(bean_dir - 90 - btn_half2 >= 45 - open_half && bean_dir - 90 + btn_half2 <= 45 + open_half, "豆子的侧键撞墙：调 bean_dir");

// 60×60、圆角 corner_r 的方形，往里缩 d
module rsq(d = 0) offset(r = corner_r - d) square([case_w - 2 * corner_r, case_w - 2 * corner_r], center = true);

module body() hull() for (p = [[0, edge_r], [edge_r, 0], [edge_r, case_h], [0, case_h - edge_r]])
    translate([0, 0, p[1]]) linear_extrude(eps) rsq(p[0]);

// 座舱：Ø24 的圆，再加上正对盒角的一个扇形，把角上的墙整个切掉；底板留着
module dock_cut() translate([dock_c[0], dock_c[1], dock_z]) {
    cylinder(d = dock_d, h = case_h, $fn = 120);
    linear_extrude(case_h) polygon(concat([[0, 0]], [for (a = [45 - open_half : 5 : 45 + open_half]) 40 * [cos(a), sin(a)]]));
}

// 侧边那条边上的一个洞：沿 -Y 边开，再按 port_side 转过去。y0 = 从边面往外多少开始，len = 进多深
module on_edge(off, w, h, shape = "rt", y0 = -1, len = 4) rotate(90 * port_side)
    translate([off, -case_w / 2 + y0, case_h / 2]) rotate([-90, 0, 0])
        if (shape == "rt") hull() for (s = [-1, 1]) translate([s * (w - h) / 2, 0, 0]) cylinder(d = h, h = len, $fn = 24);
        else cylinder(d = w, h = len, $fn = 24);

module cuts() {
    dock_cut();
    // 舱口倒角
    translate([dock_c[0], dock_c[1], case_h - 0.35]) cylinder(d1 = dock_d, d2 = dock_d + 0.7, h = 0.36, $fn = 120);
    // 座舱底的磁铁：嵌进底板，和底面齐平
    translate([dock_c[0], dock_c[1], dock_z - 0.12]) cylinder(d = magnet_d, h = 0.13, $fn = 120);
    // 舱壁上两个触点窝，也嵌进去
    translate([dock_c[0], dock_c[1], 0]) for (s2 = [-1, 1]) rotate(bean_dir + 180 + s2 * contact_a)
        translate([dock_d / 2 - 0.5, -1.6, dock_z + 1.0]) cube([0.6, 3.2, 2.2]);
    // 顶盖接缝
    difference() {
        translate([0, 0, case_h - seam_top]) linear_extrude(0.18) rsq(-1);
        translate([0, 0, case_h - seam_top - 1]) linear_extrude(3) rsq(0.12);
    }
    on_edge(usb_off, usb_w, usb_h);
    on_edge(usb_off + btn2_off, btn2_w, btn2_h);
    for (i = [0 : 2]) on_edge(usb_off + led_off + i * led_gap, led_d, led_d, "c");
    // 盒底 MagSafe 磁吸环（只是一道浅槽，看得出位置）
    if (magsafe_d > 0) translate([0, 0, -eps]) linear_extrude(0.25)
        difference() { circle(d = magsafe_d + 3, $fn = 120); circle(d = magsafe_d - 3, $fn = 120); }
}

module charge_case() {
    color(c_case) difference() { body(); cuts(); }
    translate([dock_c[0], dock_c[1], 0]) {
        // 座舱内壁和底，画深一号的颜色
        color(c_dock) translate([0, 0, dock_z - 0.02]) cylinder(d = dock_d - 0.04, h = 0.02, $fn = 120);
        color(c_mag) translate([0, 0, dock_z - 0.12]) cylinder(d = magnet_d, h = 0.12, $fn = 120);
        // 舱壁上两个充电触点，和豆子侧面那两片对上；做成和舱壁齐平，不往舱里凸
        for (s = [-1, 1]) rotate(bean_dir + 180 + s * contact_a)
            color(c_cu) translate([dock_d / 2 - 0.5, -1.6, dock_z + 1.0]) cube([0.5, 3.2, 2.2]);
    }
    color(c_lite) for (i = [0 : 2]) on_edge(usb_off + led_off + i * led_gap, led_d - 0.2, 0, "c", -0.02, 0.25);
}

if (show_case_model) {
    charge_case();
    // 豆子：磁吸片贴在座舱底，绑带和侧键从开口伸出去
    if (show_bean_in_case) translate([dock_c[0], dock_c[1], dock_z + plate_t]) rotate(bean_dir) bean(gap = 0);
}
