// 豆伴 · 录音豆托座 v0.1（soundcore Work / D3200）
//
// 做法：托座底板当「衣领」。豆子放进正面浅杯，豆子自带的磁吸片贴到底板背面，
//       隔着底板吸住。不加磁铁、不加金属件。正面完全敞开，不挡双麦、指示灯和双击打标。
// 装法：磁吸片从豆子背面滑开 → 豆子按进浅杯（绑带对准绑带槽，侧键对准缺口）
//       → 绑带从槽里拐到背面，磁吸片贴进背面凹槽。
// 保险绳：豆子朝正面方向只靠磁力固定。拿细绳在豆子自带的绑带上打个双套结，另一头系进挂绳孔，
//       磁力被甩脱时豆子只会吊着，不会整串从绑带槽滑走。打出来先甩十下试试。
// 打印：背面朝下，不用支撑，0.2 mm 层高；底板是一段约 24 mm 的搭桥。整件约 15 分钟，先打一个当试配件。
//
// 单位 mm。角度：从正面看逆时针为正，绑带出口 = 0°。
// 【图纸】= FCC 附录 D 的 CAD 线稿数字；【估】= 从线稿和外观专利图按比例量的，打印前用卡尺核一遍。

/* [松紧] */
// 豆体与杯壁的单边间隙。塞不进调大，晃就调小。FDM 0.2~0.3，树脂 0.1~0.15
fit = 0.23;
// 底板厚度，磁力隔着它传，取层高 0.2 的整数倍。带围边时底板是搭桥，背面会下垂 0.1~0.3，实际磁隙比这个数略大。
// 吸不住：先关掉 skirt 打一个对照件（底板贴平台，厚度是真的），再决定调薄（最薄 0.6）；太软就调厚
floor_t = 0.8;

/* [豆体] */
// 【图纸】外径（宣传页写 23.2）
bean_d = 23.34;
// 【实拍】磁吸片厚度，只决定背面围边多高。实拍量到 2.0~2.5，外观专利画的是 1.5，取偏厚的一边：片薄了只是坐得深一点，片厚了会凸出背面
plate_t = 2.3; // .01
// 【实拍/专利】绑带宽度（实拍 8.0~8.2，专利 8.05，留一点余量）
strap_w = 8.4; // .01
// 【实拍/专利】侧键长度（沿圆周方向），两处来源都是 7.0
btn_w = 7.0; // .01
// 【实拍】侧键角度：正面朝你、绑带朝上时侧键在右手边 = 绑带顺时针 90°，五张实拍照互相印证
btn_angle = -90;
// 【估】按键缺口的底抬高多少。量到侧键下沿后填（下沿离豆底的高度 - 1），缺口下面留一段壁，把小段杯壁和大弧连起来
btn_z0 = 0; // .1
// 【实拍】蜂鸣器孔角度（在两个充电触点中间，绑带对面）
buzz_angle = 180;
// 蜂鸣器出声槽宽度，刻在杯壁内侧、深半个壁厚；0 = 不开
buzz_w = 4; // .1

/* [托座] */
// 杯壁厚
wall = 1.6;
// 杯壁高出底板多少（豆体高约 12，包住下半截）
lip_h = 5; // .1
// 背面围一圈把磁吸片收进去，防蹭掉。关掉则背面是平的、底板直接贴打印平台，磁吸片露在外面
skirt = true;
// 挂绳环
loop = true;
// 挂绳环角度，放在侧键对面：btn_angle 为 -90 填 90，为 90 填 -90
loop_angle = 90;
// 挂绳孔直径（要同时穿挂绳和保险绳）
loop_hole = 4.5;

/* [Hidden] */
slot_fit = 0.75;   // 绑带槽、按键缺口每边多留的量
strap_inset = 3;   // 绑带槽往豆体圆内多切的量，让绑带能拐到背面（2 的时候绑带尾段离底板背面只剩 0.2）
plate_fit = 0.3;   // 背面凹槽比磁吸片多留的深度
loop_rim = 2;      // 挂绳孔外圈的肉厚
loop_t = 3;        // 挂绳环厚度
chamfer = 0.4;     // 杯口倒角，方便按进去
eps = 0.01;
show_seat = true;  // 别的文件 include 本文件复用 seat() 时，把它设成 false
$fn = 120;

cav_r   = bean_d / 2 + fit;
out_r   = cav_r + wall;
skirt_h = skirt ? plate_t + plate_fit : 0;
z_cav   = skirt_h + floor_t;   // 底板上表面，豆子坐在这
total_h = z_cav + lip_h;

// 两个角度之间的夹角，0~180
function adiff(a, b) = abs(((a - b) % 360 + 540) % 360 - 180);
strap_half = asin((strap_w / 2 + slot_fit) / cav_r);
btn_half   = asin((btn_w / 2 + slot_fit) / cav_r);

assert(fit >= 0 && fit < 1, "fit 应在 0~1 mm");
assert(floor_t >= 0.4, "底板薄于 0.4 mm 打不出来");
assert(wall >= 0.8, "杯壁至少 0.8 mm");
assert(btn_z0 >= 0 && btn_z0 < lip_h, "btn_z0 应在 0 和 lip_h 之间");
assert(adiff(btn_angle, 0) > strap_half + btn_half + 10, "按键缺口和绑带槽挨太近，中间的杯壁留不住");
assert(!loop || adiff(loop_angle, 0) > strap_half + 20, "挂绳环撞上绑带槽了");
assert(!loop || adiff(loop_angle, btn_angle) > btn_half + 20, "挂绳环撞上按键缺口了：把 loop_angle 改到侧键对面");

// 沿 angle 方向的直槽：从半径 r0 一直切到托座外面
module slot(angle, w, r0, z0, z1)
    rotate(angle) translate([r0, -w / 2, z0]) cube([out_r + 10 - r0, w, z1 - z0]);

module lanyard() {
    lx = out_r + loop_hole / 2 + 0.8;
    rotate(loop_angle) difference() {
        hull() {
            translate([lx, 0, 0]) cylinder(r = loop_hole / 2 + loop_rim, h = loop_t);
            translate([cav_r, 0, 0]) cylinder(r = loop_hole / 2 + loop_rim, h = loop_t);
        }
        translate([lx, 0, -eps]) cylinder(d = loop_hole, h = loop_t + 2 * eps);
    }
}

module seat() difference() {
    union() {
        cylinder(r = out_r, h = total_h);
        if (loop) lanyard();
    }
    // 正面浅杯
    translate([0, 0, z_cav]) cylinder(r = cav_r, h = lip_h + eps);
    // 杯口倒角
    translate([0, 0, total_h - chamfer]) cylinder(r1 = cav_r, r2 = cav_r + chamfer + eps, h = chamfer + eps);
    // 背面磁吸片凹槽。直径跟浅杯一样，不依赖磁吸片的真实直径，磁铁会自己对中
    if (skirt) translate([0, 0, -eps]) cylinder(r = cav_r, h = skirt_h + eps);
    // 绑带槽：整高贯穿，底板上也切一段，绑带从这里拐到背面
    slot(0, strap_w + 2 * slot_fit, cav_r - strap_inset, -eps, total_h + eps);
    // 按键缺口：顶部必须敞开（侧键凸出量大于 fit，封顶豆子就按不进去），只能用 btn_z0 抬底
    slot(btn_angle, btn_w + 2 * slot_fit, 0, z_cav + btn_z0, total_h + eps);
    // 蜂鸣器出声槽：从杯底通到杯口。从圆心起切，免得在弧形内壁上留薄片
    if (buzz_w > 0) rotate(buzz_angle) translate([0, -buzz_w / 2, z_cav]) cube([cav_r + wall / 2, buzz_w, lip_h + eps]);
}

if (show_seat) seat();
