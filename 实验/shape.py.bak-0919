#!/usr/bin/env python3
"""
形状实验 —— 别在领口的录音豆，只靠近场/远场的声学差异，分得开「我」和「对方」吗？

不做声纹、不转写。A 佩戴，嘴离豆子约 20cm；B 在对面约 1m。
近场：响、干、音节间隙清楚；远场：弱、带混响、间隙被填平。
所以每帧只看两个数：能量 dB、500ms 内的包络调制深度。

用法：
    python shape.py selftest
    python shape.py analyze 豆子.m4a [--phone 手机.m4a] [--turn 20] [--rounds 4] [--guard 2.5] [--lead 1.0]
                            [--vad 10] [--clap 秒] [--phone-clap 秒]
"""
import argparse, os, subprocess, sys, tempfile, time, wave
import numpy as np
from numpy.lib.stride_tricks import sliding_window_view as windows

SR = 16000
FRAME, HOP = 320, 160          # 20ms 帧，10ms 跳
MOD_HALF = 25                  # 调制深度窗半宽 25 帧 = 以本帧为中心 500ms
CALIB_S = 3.0                  # 每人只示教开口前 3 秒：模仿产品上手时的一次性校准
MEDIAN_S = 0.3
MIN_SEG_S = 1.0                # 短于 1 秒的不算一次发言（参照 Jayagopi 2009）
CLAP_SEARCH_S = 20.0
# 「响」不是拍手的特征，而且响度过不了有损压缩：同一段拍手，wav 里比中位数高 27dB，
# 转成 44.1k AAC 只剩 6dB（编码噪声把静音段抬起来了）。所以只看形状「起落都快」。
# 实测：拍手脉冲 wav 51dB / aac 30dB / opus 24k 22dB / mp3 64k 19dB；说话起音一律 ≤5dB。
CLAP_RISE_DB = 12.0            # 卡在两者中间：比最差的有损拍手低 7dB，比最强的说话起音高 7dB
CLAP_WARN_DB = 15.0            # 12–15 这一档说不准是不是拍手，提示人工核对
CLAP_DOMINANT_DB = 12.0        # 第二个瞬态若没低这么多（关门、放杯子），就分不清哪个是拍手，不猜
SILENT_DB = -90.0              # 降噪门控出来的数字静音不参与底噪估计，否则阈值被拉到 -90dB，底噪全成「有声」
MIN_AUDIO_S = 5.0
MIN_SIDE_FRAMES = 100          # 每人至少 1 秒有声帧，否则 d′ 是几帧噪声算出来的
SHIFT_MAX_S, SHIFT_STEP_S = 10.0, 0.5

# 结论阈值：工程判断，不是文献值。宁可说「勉强」，也别把噪声说成信号。
ACC_YES, ERR_YES_PP = 0.90, 5.0
UNSURE_YES = 0.20              # 「不确定」不进准确率分母；不设上限的话，弃权九成也能拿高准确率
ACC_NO, DPRIME_NO = 0.75, 1.0
# 真值整体平移一下，准确率涨这么多、且平移后确实对得上（≥ACC_NO）→ 真值本身不可信，别拿它下结论。
# 要求「平移后对得上」是防止自欺：本来就分不开的录音，40 个平移里总有一个能蒙高几个点。
MISALIGN_PP, MISALIGN_MIN_S = 10.0, 1.0
BETTER_PP = 10.0

YES, NO, MAYBE = "佩戴位置能分出我/对方", "分不开", "勉强，需要更多数据"
PARTS = ["负对照 B 大声", "负对照 A 摘豆", "负对照 同时说", "自然段"]


# ---------- ffmpeg 音频 I/O ----------

def decode(path, sr=SR, keep_channels=False):
    """任意音频 → float32 @ sr。keep_channels=True 时保留双声道，返回 (样本数, 声道数)。"""
    ch = 1
    if keep_channels:
        p = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
                            "stream=channels", "-of", "csv=p=0", path], capture_output=True, text=True)
        ch = 2 if p.stdout.strip().isdigit() and int(p.stdout.strip()) >= 2 else 1
    p = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", str(ch), "-ar", str(sr), "-"],
        capture_output=True)
    if p.returncode != 0:
        raise RuntimeError(f"ffmpeg 解码失败: {p.stderr.decode()[:200]}")
    x = np.frombuffer(p.stdout, dtype=np.float32).copy()
    return x.reshape(-1, ch) if keep_channels else x


def encode(x, path, sr=SR):
    """只给自检用：走 wave 而不是 ffmpeg，管道传 27MB 要 4 秒，10 秒预算花不起。"""
    with wave.open(path, "wb") as w:
        w.setnchannels(1 if x.ndim == 1 else x.shape[1])
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())


# ---------- 特征 ----------

def frame_db(x, frame=FRAME, hop=HOP):
    c = np.concatenate([[0.0], np.cumsum(x.astype(np.float64) ** 2)])
    s = np.arange(1 + (len(x) - frame) // hop) * hop
    return 10 * np.log10(np.maximum(c[s + frame] - c[s], 0) / frame + 1e-10)


def _impulse(db):
    """每帧的「脉冲程度」= min(10ms 上升, 50ms 衰减)。只有起落都快的才是拍手。"""
    if len(db) < 7:
        return np.full(len(db), -99.0)
    return np.minimum(np.r_[-99.0, np.diff(db)], db - np.r_[db[5:], np.repeat(db[-1], 5)])


def _peaks(db, gap=50, k=4):
    """最像拍手的几帧：起落都快。彼此至少隔 0.5s（一次拍手会占好几帧）。"""
    s = _impulse(db)
    out = []
    for i in np.argsort(-s):
        if s[i] < CLAP_RISE_DB or len(out) == k:
            break
        if all(abs(i - j) >= gap for j in out):
            out.append(int(i))
    return out, s


def find_clap(x):
    c, s = _peaks(frame_db(x[:int(CLAP_SEARCH_S * SR)], HOP, HOP))
    fmt = lambda i, arr: f"{i * HOP / SR:.2f}s（{arr[i]:.0f}dB）"
    if not c:
        g, gs = _peaks(frame_db(x, HOP, HOP))                # 前 20 秒没有，整段里找个建议给人
        sys.exit(f"前 {CLAP_SEARCH_S:.0f} 秒里没有拍手那样的瞬态（要求 10ms 内起、50ms 内落，≥{CLAP_RISE_DB:.0f}dB）。\n"
                 + (f"整段里最像的在 {fmt(g[0], gs)}。\n" if g else "")
                 + "错的对齐会把「能分开」算成「分不开」，所以不猜。用 --clap 秒数（手机用 --phone-clap）手动指定。")
    if len(c) > 1 and s[c[0]] - s[c[1]] < CLAP_DOMINANT_DB:
        sys.exit(f"前 {CLAP_SEARCH_S:.0f} 秒里有不止一个瞬态（关门？放杯子？），分不清哪个是拍手：\n"
                 f"  " + "、".join(fmt(i, s) for i in c) + "\n"
                 "错的对齐会把「能分开」算成「分不开」，所以不猜。用 --clap 秒数手动指定。")
    return c[0] * HOP / SR, float(s[c[0]])


def analyze(x, turn=20.0, rounds=4, guard=2.5, lead=1.0, vad_db=10.0, clap=None):
    r = {"corr": None, "margin": None}
    if x.ndim == 2:
        if x.shape[1] == 2:
            r["corr"] = float(np.corrcoef(x[:, 0], x[:, 1])[0, 1])
        x = x.mean(1)
    if x.size < MIN_AUDIO_S * SR:
        sys.exit(f"录音只有 {x.size / SR:.1f}s，没什么可分析的")
    if np.max(np.abs(x)) < 1e-4:
        sys.exit("整段录音几乎是数字静音：确认导出的是正确的文件、录音时麦克风没被占用")
    if clap is None:
        clap, r["margin"] = find_clap(x)

    E = frame_db(x)
    n = len(E)
    t = (np.arange(n) * HOP + FRAME / 2) / SR
    lo, hi = np.percentile(windows(np.pad(E, MOD_HALF, mode="edge"), 2 * MOD_HALF + 1), [10, 95], axis=1)
    M = hi - lo
    floor = float(np.percentile(E[E > SILENT_DB], 10))
    voiced = E > floor + vad_db

    t0 = clap + lead
    end = t0 + 2 * rounds * turn
    if t[-1] < end + 30:
        print(f"  注意：录音只有 {t[-1]:.0f}s，脚本段+负对照要到 {end + 30:.0f}s", file=sys.stderr)

    def truth_at(s0):
        tr = np.zeros(n, int)
        for k in range(2 * rounds):
            s = s0 + k * turn
            tr[(t >= s + guard) & (t < s + turn - guard)] = 1 if k % 2 == 0 else -1
        return tr
    truth = truth_at(t0)

    def calib(k):
        s = t0 + k * turn + guard
        m = voiced & (t >= s) & (t < s + CALIB_S)
        if m.sum() < 50:
            sys.exit(f"校准段 {s:.1f}–{s + CALIB_S:.1f}s 只有 {m.sum()} 个有声帧（该说话的是 {'AB'[k % 2]}）。\n"
                     f"可能是：拍手时刻找错、这个人开口比 --lead 晚、或者这段根本没人说话。核对后用 --clap / --lead 重跑")
        return m

    # 两维单位不同（dB 对 dB 但尺度差很多），按全体有声帧标准差归一，否则距离只由能量决定
    Z = np.stack([E, M], 1) / np.stack([E, M], 1)[voiced].std(0)
    cA, cB = Z[calib(0)].mean(0), Z[calib(1)].mean(0)
    dA, dB = np.linalg.norm(Z - cA, axis=1), np.linalg.norm(Z - cB, axis=1)
    raw = np.where(dA < dB, 1, -1)
    raw[np.minimum(dA, dB) > np.linalg.norm(cA - cB)] = 0      # 离两边都比两中心还远：不猜

    # 平滑只在有声帧序列上做：A 的音节间隙是无声帧，若算进窗里会把近场帧磨成「不确定」
    idx = np.flatnonzero(voiced)
    h = int(round(MEDIAN_S * SR / HOP)) // 2
    v = np.median(windows(np.pad(raw[idx], h, mode="edge"), 2 * h + 1), axis=1).astype(int)
    cuts = np.flatnonzero(np.diff(v)) + 1
    for a, b in zip(np.r_[0, cuts], np.r_[cuts, len(v)]):
        if v[a] != 0 and t[idx[b - 1]] - t[idx[a]] + HOP / SR < MIN_SEG_S:
            v[a:b] = 0
    pred = np.zeros(n, int)
    pred[idx] = v

    sc = voiced & (truth != 0)
    tr, pr = truth[sc], pred[sc]
    ea, eb = E[sc & (truth == 1)], E[sc & (truth == -1)]
    if min(len(ea), len(eb)) < MIN_SIDE_FRAMES:
        sys.exit(f"脚本段里 A 有 {len(ea)} 个有声帧、B 有 {len(eb)} 个（每人至少要 {MIN_SIDE_FRAMES}）。\n"
                 "可能是：只有一个人说话、拍手时刻找错、或 --turn/--rounds 和实际录的不一样")
    dec = pr != 0
    acc = float((pr[dec] == tr[dec]).mean()) if dec.any() else float("nan")
    trueA = len(ea) / (len(ea) + len(eb))
    estA = float((pr == 1).sum() / dec.sum()) if dec.any() else float("nan")

    # 判别轴上的 d′：分类器真正用的那个方向。和能量 d′ 拉开 = 分开靠的是混响/调制，不是音量
    w = cA - cB
    proj = Z @ (w / np.linalg.norm(w)) if np.linalg.norm(w) > 1e-9 else np.zeros(n)
    pa, pb = proj[sc & (truth == 1)], proj[sc & (truth == -1)]
    sd = np.sqrt((pa.var() + pb.var()) / 2)
    dprime2 = float((pa.mean() - pb.mean()) / sd) if sd > 1e-9 else 0.0

    # 真值可能是错的（人计时不准、拍手找错）。整体平移一下如果准确率明显变好，就别拿这个真值下结论
    shift, shift_acc = 0.0, acc
    if dec.any() and acc == acc:
        lim = min(SHIFT_MAX_S, turn / 2)        # 超过半轮就换成了对方的段，平移没意义
        for d in np.arange(-lim, lim + 1e-9, SHIFT_STEP_S):
            t2 = truth_at(t0 + d)
            m = voiced & (t2 != 0) & (pred != 0)
            if m.sum() >= MIN_SIDE_FRAMES:
                a2 = float((pred[m] == t2[m]).mean())
                if a2 > shift_acc:
                    shift, shift_acc = float(d), a2

    parts = []
    for i, name in enumerate(PARTS):
        a, b = end + 10 * i, (end + 10 * (i + 1) if i < 3 else np.inf)
        p = pred[voiced & (t >= a) & (t < b)]
        parts.append([(p == 1).mean(), (p == -1).mean(), (p == 0).mean()] if len(p) else None)

    r.update(clap=clap, floor=floor, thr=floor + vad_db, t=t, E=E, M=M, voiced=voiced, truth=truth, pred=pred,
             turn=turn, n=int(sc.sum()), acc=acc, unsure=float(1 - dec.mean()),
             dmed=float(np.median(ea) - np.median(eb)),
             dprime=float((ea.mean() - eb.mean()) / np.sqrt((ea.var() + eb.var()) / 2)), dprime2=dprime2,
             trueA=trueA, estA=estA, err=abs(estA - trueA) * 100, parts=parts,
             short=max(0.0, end - float(t[-1])), shift=shift, shift_acc=shift_acc,
             misalign=bool((shift_acc - acc) * 100 >= MISALIGN_PP and shift_acc >= ACC_NO
                           and abs(shift) >= MISALIGN_MIN_S))
    return r


def verdict(r):
    # 真值不可信 / 录音缺了半轮以上：分数是拿错尺子量的，YES 和 NO 都不能下
    if r["misalign"] or r["short"] > 0.5 * r["turn"]:
        return MAYBE
    # 「分不开」先判：准确率不够、或两个方向都没信息量（nan 也落在这里）
    if not r["acc"] >= ACC_NO or max(r["dprime"], r["dprime2"]) < DPRIME_NO:
        return NO
    # 能量 d′ 是这个方向的物理赌注。只靠混响调制分开的话，对方一提高音量、设备一动增益就翻盘
    if r["acc"] >= ACC_YES and r["err"] <= ERR_YES_PP and r["unsure"] <= UNSURE_YES and r["dprime"] >= DPRIME_NO:
        return YES
    return MAYBE


def compare(b, p):
    # 全部弃权 = 没提供信息，按二选一瞎猜的 50% 算
    ba, pa = (0.5 if r["acc"] != r["acc"] else r["acc"] for r in (b, p))
    gap = (ba - pa) * 100
    head = f"豆子 vs 手机：帧准确率 {ba:.1%} vs {pa:.1%}（差 {gap:+.1f}pp），d′ {b['dprime']:.2f} vs {p['dprime']:.2f} → "
    return head + ("豆子明显优于桌上手机" if gap >= BETTER_PP else f"豆子没有明显优于桌上手机（差不到 {BETTER_PP:.0f}pp），佩戴位置的优势不成立")


# ---------- 输出 ----------

def load(path, clap=None, **kw):
    r = analyze(decode(path, keep_channels=True), clap=clap, **kw)
    lab = np.array(["B", "", "A"])          # 索引 = 标签 + 1
    pr = np.where(r["voiced"], np.where(r["pred"] == 0, "?", lab[r["pred"] + 1]), "")
    with open(path + ".frames.csv", "w") as f:
        f.write("time,energy_db,mod_db,truth,pred\n")
        f.write("\n".join(f"{a:.2f},{b:.2f},{c:.2f},{d},{e}"
                          for a, b, c, d, e in zip(r["t"], r["E"], r["M"], lab[r["truth"] + 1], pr)) + "\n")
    r["csv"] = path + ".frames.csv"
    return r


def pad(s, w):
    return s + " " * max(0, w - sum(2 if ord(c) > 0x2E80 else 1 for c in s))


def pct(v):
    return "—" if v != v else f"{v:.1%}"


def report(rs, cols):
    L, W = 22, 28
    row = lambda label, f: print(pad(label, L) + "".join(pad(f(r), W) for r in rs).rstrip())
    print(pad("", L) + "".join(pad(c, W) for c in cols).rstrip())
    row("拍手时刻", lambda r: f"{r['clap']:.2f}s " + ("（手动）" if r["margin"] is None else
        f"（脉冲 {r['margin']:.0f}dB{'，存疑' if r['margin'] < CLAP_WARN_DB else ''}）"))
    row("两声道相关", lambda r: "单声道" if r["corr"] is None else f"{r['corr']:.3f}")
    row("底噪 / 有声阈值", lambda r: f"{r['floor']:.0f} / {r['thr']:.0f} dB")
    row("脚本段计分有声帧", lambda r: str(r["n"]))
    row("帧准确率", lambda r: pct(r["acc"]))
    row("不确定占比", lambda r: pct(r["unsure"]))
    row("能量中位数差 A−B", lambda r: f"{r['dmed']:+.1f} dB")
    row("d′（能量）", lambda r: f"{r['dprime']:.2f}")
    row("d′（判别轴）", lambda r: f"{r['dprime2']:.2f}")
    row("真实 A 占比", lambda r: pct(r["trueA"]))
    row("估计 A 占比", lambda r: pct(r["estA"]))
    row("占比误差", lambda r: "—" if r["err"] != r["err"] else f"{r['err']:.1f} pp")
    print("\n" + pad("估计占比（无真值）", L) + "A / B / 不确定")
    for i, name in enumerate(PARTS):
        row(name, lambda r: "—" if r["parts"][i] is None else " / ".join(f"{v:.0%}" for v in r["parts"][i]))
    print("  预期：B 大声仍应判 B（判成 A = 被音量骗了）；A 摘豆应转成 B 或不确定（证明靠的是距离不是嗓音）")
    print("\n结论")
    for c, r in zip(cols, rs):
        print(f"  {pad(c, 18)}{verdict(r)}")
        warn = lambda s: print(f"  {pad('', 18)}⚠ {s}")
        # 佩戴者反而更弱 = 物理上说不通，先怀疑对齐而不是怀疑方向
        if r["dprime"] < -0.3:      # -0.0 只是噪声，别喊狼来了
            warn("d′ 为负：A 比 B 还弱。多半是拍手时刻找错了、或先开口的不是 A，核对后重跑")
        if r["margin"] is not None and r["margin"] < CLAP_WARN_DB:
            warn(f"拍手脉冲只有 {r['margin']:.0f}dB，可能找的是别的碰撞声。人工听一下，用 --clap 指定")
        if r["misalign"]:
            warn(f"真值可能不准：把真值整体平移 {r['shift']:+.1f}s 后准确率 {pct(r['acc'])} → {pct(r['shift_acc'])}。"
                 f"先核对拍手时刻 / --lead / --turn 再看结论")
        if r["short"] > 0:
            warn(f"录音比脚本段短 {r['short']:.0f}s：最后几轮没录到，分数只代表录到的部分")
        if r["dprime"] < DPRIME_NO <= r["dprime2"]:
            warn(f"能量 d′ 只有 {r['dprime']:.2f}，判别轴 d′ 有 {r['dprime2']:.2f}：分开靠的是混响/调制，不是音量。"
                 f"对方一提高音量、设备一动自动增益就可能翻盘")
    if len(rs) == 2:
        print("  " + compare(*rs))
    for c, r in zip(cols, rs):
        if "csv" in r:
            print(f"  逐帧 CSV（{c}）→ {r['csv']}")


def cmd_analyze(a):
    kw = dict(turn=a.turn, rounds=a.rounds, guard=a.guard, lead=a.lead, vad_db=a.vad)
    rs, cols = [load(a.bead, a.clap, **kw)], ["豆子（领口）"]
    if a.phone:
        try:                                    # 手机那份挂了不该连豆子的结果一起丢掉
            rs.append(load(a.phone, a.phone_clap, **kw))
            cols.append("手机（桌上）")
        except SystemExit as e:
            print(f"手机录音没法分析，只报豆子：{e}\n", file=sys.stderr)
    report(rs, cols)


# ---------- 合成数据自检 ----------

def _carrier(rng, n):
    X = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    X[(f < 300) | (f > 3400)] = 0
    c = np.fft.irfft(X, n)
    return c / c.std()


def _env(rng, n, spans):
    """约 4Hz 的音节包络，音节之间留静音。"""
    env = np.zeros(n)
    for a, b in spans:
        s = a
        while s < b:
            L = rng.uniform(0.15, 0.22)
            i = int(s * SR)
            seg = np.hanning(int(L * SR)) * 10 ** (rng.uniform(-3, 3) / 20)
            env[i:i + len(seg)] = seg[:max(0, n - i)]
            s += L + rng.uniform(0.02, 0.08)
    return env


def _conv(x, h):
    N = 1 << int(np.ceil(np.log2(len(x) + len(h))))
    return np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(h, N), N)[:len(x)]


def synth(seed=0, turn=20.0, rounds=4, clap_t=1.5, lead=1.0, T=215):
    """按今晚的录音流程拼一段：拍手 + lead + 4 轮 A/B + 负对照 30s + 自然段 20s。
    返回 (豆子, 桌上手机, 被自动增益压平的豆子, 拍手时刻)。"""
    rng = np.random.default_rng(seed)
    n = T * SR
    # 每个换人点 ±1s 抖动，换人时各让 0.5s（约 1s 停顿）：模拟人的计时误差
    b = clap_t + lead + turn * np.arange(2 * rounds + 1) + rng.uniform(-1, 1, 2 * rounds + 1)
    sp = {"A": [], "B": [], "A_off": [], "B_loud": []}
    for k in range(2 * rounds):
        sp["AB"[k % 2]].append((b[k] + 0.5, b[k + 1] - 0.5))
    nc = b[-1]
    sp["B_loud"].append((nc + 0.5, nc + 9.5))
    sp["A_off"].append((nc + 10.5, nc + 19.5))
    sp["A"].append((nc + 20.5, nc + 29.5))
    sp["B"].append((nc + 20.5, nc + 29.5))
    s, who = nc + 30.5, 0
    while s < nc + 50:
        d = rng.uniform(1.5, 4)
        sp["AB"[who]].append((s, min(s + d, nc + 50)))
        s, who = s + d + 0.3, who ^ 1

    car = {"A": _carrier(rng, n), "B": _carrier(rng, n)}
    env = {k: _env(rng, n, v) for k, v in sp.items()}
    L = int(0.5 * SR)
    h = rng.standard_normal(L) * np.exp(-6.91 * np.arange(L) / SR / 0.4)   # RT60 = 0.4s：60dB = e^-6.91
    h /= np.sqrt((h ** 2).sum())
    k = int(0.01 * SR)
    clap = np.zeros(n)
    clap[int(clap_t * SR):int(clap_t * SR) + k] = 0.9 * rng.standard_normal(k) * np.exp(-np.arange(k) / (0.003 * SR))
    noise = 0.001 * rng.standard_normal(n)

    def mix(parts):
        dry, wet = np.zeros(n), np.zeros(n)
        for key, g, rev in parts:
            dst = wet if rev else dry
            dst += 0.1 * 10 ** (g / 20) * car[key[0]] * env[key]
        return (dry + _conv(wet, h) + clap + noise).astype(np.float32)

    bead = mix([("A", 0, False), ("A_off", -6, True), ("B", -14, True), ("B_loud", -8, True)])
    phone = mix([("A", -6, True), ("A_off", -6, True), ("B", -6, True), ("B_loud", 0, True)])
    # 自动增益把远近差压到 3dB，混响照旧：调制深度还分得开，但「近场更响」这个物理赌注没了
    agc = mix([("A", 0, False), ("A_off", -3, True), ("B", -3, True), ("B_loud", -1, True)])
    return bead, phone, agc, clap_t


def fails(fn, *a, **kw):
    """只给自检用：拿到 sys.exit 的话，返回那句话。"""
    try:
        fn(*a, **kw)
    except SystemExit as e:
        return str(e)
    return None


def cmd_selftest():
    t_start = time.time()
    bead, phone, agc, clap_t = synth()
    with tempfile.TemporaryDirectory() as d:
        p = {k: os.path.join(d, k + ".wav") for k in ("bead", "stereo", "phone")}
        encode(bead, p["bead"])
        encode(np.stack([bead, bead], 1), p["stereo"])
        encode(phone, p["phone"])
        rb, rs, rp = load(p["bead"]), load(p["stereo"]), load(p["phone"])
    for r in (rb, rp):
        r.pop("csv")
    report([rb, rp], ["豆子（合成）", "桌上手机（合成）"])

    print("\n断言")
    assert rb["acc"] >= 0.9 and rb["err"] <= 5 and verdict(rb) == YES, \
        f"豆子场景没分出来：准确率 {pct(rb['acc'])}，占比误差 {rb['err']:.1f}pp，结论「{verdict(rb)}」"
    print(f"  1 豆子：准确率 {pct(rb['acc'])} ≥ 90%，占比误差 {rb['err']:.1f}pp ≤ 5，结论「{YES}」    通过")
    assert (rp["dprime"] < 1 or not rp["acc"] >= 0.75) and verdict(rp) == NO, \
        f"桌上手机场景没说「分不开」：d′ {rp['dprime']:.2f}，准确率 {pct(rp['acc'])}，结论「{verdict(rp)}」"
    print(f"  2 桌上手机：d′ {rp['dprime']:.2f}，准确率 {pct(rp['acc'])}，结论「{NO}」    通过")
    errs = [abs(r["clap"] - clap_t) * 1000 for r in (rb, rp)]
    assert max(errs) < 50, f"拍手定位误差 {max(errs):.0f}ms"
    print(f"  3 拍手定位误差 豆子 {errs[0]:.0f}ms / 手机 {errs[1]:.0f}ms < 50ms    通过")
    assert rs["corr"] is not None and rs["corr"] > 0.999 and rb["corr"] is None, "双声道没被识别出来"
    assert np.array_equal(rs["pred"], rb["pred"]) and rs["acc"] == rb["acc"] and rs["clap"] == rb["clap"], \
        "双声道（两路相同）和单声道结果不一致"
    print(f"  4 双声道（相关 {rs['corr']:.3f}）与单声道逐帧结果一致    通过")

    # 5 自动增益把差距压到 3dB：调制深度照样分得开，但不能因此说「能分出」——一次增益更新就翻盘
    ra = analyze(agc)
    assert verdict(ra) != YES and ra["dprime"] < DPRIME_NO, \
        f"增益压平后还说「{verdict(ra)}」：能量 d′ {ra['dprime']:.2f}"
    print(f"  5 增益压平（只差 3dB）：准确率 {pct(ra['acc'])}，能量 d′ {ra['dprime']:.2f} < 1，"
          f"判别轴 d′ {ra['dprime2']:.2f}，结论「{verdict(ra)}」    通过")

    # 6 没拍手 / 有更响的关门声：只能报错让人手动指定，绝不能静默拿错时刻打分
    head = bead[:int(20 * SR)].copy()
    quiet = head.copy()
    quiet[int(1.4 * SR):int(1.8 * SR)] = 0.001 * np.random.default_rng(1).standard_normal(int(0.4 * SR))
    door = head.copy()
    door[int(0.6 * SR):int(0.6 * SR) + 160] += 3 * head[int(clap_t * SR):int(clap_t * SR) + 160]
    m1, m2 = fails(find_clap, quiet), fails(find_clap, door)
    assert m1 and "没有拍手" in m1, f"没拍手却给了个时刻：{find_clap(quiet)}"
    assert m2 and "不止一个" in m2, f"关门声更响却没报错：{find_clap(door)}"
    assert abs(find_clap(head)[0] - clap_t) < 0.05, "正常录音反而找不到拍手了"
    print("  6 没拍手 / 关门声更响：都报错要求 --clap，正常录音仍找得到    通过")

    # 7 真值本身不可信（--lead 给错 5s）时，既不能说「能分出」也不能说「分不开」
    rm = analyze(bead, lead=6.0)
    assert rm["misalign"] and verdict(rm) == MAYBE, \
        f"真值平移 5s 后没提示：misalign={rm['misalign']}，结论「{verdict(rm)}」"
    print(f"  7 --lead 错 5s：准确率 {pct(rm['acc'])}，提示平移 {rm['shift']:+.1f}s 可到 {pct(rm['shift_acc'])}，"
          f"结论「{MAYBE}」    通过")

    # 8 录音没录完 / 太短 / 全静音：降级或优雅报错，不能拿半截数据下 YES，也不能崩
    rt = analyze(bead[:int(60 * SR)])
    assert rt["short"] > 0 and verdict(rt) != YES, f"只录了 60s 还说「{verdict(rt)}」"
    assert fails(analyze, np.zeros(int(2 * SR), np.float32)), "太短的文件没报错"
    assert fails(analyze, np.zeros(int(30 * SR), np.float32)), "全静音的文件没报错"
    print(f"  8 只录了 60s（缺 {rt['short']:.0f}s）：结论「{verdict(rt)}」；太短/全静音都优雅报错    通过")

    dt = time.time() - t_start
    assert dt < 10, f"自检跑了 {dt:.1f}s，超过 10s"
    print(f"  9 用时 {dt:.1f}s < 10s    通过")
    print("\nOK")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="领口录音豆：近场/远场能不能分出我和对方")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("selftest")
    q = sub.add_parser("analyze")
    q.add_argument("bead", help="豆子录音（soundcore App 导出，任意格式）")
    q.add_argument("--phone", help="桌上手机同时录的对照")
    q.add_argument("--turn", type=float, default=20.0, help="每人每段秒数")
    q.add_argument("--rounds", type=int, default=4)
    q.add_argument("--guard", type=float, default=2.5, help="每段两端不计分的秒数，吸收人的计时误差")
    q.add_argument("--lead", type=float, default=1.0, help="拍手到开口的秒数")
    q.add_argument("--vad", type=float, default=10.0, help="有声阈值：高出底噪（10 分位）多少 dB")
    q.add_argument("--clap", type=float, help="手动指定豆子录音里的拍手时刻（秒）")
    q.add_argument("--phone-clap", type=float, help="手动指定手机录音里的拍手时刻（秒）")
    a = ap.parse_args()
    cmd_selftest() if a.cmd == "selftest" else cmd_analyze(a)
