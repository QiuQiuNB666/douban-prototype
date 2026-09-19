#!/usr/bin/env python3
"""
助手验证 —— 同一批数字，固定阈值规则怎么报，助手怎么报；助手的输出过不过程序校验。

对应预赛文档功能点②和「验证状态」表第 4 行：三种情形各真实调用一次。
助手只收结构化数字，输出固定结构；程序校验不过就重生成一次，仍不过就「本周不提醒」。

用法：
    python assistant_check.py selftest      # 不联网：规则基线、校验器、重试与降级
    python assistant_check.py check 输出.json "来源说明"   # 校验别处生成的输出（如 Claude Code 子代理），同一个校验器
    python assistant_check.py run           # 真实调用，需要 pip install anthropic 和 ANTHROPIC_API_KEY
                                            # 走中转且中转不认 beta 参数时：NO_FALLBACKS=1
"""
import json, os, sys, time

MODEL = "claude-opus-5"
WHITELIST = {                      # 助手只能绑定这四项；亲密度组合分不在内
    "share":     ("说话占比：孩子在这段关系里说了几成（%）", 0, 100),
    "monolog_s": ("最长独白：孩子连续说话最长的一段（秒）", 0, 3600),
    "minutes":   ("一起说话的时长：本周合计（分钟）", 0, 10080),
    "days":      ("次数：本周有记录的天数", 0, 7),
}
BANNED = ["霸凌", "欺负", "欺凌", "打压", "孤立", "排挤", "冷暴力", "受害", "施暴", "检测到", "异常", "警告", "危险"]
MAX_LEN = 60                       # 「一句话」和「开口方式」各自的字数上限

SYSTEM = f"""你是一个儿童同伴关系产品里的助手。你读到的只有数字：一个孩子和几位好友每周的说话形状，没有任何谈话内容、姓名或声音，好友只有代号。
家长每周最多收到一条提醒。你来决定：这周要不要提醒；要的话，提哪一个变化、怎么开口、下周看什么算恢复。

四项指标（只能绑定这四项之一）：
{chr(10).join(f"- {k}：{v[0]}" for k, v in WHITELIST.items())}
total_days 是孩子本周总共有记录的天数。孩子按键才录，所以没有记录不等于没有朋友；share 是一段谈话内部的比例，不受按了几次键影响，优先看它。

怎么判断：
- 所有好友一起变，多半是外部的共同原因（考试、假期、生病），不值得提醒。不提醒也是一次决定。
- 和一位好友少了、同期和另一位多了、总次数照常，是孩子的交往在正常流动，不提醒；可以在 trend_note 里给趋势页写一句中性的话。
- 只有某一位好友的数字变了、其他稳定，才值得家长留意。
- 只写变化，不写原因，不猜对方做了什么，不给任何孩子下判断或贴标签。好朋友之间说话不对称本来就常见。
- 语气平常，不吓人。opener 是家长能自然问出口的一个话头，不是盘问。
- 恢复线绑定同一项指标，下周测得出；给一个现实的数，不要求回到原值。
- 上次提醒没恢复时，你可以换开口方式、调低恢复线，或不再提；家长选了「换座位」这类原因，可以把现状当新的基线。
- 这些词不能出现：{"、".join(BANNED)}。

remind 为 false 时，friend、sentence、opener 留空字符串，metric 和 recovery_op 填 "none"，recovery_value 填 0。
sentence 和 opener 各不超过 {MAX_LEN} 个字。reason 写给开发者看，一句话说明你为什么这样决定。"""

SCHEMA = {
    "type": "object", "additionalProperties": False,
    "required": ["remind", "friend", "metric", "sentence", "opener", "recovery_op", "recovery_value", "trend_note", "reason"],
    "properties": {
        "remind": {"type": "boolean"}, "friend": {"type": "string"},
        "metric": {"type": "string", "enum": [*WHITELIST, "none"]},
        "sentence": {"type": "string"}, "opener": {"type": "string"},
        "recovery_op": {"type": "string", "enum": [">=", "<=", "none"]}, "recovery_value": {"type": "number"},
        "trend_note": {"type": "string"}, "reason": {"type": "string"},
    },
}
NO_REMIND = {"remind": False, "friend": "", "metric": "none", "sentence": "", "opener": "",
             "recovery_op": "none", "recovery_value": 0, "trend_note": "", "reason": "校验未通过，降级"}


def wk(total_days, **friends):
    """一周的数字。好友=(share, monolog_s, minutes, days)"""
    return {"total_days": total_days, "friends": {f: dict(zip(WHITELIST, v)) for f, v in friends.items()}}


# 示意数字，非实测。三种情形与预赛文档功能点②的对照表一一对应。
CASES = [
    {"name": "考试周，所有好友的时长一起降了一半", "expect_remind": False, "weeks": [
        wk(5, 好友A=(47, 38, 62, 4), 好友B=(52, 45, 40, 3), 好友C=(44, 30, 36, 3)),
        wk(5, 好友A=(45, 41, 58, 4), 好友B=(50, 40, 44, 3), 好友C=(46, 33, 34, 3)),
        wk(5, 好友A=(46, 36, 60, 4), 好友B=(51, 42, 42, 3), 好友C=(45, 35, 38, 3)),
        wk(3, 好友A=(46, 30, 29, 2), 好友B=(49, 35, 20, 1), 好友C=(47, 28, 17, 1)),
    ]},
    {"name": "和好友 A 的时长降到 0，同期和新好友 C 从 0 涨到 80 分钟，总次数照常", "expect_remind": False, "weeks": [
        wk(5, 好友A=(48, 40, 70, 4), 好友B=(50, 38, 35, 2)),
        wk(5, 好友A=(47, 42, 66, 4), 好友B=(52, 36, 38, 2)),
        wk(5, 好友A=(46, 35, 30, 2), 好友B=(51, 40, 36, 2), 好友C=(45, 30, 40, 2)),
        wk(5, 好友A=(0, 0, 0, 0), 好友B=(50, 39, 37, 2), 好友C=(48, 44, 80, 4)),
    ]},
    {"name": "与好友 A 对话中孩子的占比 46% → 11%，其他好友稳定", "expect_remind": True, "weeks": [
        wk(5, 好友A=(46, 40, 55, 4), 好友B=(51, 42, 40, 3)),
        wk(5, 好友A=(45, 38, 58, 4), 好友B=(50, 40, 42, 3)),
        wk(5, 好友A=(24, 15, 52, 4), 好友B=(52, 41, 38, 3)),
        wk(5, 好友A=(11, 6, 54, 4), 好友B=(49, 43, 41, 3)),
    ]},
]


# 第二轮：情形三发出提醒后的下一周，占比 11% → 14%，还没到恢复线（≥ 20%）。家长选的原因不同，助手怎么办由它决定，没有预设答案。
_W5 = wk(5, 好友A=(14, 8, 50, 4), 好友B=(50, 41, 40, 3))
_LAST = {"friend": "好友A", "metric": "share", "recovery_op": ">=", "recovery_value": 20, "value_when_reminded": 11, "value_now": 14, "recovered": False}
ROUND1 = len(CASES)
CASES += [{"name": f"第二轮：还没到线，家长选「{r}」", "expect_remind": None, "weeks": CASES[2]["weeks"] + [_W5],
           "last_reminder": _LAST, "parent_reason": r} for r in ("换座位了", "闹别扭了", "没什么事", "还不清楚")]


def payload(case):
    return {"weeks_oldest_first": case["weeks"], "guess_gap_points": case.get("guess_gap"),
            "last_reminder": case.get("last_reminder"), "parent_reason": case.get("parent_reason")}


def rule_baseline(case):
    """固定阈值规则：本周比此前各周的均值，时长或次数掉一半以上、或占比掉 15 个百分点以上，就报。每位好友至多一条。"""
    *past, now = case["weeks"]
    alerts = []
    for f, cur in now["friends"].items():
        hist = [w["friends"][f] for w in past if f in w["friends"]]
        if not hist:
            continue
        base = {k: sum(h[k] for h in hist) / len(hist) for k in WHITELIST}
        hit = [k for k in ("minutes", "days") if base[k] > 0 and cur[k] <= base[k] / 2]
        if cur["minutes"] > 0 and base["share"] - cur["share"] >= 15:   # 没说上话的那周，占比没有意义
            hit.append("share")
        if hit:
            alerts.append(f"{f}：{'、'.join(hit)} 下降")
    return alerts


def validate(out, case):
    """程序校验。返回错误列表，空 = 通过。"""
    if not isinstance(out, dict) or not isinstance(out.get("remind"), bool):
        return ["结构不对"]
    text = "".join(str(out.get(k, "")) for k in ("sentence", "opener", "trend_note"))
    errs = [f"含禁用措辞「{w}」" for w in BANNED if w in text]
    if not out["remind"]:
        return errs
    m, f, op, v = out.get("metric"), out.get("friend"), out.get("recovery_op"), out.get("recovery_value")
    now = case["weeks"][-1]["friends"]
    if m not in WHITELIST:
        return errs + [f"指标「{m}」不在白名单"]
    if f not in now:
        return errs + [f"好友「{f}」本周没有数字，恢复线没法对照"]
    lo, hi = WHITELIST[m][1:]
    if op not in (">=", "<=") or not isinstance(v, (int, float)) or not lo <= v <= hi:
        errs.append(f"恢复线 {op} {v} 测不出（{m} 的范围是 {lo}–{hi}）")
    elif (now[f][m] >= v) if op == ">=" else (now[f][m] <= v):
        errs.append(f"恢复线 {op} {v} 本周已经满足（现值 {now[f][m]}），下周对照没有意义")
    for k in ("sentence", "opener"):
        s = out.get(k, "")
        if not s or len(s) > MAX_LEN:
            errs.append(f"{k} 为空或超过 {MAX_LEN} 字")
    return errs


def decide(case, call):
    """生成 → 校验 → 不过重生成一次 → 仍不过就本周不提醒。返回 (输出, 第几次, 每次的错误)。"""
    log = []
    for attempt in (1, 2):
        try:
            out = call(case)
            errs = validate(out, case)
        except Exception as e:                       # 超时、断网、解析失败：算一次失败的生成
            out, errs = None, [f"{type(e).__name__}: {e}"]
        log.append(errs)
        if not errs:
            return out, attempt, log
    return NO_REMIND, 2, log


def claude_caller():
    import anthropic
    client = anthropic.Anthropic(timeout=60.0)       # 超时走降级，与演示时的行为一致
    no_fb = os.environ.get("NO_FALLBACKS")
    api = client.messages if no_fb else client.beta.messages
    extra = {} if no_fb else {"betas": ["server-side-fallback-2026-07-01"], "fallbacks": "default"}

    def call(case):
        try:
            r = api.create(model=MODEL, max_tokens=16000, system=SYSTEM,
                           messages=[{"role": "user", "content": json.dumps(payload(case), ensure_ascii=False)}],
                           output_config={"format": {"type": "json_schema", "schema": SCHEMA}}, **extra)
        except (anthropic.AuthenticationError, anthropic.PermissionDeniedError,
                anthropic.NotFoundError, anthropic.BadRequestError) as e:
            sys.exit(f"配置问题，不算一次失败的生成：{type(e).__name__}: {e.message}")
        if r.stop_reason != "end_turn":              # refusal / max_tokens：不读 content
            raise RuntimeError(f"stop_reason={r.stop_reason}")
        return json.loads(next(b.text for b in r.content if b.type == "text"))
    return call


def describe(out):
    if out["remind"]:
        return (f"提醒｜{out['friend']}·{out['metric']}｜{out['sentence']}｜开口：{out['opener']}"
                f"｜恢复线 {out['recovery_op']} {out['recovery_value']:g}")
    return "本周不提醒" + (f"｜趋势页：{out['trend_note']}" if out["trend_note"] else "")


def check(path, source):
    """校验别处生成的一批输出（如 Claude Code 子代理）：[{case_index, run, out}]。同一个 validate()；每次运行单独判，不含重试。"""
    items = sorted(json.load(open(path, encoding="utf-8")), key=lambda x: (x["case_index"], x["run"]))
    print(f"\n来源：{source}；数字为示意，非实测\n")
    print("| 情形 | 第几次 | 固定阈值规则 | 助手 | 程序校验 | 与设计预期一致 |\n|---|---|---|---|---|---|")
    for it in items:
        c, out = CASES[it["case_index"]], it["out"]
        it.update(case=c["name"], rule=rule_baseline(c), errors=validate(out, c))
        it["as_designed"] = not it["errors"] and c["expect_remind"] in (None, out["remind"])     # None：没有预设答案，只看过不过校验
        print(f"| {c['name']} | {it['run']} | {'；'.join(it['rule']) or '不报'} | {describe(out)} | "
              f"{'通过' if not it['errors'] else '不过：' + '；'.join(it['errors'])} | {'是' if it['as_designed'] else '否'} |")
    n = len(items)
    print(f"\n合计 {n} 次：一次过校验 {sum(not i['errors'] for i in items)}/{n}，与设计预期一致 {sum(i['as_designed'] for i in items)}/{n}")
    dst = os.path.splitext(os.path.abspath(path))[0] + ".checked.json"
    json.dump({"source": source, "at": time.strftime("%Y-%m-%d %H:%M:%S"), "results": items}, open(dst, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    print(f"已存 {dst}")


def run():
    call, rows, raw = claude_caller(), [], []
    for c in CASES:
        t = time.time()
        out, attempt, log = decide(c, call)
        dt = time.time() - t
        said = describe(out)
        ok = "通过" if not log[-1] else "降级：" + "；".join(log[-1])
        rows.append((c["name"], "；".join(rule_baseline(c)) or "不报", said, f"{ok}（第 {attempt} 次）",
                     f"{dt:.1f}s", "是" if c["expect_remind"] in (None, out["remind"]) and not log[-1] else "否"))
        raw.append({"case": c["name"], "rule": rule_baseline(c), "assistant": out, "attempt": attempt, "errors": log, "seconds": round(dt, 1)})
    print(f"\n模型 {MODEL}，{time.strftime('%Y-%m-%d %H:%M')}；数字为示意，非实测\n")
    print("| 情形 | 固定阈值规则 | 助手 | 程序校验 | 耗时 | 与设计预期一致 |\n|---|---|---|---|---|---|")
    for r in rows:
        print("| " + " | ".join(r) + " |")
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assistant_results.json")
    json.dump({"model": MODEL, "at": time.strftime("%Y-%m-%d %H:%M:%S"), "results": raw}, open(path, "w"), ensure_ascii=False, indent=2)
    print(f"\n原始输出已存 {path}")


def selftest():
    n = [len(rule_baseline(c)) for c in CASES[:ROUND1]]
    assert n == [3, 1, 1], f"规则基线应报 3/1/1 条，实际 {n}"
    c3 = CASES[2]
    good = {**NO_REMIND, "remind": True, "friend": "好友A", "metric": "share", "sentence": "这两周她和好友A聊天时说得少了很多。",
            "opener": "周末可以问问她们最近一起玩什么。", "recovery_op": ">=", "recovery_value": 30}
    assert validate(good, c3) == [], validate(good, c3)
    assert validate(NO_REMIND, c3) == []
    bad = {"组合分不在白名单": {"metric": "intimacy"}, "占位指标": {"metric": "none"}, "禁用措辞": {"sentence": "她可能被好友A孤立了。"},
           "恢复线已满足": {"recovery_value": 10}, "恢复线越界": {"recovery_value": 130}, "恢复线没有方向": {"recovery_op": "none"},
           "好友不存在": {"friend": "好友Z"}, "没有开口方式": {"opener": ""}, "一句话太长": {"sentence": "长" * (MAX_LEN + 1)}}
    for why, patch in bad.items():
        assert validate({**good, **patch}, c3), f"该拦没拦：{why}"
    assert validate({**NO_REMIND, "trend_note": "检测到变化"}, c3), "不提醒时趋势页的话也要查禁用措辞"
    assert validate("不是 JSON 对象", c3) and validate({"remind": "yes"}, c3)

    seq = iter([{**good, "metric": "intimacy"}, good])
    out, attempt, log = decide(c3, lambda c: next(seq))
    assert out is good and attempt == 2 and log[0] and not log[1], "第一次不过，第二次过"
    out, attempt, log = decide(c3, lambda c: {**good, "friend": "好友Z"})
    assert out is NO_REMIND and attempt == 2, "两次都不过 → 本周不提醒"
    def boom(c): raise TimeoutError("模拟超时")
    out, _, log = decide(c3, boom)
    assert out is NO_REMIND and "TimeoutError" in log[0][0], "超时 → 本周不提醒"
    assert all(w in SYSTEM for w in BANNED) and "expect" not in json.dumps(payload(c3)), "禁用词进了提示词；预期答案没有泄给模型"
    print("SELFTEST PASSED：规则基线 3/1/1；校验器 2 通过 + 12 拦截；重试、降级、超时各 1")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "check" and len(sys.argv) == 4:
        check(sys.argv[2], sys.argv[3])
    else:
        {"selftest": selftest, "run": run}.get(cmd, lambda: print(__doc__))()
