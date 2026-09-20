// 录音豆蝴蝶结 v0.1 —— 大红领结，中间的「结」就是录音豆托座
//
// 做法：正中是 托座.scad 的 seat()（原样复用，转 -90°：绑带槽朝下、侧键缺口朝左、蜂鸣器槽朝上）。
//       左右两片翅膀从背面 z=0 平着长起来：靠结的一圈压到底板高度（手指从左边够得着侧键），
//       往外鼓到 6 mm，上面三道从结放射出去的褶（沟）。录音豆正面完全露着，麦克风和指示灯不挡。
// 松紧带（10 mm 宽）：外槽从背面穿到正面 → 压过桥 → 内槽穿回背面 → 横着压过结的背面
//       （兜住磁吸片，掉不出凹槽）→ 另一侧镜像。颈后务必用「一拉就开」的安全扣或魔术贴，不要打死结。
// 加强箍：托座正下方是贯穿的绑带槽、正上方杯壁被蜂鸣器槽削薄，两边一掰就从正中裂。
//       所以在结的上半圈外面箍了一段（只在两片翅膀之间，不进翅膀、不进绑带通道、不高过翅膀）。
// 打印：背面朝下，不用支撑，0.2 mm 层高，4 圈壁（翅膀根部只有 2.7 厚，靠壁圈扛掰）。
//       天天戴建议用 PETG 或 PLA+，比普通 PLA 耐掰。
//
// 单位 mm。从正面看：+x 右、+y 上、+z 朝外（正面）。

include <托座.scad>

/* [Hidden] */
show_seat = false;   // include 是文本展开，同名变量以最后一次赋值为准
loop = false;        // 蝴蝶结不要挂绳环

/* [整体尺寸] */
// 总宽（100~115）
bow_w = 110;
// 翅膀外端高（45~55）
wing_h = 52;
// 腰高：翅膀在杯壁外表面（x = out_r）处的高度（22~28）。调大时下沿会逼近绑带通道，有 assert 把关
waist_h = 25;
// 外端圆角半径（≥ 2，越大越圆）
corner_r = 14;
// 外端竖边中间比圆角再鼓出多少
end_bulge = 2;

/* [厚度与鼓包] */
// 翅膀最厚（≤ 6）
wing_t = 6;
// 低矮区：离杯壁外表面这么远以内，翅膀上表面压到底板高度 z_cav，给按侧键的手指让路（≥ 14 + 一格网格的余量）
low_gap = 15;
// 从低矮区鼓到最厚的过渡长度
ramp_len = 12;
// 边缘鼓包宽度：从轮廓往里这么远才鼓到最厚，越大越像枕头
puff_d = 10;
// 侧面竖直段的顶（从这往上开始收圆）。低矮区的顶面棱边因此是一圈约 1.5 mm 的斜倒角
edge_land = 1.2;
// 背面一圈 45° 倒角，贴脖子那面不硌，也消掉首层的「象脚」飞边
back_chamfer = 0.5;

/* [褶] */
// 每片翅膀的褶：从结心放射出去的角度（相对翅膀中线）
pleat_angles = [-17, 0, 17];
// 褶（沟）深（≥ 1）。低矮区里不刻褶，不削弱翅膀根
pleat_d = 2.0;
// 褶的半宽：起点处
pleat_w0 = 1.8;
// 褶的半宽：外端处
pleat_w1 = 3.2;

/* [松紧带槽] */
// 槽长（竖直方向），10 mm 松紧带留 2 mm 余量
band_l = 12;
// 槽宽
band_w = 2.5;
// 内槽中心离杯壁外表面
slot1_gap = 5;
// 两槽之间的桥宽（倒角吃掉两边之后仍 ≥ 4）
bridge = 5;
// 槽口正反两面的倒角，松紧带拐弯处不被棱磨断
slot_chamfer = 0.5;
// 槽四角圆角（直边 = band_l - 2×它，要 ≥ 松紧带宽）
slot_corner = 1;

/* [结的加强箍] */
hoop = true;
// 箍的径向宽度
hoop_w = 3.5;
// 箍高（≤ 6，和翅膀最厚处齐平）
hoop_h = 6;

/* [绑带通道] */
// 正下方这个半角的扇区内……
clear_half = 38;
// ……离圆心这么远以内不留任何翅膀材料
clear_r = 31;

/* [Hidden] */
overlap = 0.6;     // 翅膀、箍咬进杯壁的深度（H4：不许超过 0.6，又要 ≥ 0.5）
root_x = 5;        // 翅膀轮廓的内端，埋在杯子里，反正会被切掉
puff_n = 12;       // 鼓包放样的层数
grid = 0.5;        // 顶面高度场的网格
show_bow = true;   // 别的文件 include 本文件时设成 false
show_bean = false;  // 渲染预览图时把豆子也画出来（-D show_bean=true）；不进 STL

low_r   = out_r + low_gap;
slot1_x = out_r + slot1_gap;
slot2_x = slot1_x + band_w + bridge;

// 翅膀上沿：过腰点 A、和外端圆角相切的直线
A = [out_r, waist_h / 2];
C = [bow_w / 2 - end_bulge - corner_r, wing_h / 2 - corner_r];
edge_a = atan2(C.y - A.y, C.x - A.x) + asin(corner_r / norm(C - A));
edge_u = [cos(edge_a), sin(edge_a)];
function edge_y(x) = A.y + (x - out_r) * tan(edge_a);
root_y = edge_y(root_x);
// 上沿和杯壁外圆的交点 P（下沿镜像），它离绑带通道有多远
P_t = A * edge_u - sqrt(pow(A * edge_u, 2) - (A * A - out_r * out_r));
P = A - P_t * edge_u;
// 外端鼓弧：过 (bow_w/2, 0)，和两个圆角内切
bulge_q = (end_bulge * end_bulge + C.y * C.y) / (2 * end_bulge);
bulge_r = bulge_q + corner_r;
bulge_y = bulge_r * C.y / bulge_q;
// 加强箍满高的半宽：45° 斜坡正好在翅膀根（P）处落到 z_cav，翅膀范围内不高过 z_cav
hoop_half = P.x - (hoop_h - z_cav);

assert(skirt && z_cav >= 2, "托座的 skirt 要开着：低矮区的厚度就是 z_cav，关掉就只剩一张薄片");
assert(bow_w >= 100 && bow_w <= 115, "总宽应在 100~115");
assert(wing_h >= 45 && wing_h <= 55, "外端高应在 45~55");
assert(waist_h >= 22 && waist_h <= 28, "腰高应在 22~28");
assert(bow_w <= 180 && wing_h <= 180, "放不进 180×180 平台");
assert(corner_r >= 2 && corner_r <= wing_h / 2 - 1, "外端圆角半径不合适");
assert(end_bulge > 0, "end_bulge 要大于 0");
assert(wing_t <= 6 && wing_t >= z_cav + 1, "翅膀最厚应在 z_cav+1 ~ 6");
assert(low_gap >= 14 + 1.5 * grid, "低矮区至少离杯壁 14，再留一格半网格的余量（顶面是网格插值的）");
assert(pleat_d >= 1 && wing_t - pleat_d >= 1.2, "褶深 ≥ 1，褶底剩肉 ≥ 1.2");
assert(bridge - 2 * slot_chamfer >= 4, "桥去掉倒角后不足 4");
assert(slot1_x - band_w / 2 - slot_chamfer - out_r >= 3, "内槽离杯壁不足 3");
assert(edge_y(slot1_x - band_w / 2) - band_l / 2 >= 3, "槽离翅膀上下沿不足 3");
assert(norm([slot2_x + band_w / 2, band_l / 2]) <= low_r, "外槽要落在低矮区里：调大 low_gap 或调小 bridge");
assert(slot_corner < band_w / 2 && band_l - 2 * slot_corner >= 10, "槽角圆角太大，10 mm 松紧带穿不平");
assert(atan2(P.y, P.x) <= 90 - clear_half - 3, "翅膀下沿探进绑带通道了：waist_h 调小");
assert(overlap >= 0.5 && overlap <= 0.6, "overlap 应在 0.5~0.6");
assert(!hoop || (hoop_h <= 6 && hoop_h > z_cav && hoop_half >= 3), "加强箍：高度在 z_cav~6 之间，满高段至少半宽 3");

// 右翅膀的平面轮廓（凸的，方便放样）。内端埋在杯子里
module wing2d() hull() {
    translate([root_x, -root_y]) square([0.01, 2 * root_y]);
    for (s = [-1, 1]) translate([C.x, s * C.y]) circle(r = corner_r);
    intersection() {
        translate([bow_w / 2 - bulge_r, 0]) circle(r = bulge_r, $fn = 360);
        translate([C.x, -bulge_y]) square([bow_w, 2 * bulge_y]);
    }
}

// 边缘剖面 [内缩量, 高度]：背面倒角 → 竖直段 → 抛物线鼓包
prof = concat([[back_chamfer, 0], [0, back_chamfer]],
    [for (i = [0 : puff_n]) let(u = i / puff_n)
        [puff_d * u, edge_land + (wing_t + 0.05 - edge_land) * (1 - pow(1 - u, 2))]]);

module slab(p) translate([0, 0, p[1]]) linear_extrude(eps) offset(delta = -p[0]) wing2d();
module pillow() for (i = [0 : len(prof) - 2]) hull() { slab(prof[i]); slab(prof[i + 1]); }

// 顶面高度场：低矮区 z_cav → 平滑鼓到 wing_t，再减去放射状的褶
function sstep(t) = let(c = min(max(t, 0), 1)) c * c * (3 - 2 * c);
function top_z(x, y) = let(
    r = norm([x, y]), a = atan2(y, x), up = sstep((r - low_r) / ramp_len),
    w = pleat_w0 + (pleat_w1 - pleat_w0) * sstep((r - low_r) / (bow_w / 2 - low_r)),
    cut = max([for (pa = pleat_angles) let(dl = r * abs(sin(a - pa)))
        dl < w ? 0.5 * (1 + cos(180 * dl / w)) : 0]))
    z_cav + (wing_t - z_cav - pleat_d * cut) * up;

cx1 = bow_w / 2 + 1;
cy1 = wing_h / 2 + 1;
nx = ceil(cx1 / grid);
ny = ceil(2 * cy1 / grid);
function gi(i, j) = i * (ny + 1) + j;
module ceiling() {
    n = (nx + 1) * (ny + 1);
    pts = concat(
        [for (i = [0 : nx], j = [0 : ny]) let(x = cx1 * i / nx, y = -cy1 + 2 * cy1 * j / ny) [x, y, top_z(x, y)]],
        [[0, -cy1, -1], [cx1, -cy1, -1], [cx1, cy1, -1], [0, cy1, -1]]);
    faces = concat(
        [for (i = [0 : nx - 1], j = [0 : ny - 1], k = [0, 1])
            k == 0 ? [gi(i, j), gi(i, j + 1), gi(i + 1, j + 1)] : [gi(i, j), gi(i + 1, j + 1), gi(i + 1, j)]],
        [[n, n + 1, n + 2, n + 3]],
        [concat([n], [for (i = [0 : nx]) gi(i, 0)], [n + 1])],
        [concat([n + 2], [for (i = [nx : -1 : 0]) gi(i, ny)], [n + 3])],
        [concat([n + 3], [for (j = [ny : -1 : 0]) gi(0, j)], [n])],
        [concat([n + 1], [for (j = [0 : ny]) gi(nx, j)], [n + 2])]);
    polyhedron(pts, faces, convexity = 4);
}

module wing_body() intersection() { pillow(); ceiling(); }

// 松紧带槽：竖直通槽，正反两面槽口都倒角
module slot2d(grow = 0) offset(r = slot_corner + grow)
    square([band_w - 2 * slot_corner, band_l - 2 * slot_corner], center = true);
module band_slot(x) translate([x, 0, 0]) {
    translate([0, 0, -eps]) linear_extrude(wing_t + 1) slot2d();
    hull() {
        translate([0, 0, z_cav - slot_chamfer]) linear_extrude(eps) slot2d();
        translate([0, 0, z_cav]) linear_extrude(wing_t) slot2d(slot_chamfer);
    }
    hull() {
        translate([0, 0, -eps]) linear_extrude(eps) slot2d(slot_chamfer);
        translate([0, 0, slot_chamfer]) linear_extrude(eps) slot2d();
    }
}

// 结的加强箍：上半圈。矮的一圈（比 z_cav 低一层）顺手把翅膀上沿和杯壁之间的夹角填掉；
// 高的一段只在两片翅膀之间，两头 45° 斜下去
module hoop_ring(h, ct) rotate_extrude(angle = 180) polygon([
    [out_r - overlap, 0], [out_r + hoop_w - back_chamfer, 0], [out_r + hoop_w, back_chamfer],
    [out_r + hoop_w, h - ct], [out_r + hoop_w - ct, h], [out_r - overlap, h]]);
module knot_hoop() {
    hoop_ring(z_cav - 0.2, 1);
    intersection() {
        hoop_ring(hoop_h, 1);
        rotate([90, 0, 0]) translate([0, 0, -(out_r + hoop_w + 1)]) linear_extrude(out_r + hoop_w + 1)
            polygon([[-(hoop_half + hoop_h + 1), -1], [hoop_half + hoop_h + 1, -1],
                     [hoop_half - 1, hoop_h + 1], [-(hoop_half - 1), hoop_h + 1]]);
    }
}

// 绑带通道：正下方扇区，整高清空
module strap_clear() translate([0, 0, -1]) linear_extrude(total_h + 2)
    polygon(concat([[0, 0]], [for (a = [-90 - clear_half : 5 : -90 + clear_half]) clear_r / cos(2.5) * [cos(a), sin(a)]]));

module bowtie() {
    rotate([0, 0, -90]) seat();
    difference() {
        union() {
            for (m = [0, 1]) mirror([m, 0, 0]) wing_body();
            if (hoop) knot_hoop();
        }
        // 翅膀只许咬进杯壁 overlap 这么深：不填侧键缺口，不探进浅杯和背面凹槽
        translate([0, 0, -1]) cylinder(r = out_r - overlap, h = total_h + 2);
        strap_clear();
        for (m = [0, 1]) mirror([m, 0, 0]) { band_slot(slot1_x); band_slot(slot2_x); }
    }
}

if (show_bow) color("#c8102e") bowtie();
if (show_bean) color("#1a1a1a") translate([0, 0, z_cav]) { cylinder(d = bean_d, h = 11); translate([0, 0, 11]) scale([1, 1, 0.07]) sphere(d = bean_d); }
