// 不豆 · 怪兽外壳 v0.1（soundcore Work / D3200）
//
// 照「不豆 BUDOU」概念图建的：圆滚滚的怪兽，张着的大嘴就是录音豆的位置。
// 装法：豆子带着磁吸片、正面朝外，绑带朝上，从嘴里直着按进去。绑带对折收进嘴巴上沿的槽里。
// 固定：硬料（PLA）靠嘴巴内壁夹住豆子，松紧调 grip_fit；软料（TPU）可以再紧一点。
// 侧键：豆子的侧键被包在嘴里，从怪兽身侧的按键孔伸手指进去按。
// 打印：站着打（脚底是平的），要开树状支撑（鬃毛、拳头、眉毛下面都是悬空的）。
//
// 单位 mm。正面朝 -Y，Z 朝上。豆子的尺寸和 托座.scad 共用一份。

include <托座.scad>
show_seat = false;
loop = false;
$fn = 72;

/* [看什么] */
// 把豆子（贴了嘴巴贴纸的样子）也画出来。导出 STL 前关掉
show_bean = true;

/* [豆子怎么装] */
// 【图纸】豆子含磁吸片的总高
bean_h = 13.45; // .01
// 豆子和嘴巴内壁的单边间隙，硬料靠它夹住豆子。掉就调小，塞不进调大
grip_fit = 0.15; // .01
// 豆子正面比嘴唇缩进去多少
recess = 1; // .1
// 【实拍】侧键在哪一侧：1 = 从正面看的右边（实拍确认），-1 = 左边，0 = 不开按键孔
btn_side = 1;
// 按键孔直径（Φ12 只够指尖，Φ14 能用指腹）
btn_hole = 14; // .1
// 【实拍】侧键中心离嘴底多远 = 磁吸片 2.3 + 侧键高 4.2 + 嘴底余量 0.3
btn_depth = 6.8; // .1

/* [怪兽] */
// 身体宽
body_w = 56;
// 身体高
body_h = 58;
// 身体前后厚
body_d = 46;
// 鬃毛瓣数
petals = 11;
// 嘴巴中心比身体中心低多少
mouth_drop = 7;
// 头顶那一瓣上的挂绳孔直径，0 = 不开
hang_hole = 4; // .1

/* [Hidden] */
lift = 3;                         // 身体离地，靠两只脚站
lip_w = 4.4;                      // 嘴唇宽
lip_r = 2.2;                      // 嘴唇圆边半径
c_body  = [0.97, 0.52, 0.30];
c_mane  = [0.93, 0.27, 0.22];
c_mane2 = [0.97, 0.40, 0.26];
c_white = [0.98, 0.97, 0.94];
c_black = [0.08, 0.08, 0.09];
c_pink  = [0.98, 0.62, 0.62];
c_mouth = [0.60, 0.10, 0.14];

Zc = lift + body_h / 2;           // 身体中心高度
Zm = Zc - mouth_drop;             // 嘴巴中心高度
mouth_r = bean_d / 2 + grip_fit;  // 嘴巴内半径
lip_R = mouth_r + lip_w;          // 嘴唇外半径
y_lip = -(body_d / 2) - 1.5;      // 嘴唇圆边的中心面；嘴巴入口就在这
y_face = y_lip + recess;          // 豆子正面的位置
y_back = y_face + bean_h + 0.3;   // 嘴巴底

assert(btn_side == 1 || btn_side == -1 || btn_side == 0, "btn_side 只能是 1、-1、0");
assert(y_back < body_d / 2 - 6, "身体太薄，嘴巴快捅穿后背了：调大 body_d");

module ell(r) scale(r) sphere(1);

// 身体正面在 (x, 相对身体中心的 z) 处的 y
function ysurf(x, z) = -(body_d / 2) * sqrt(max(0, 1 - pow(x / (body_w / 2), 2) - pow(z / (body_h / 2), 2)));

module body() translate([0, 0, Zc]) ell([body_w / 2, body_d / 2, body_h / 2]);

// 一圈鬃毛：从 4 点钟绕过头顶到 8 点钟，头顶的长、两侧的短
module mane() {
    for (i = [0 : petals - 1]) {
        t = -25 + i * 230 / (petals - 1);
        r = 1 / sqrt(pow(cos(t) / (body_w / 2), 2) + pow(sin(t) / (body_h / 2), 2));
        translate([r * cos(t), 3, Zc + r * sin(t)]) rotate([0, 90 - t, 0]) ell([6.8, 4.8, 9 + 5 * pow(max(0, sin(t)), 2)]);
    }
    for (i = [0 : petals - 2]) {
        t = -25 + (i + 0.5) * 230 / (petals - 1);
        r = 1 / sqrt(pow(cos(t) / (body_w / 2), 2) + pow(sin(t) / (body_h / 2), 2));
        color(c_mane2) translate([(r - 2) * cos(t), -1.5, Zc + (r - 2) * sin(t)]) rotate([0, 90 - t, 0]) ell([5.6, 4.2, 7 + 3 * pow(max(0, sin(t)), 2)]);
    }
    // 后背中线上的三瓣
    for (p = [68, 38, 8])
        translate([0, body_d / 2 * cos(p), Zc + body_h / 2 * sin(p)]) rotate([-(90 - p), 0, 0]) ell([6, 4.4, 9]);
}

module face() {
    for (s = [-1, 1]) {
        ey = ysurf(10.5, 11);
        color(c_white) translate([s * 10.5, ey + 0.5, Zc + 11]) rotate([0, -s * 14, 0]) ell([7.0, 3.4, 8.4]);
        color(c_black) translate([s * 8.4, ey - 2.5, Zc + 9.0]) ell([3.6, 1.2, 4.2]);
        color(c_white) translate([s * 9.6, ey - 3.4, Zc + 10.8]) ell([1.1, 0.6, 1.1]);
        // 眉毛：内低外高，压住眼睛上沿
        color(c_mane) hull() {
            translate([s * 3.2, ysurf(3.2, 14.5) - 2.2, Zc + 14.5]) sphere(3);
            translate([s * 14.5, ysurf(14.5, 21) - 2.6, Zc + 21]) sphere(3);
        }
        // 腮红
        color(c_pink) translate([s * 20.5, ysurf(20.5, 4) + 0.2, Zc + 4]) rotate([0, 0, s * 40]) ell([4.2, 1.0, 3.0]);
        // 下唇两侧的小尖牙
        color(c_white) translate([s * 7.6, y_lip - lip_r + 0.6, Zm - 11.4]) ell([2.2, 1.8, 2.8]);
    }
    color(c_mane) translate([0, ysurf(0, 9) - 0.6, Zc + 9]) sphere(1.7);
}

// 嘴：一圈鼓出来的嘴唇
module muzzle() translate([0, 0, Zm]) rotate([90, 0, 0]) {
    translate([0, 0, 12]) cylinder(r1 = lip_R + 3, r2 = lip_R, h = -y_lip - 12);
    translate([0, 0, -y_lip]) rotate_extrude() translate([lip_R - lip_r, 0]) circle(lip_r);
}

module limbs() for (s = [-1, 1]) {
    hull() {
        translate([s * 18.5, -21, Zm - 13]) ell([6.2, 6, 6.6]);
        translate([s * 20, -8, Zm - 14]) sphere(4);
    }
    translate([s * 12.5, -4, 3.5]) ell([8.5, 11, 6]);
}

// 要挖掉的：嘴巴、绑带槽、侧键槽和按键孔、挂绳孔、脚底以下
module mouth_cut() translate([0, y_back, Zm]) rotate([90, 0, 0]) cylinder(r = mouth_r, h = y_back + 40);

module cuts() {
    w_s = strap_w + 2 * slot_fit;
    w_b = btn_w + 2 * slot_fit;
    // 绑带槽：嘴巴正上方，绑带对折躺在里面
    translate([-w_s / 2, -40, Zm]) cube([w_s, y_back + 40, mouth_r + 3.5]);
    if (btn_side != 0) {
        // 侧键凸出豆体，得有一道槽让它顺着滑进去
        translate([btn_side > 0 ? 0 : -(mouth_r + 3.2), -40, Zm - w_b / 2]) cube([mouth_r + 3.2, y_back + 40, w_b]);
        translate([0, y_back - btn_depth, Zm]) rotate([0, btn_side * 90, 0]) cylinder(d = btn_hole, h = body_w);
    }
    if (hang_hole > 0) translate([0, 20, Zc + body_h / 2 + 7]) rotate([90, 0, 0]) cylinder(d = hang_hole, h = 40);
    translate([-100, -100, -50]) cube([200, 200, 50]);
}

module shell() difference() {
    union() {
        color(c_body) { body(); muzzle(); limbs(); }
        color(c_mane) mane();
        face();
    }
    color(c_mouth) mouth_cut();
    color(c_body) cuts();
}

// 只是画给人看的豆子：贴纸上有上排牙和舌头，两个麦克风孔和指示灯的位置必须留空
module bean_vis() translate([0, y_face, Zm]) {
    color(c_mouth) rotate([-90, 0, 0]) cylinder(d = bean_d, h = bean_h);
    for (x = [-7.2, -2.4, 2.4, 7.2]) {
        top = sqrt(pow(bean_d / 2 - 1.2, 2) - x * x) - 1.6;
        color(c_white) hull() for (z = [top, top - 3.6 + abs(x) * 0.2]) translate([x, 0, z]) ell([2.1, 0.5, 1.9]);
    }
    color(c_pink) translate([0, 0, -6.3]) ell([6.5, 0.5, 3.8]);
    for (z = [-10, 10]) color(c_black) hull() for (x = [-1.6, 1.6]) translate([x, -0.4, z]) sphere(0.65);
    color(c_black) translate([0, -0.5, 3.4]) sphere(0.5);
}

shell();
if (show_bean) bean_vis();
