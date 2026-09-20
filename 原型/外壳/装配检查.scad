// 装配干涉检查：把 录音豆.scad 的豆子放进三个外壳，求「外壳 ∩ 豆子」。交集是空的 = 不相撞。
// 用法：openscad -D 'which="seat"' -o 交集.stl 装配检查.scad    （which = seat / bowtie / monster / 某个 _show）
//       报「top level object is empty」就是通过；导出了东西，就用 meshcheck 看撞在哪、撞了多少。
// 蝴蝶结和怪兽读的是已导出的 STL，改过参数要先重新导出它们。

include <录音豆.scad>
show_bean_model = false;

which = "seat";

// 豆子在托座里：坐在底板上，磁吸片隔着底板吸在背面
module bean_in_seat() translate([0, 0, z_cav]) bean(gap = floor_t);
// 豆子在怪兽嘴里：正面朝 -Y，绑带朝上，磁吸片吸在豆子背面；绑带是对折塞进槽里的，不参与检查。
// 下面三个数要和 不豆.scad 一致（那边是 Hidden 里算出来的）
monster_y_face = -(46 / 2) - 1.5 + 1;
monster_Zm = 3 + 58 / 2 - 7;
module bean_in_monster() translate([0, monster_y_face + bean_body_h, monster_Zm]) rotate([90, 0, 0]) rotate(90) bean(gap = 0, strap = false);

if (which == "seat")    intersection() { seat(); bean_in_seat(); }
if (which == "bowtie")  intersection() { import("蝴蝶结.stl"); rotate(-90) bean_in_seat(); }
if (which == "monster") intersection() { import("不豆.stl"); bean_in_monster(); }
if (which == "seat_show")    { seat(); bean_in_seat(); }
if (which == "bowtie_show")  { color("#c8102e") import("蝴蝶结.stl"); rotate(-90) bean_in_seat(); }
if (which == "monster_show") { color([0.97, 0.52, 0.30]) import("不豆.stl"); bean_in_monster(); }
