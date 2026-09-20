// 录音豆本体 v0.1（soundcore Work / D3200）—— 参考模型，不是拿来打印的
//
// 用途：① 放进托座、蝴蝶结、怪兽的渲染图里；② 做装配干涉检查（见 装配检查.scad）。
// 坐标和 托座.scad 一致：绑带出口 = 0°（+X），从正面看逆时针为正，正面朝 +Z，豆体底面在 z = 0，磁吸片在下面。
//
// 尺寸来源：
//   【图纸】FCC 附录 D 的 CAD 线稿：外径 23.34，含磁吸片总高 13.45（到正面最高点）/ 12.63（到正面边沿）
//   【实拍】我爱音频网评测的四张实物照（正面、侧键侧、触点侧、背面），按外径 23.34 定标量的
//   【专利】EUIPO 015109602-0001 七视图，按外径定标量的。注意它是早期设计：侧键画在绑带旁边，量产机不是
//   豆体外径、磁吸片厚度、绑带宽度、侧键角度沿用 托座.scad 里的值，只有一份

include <托座.scad>
show_seat = false;

/* [看什么] */
// 单独打开本文件时画一颗豆子；别的文件 include 时设成 false
show_bean_model = true;
// 磁吸片和豆体之间隔着多厚的东西：0 = 吸在一起（平时的样子），0.8 = 夹着托座底板
bean_gap = 0; // .1

/* [本体] */
// 【图纸】含磁吸片总高：到正面最高点
h_total = 13.45; // .01
// 【图纸】含磁吸片总高：到正面边沿
h_edge = 12.63; // .01
// 【实拍】正面一圈圆角的半径（专利画的是 R3.25 的平顶，量产机圆角小、中间微拱）
face_fillet = 2.0; // .1
// 【专利】前盖和鼓身的接缝高度（FCC 标签声明里的「厚 8 mm」就是鼓身这一段）
seam_z = 8.1; // .1
// 【专利/实拍】磁吸片直径
plate_d = 20.2; // .1

/* [正面] */
// 【实拍/专利】两个麦克风孔离圆心多远，在绑带这条轴线上，一上一下
mic_r = 9.0; // .1
// 【实拍】麦克风孔：长（垂直于绑带方向）。专利画 3.0×1.0，实拍连边框约 4.4×1.8，取中间
mic_l = 4.0; // .1
// 【实拍】麦克风孔：宽
mic_w = 1.5; // .1
// 【实拍】指示灯离圆心多远，在绑带这一侧的麦克风孔下面
led_r = 6.7; // .1

/* [侧面] */
// 侧键沿圆周方向的长度：直接用 托座.scad 的 btn_w，只留一份
btn_len = btn_w;
// 【实拍/专利】侧键：沿厚度方向的宽度
btn_ax = 3.0; // .1
// 【实拍/专利】侧键中心离豆体底面的高度
btn_z = 4.2; // .1
// 【实拍】侧键凸出杯壁多少。它是大行程自锁键，弹起和按下不一样高；三张实拍 1.7~2.9
btn_out = 2.0; // .1
// 【实拍】两个充电触点各自偏离「绑带正对面」多少度
contact_a = 38;
// 【实拍】蜂鸣器孔高度（在两个触点正中间）
buzz_z = 4.6; // .1
// 【专利】绑带厚度
strap_t = 1.2; // .1
// 【实拍】绑带的环平时鼓出豆体多远
strap_out = 10; // .1

/* [Hidden] */
bean_r  = bean_d / 2;
bean_body_h = h_total - plate_t;   // 豆体自己的高度，到最高点
edge_h  = h_edge - plate_t;    // 到正面边沿
dome_R  = (pow(bean_r - face_fillet, 2) + pow(bean_body_h - edge_h, 2)) / (2 * (bean_body_h - edge_h));
c_shell   = [0.24, 0.24, 0.26];
c_plate   = [0.30, 0.27, 0.25];
c_strap   = [0.16, 0.16, 0.17];
c_copper  = [0.80, 0.52, 0.32];
c_led     = [1.00, 0.55, 0.10];

assert(bean_body_h > edge_h && edge_h > seam_z, "高度关系不对：最高点 > 边沿 > 接缝");

// 正面在半径 r 处的高度
function face_z(r) = bean_body_h - dome_R + sqrt(dome_R * dome_R - r * r);

module bean_profile() intersection() {
    hull() {
        translate([0, 0.4]) square([bean_r, edge_h - face_fillet - 0.4]);
        square([bean_r - 0.4, 0.4]);
        translate([bean_r - face_fillet, edge_h - face_fillet]) circle(face_fillet);
        intersection() {
            translate([0, bean_body_h - dome_R]) circle(dome_R, $fn = 720);
            translate([0, edge_h - face_fillet]) square([bean_r - face_fillet, bean_body_h]);
        }
    }
    square([bean_r, bean_body_h + 1]);
}

module racetrack(l, w, h) hull() for (s = [-1, 1]) translate([0, s * (l - w) / 2, 0]) cylinder(d = w, h = h, $fn = 32);

module bean_body() {
    color(c_shell) difference() {
        rotate_extrude() bean_profile();
        // 前盖接缝
        translate([0, 0, seam_z]) difference() { cylinder(r = bean_r + 1, h = 0.2); cylinder(r = bean_r - 0.15, h = 0.2); }
        // 两个麦克风孔、指示灯
        for (s = [-1, 1]) translate([s * mic_r, 0, face_z(mic_r) - 0.35]) racetrack(mic_l, mic_w, 2);
        translate([led_r, 0, face_z(led_r) - 0.3]) cylinder(d = 0.8, h = 2, $fn = 24);
        // 充电触点的缺口、蜂鸣器孔
        for (s = [-1, 1]) rotate(180 + s * contact_a) translate([bean_r - 0.4, -3.0, 0.3]) cube([2, 6.0, 2.0]);
        rotate(180) translate([bean_r - 1, 0, buzz_z]) rotate([0, 90, 0]) cylinder(d = 0.8, h = 2, $fn = 24);
    }
    color(c_copper) for (s = [-1, 1]) rotate(180 + s * contact_a) translate([bean_r - 0.9, -3.0, 0.3]) cube([0.6, 6.0, 2.0]);
    color(c_led) translate([led_r, 0, face_z(led_r) - 0.3]) cylinder(d = 0.8, h = 0.15, $fn = 24);
    // 侧键
    color(c_shell) rotate(btn_angle) translate([bean_r - 1, 0, btn_z]) rotate([0, 90, 0]) racetrack(btn_len, btn_ax, 1 + btn_out);
}

module bean_plate(gap) color(c_plate) translate([0, 0, -gap - plate_t]) hull() {
    cylinder(d = plate_d - 0.6, h = plate_t);
    translate([0, 0, 0.3]) cylinder(d = plate_d, h = plate_t - 0.6);
}

// 绑带：从鼓身后沿出来，鼓一个环，拐到下面接在磁吸片边上
module bean_strap(gap) {
    zp = -gap - plate_t / 2;
    zm = (1.5 + zp) / 2; rr = (2.3 - zp + 0.6) / 2;   // 环头：半圆
    path = concat([[bean_r - 0.6, 1.5], [bean_r + strap_out * 0.35, 2.2], [bean_r + strap_out * 0.6, 2.3]],
            [for (a = [90 : -30 : -90]) [bean_r + strap_out - rr + rr * cos(a), zm + rr * sin(a)]],
            [[bean_r + strap_out * 0.6, zp - 0.6], [bean_r + strap_out * 0.3, zp - 0.3], [plate_d / 2 - 1, zp]]);
    color(c_strap) rotate([90, 0, 0]) translate([0, 0, -strap_w / 2]) linear_extrude(strap_w)
        for (i = [0 : len(path) - 2]) hull() { translate(path[i]) circle(d = strap_t, $fn = 16); translate(path[i + 1]) circle(d = strap_t, $fn = 16); }
}

module bean(gap = 0, strap = true) {
    bean_body();
    bean_plate(gap);
    if (strap) bean_strap(gap);
}

if (show_bean_model) bean(bean_gap);
