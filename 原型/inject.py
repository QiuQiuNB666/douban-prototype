#!/usr/bin/env python3
"""把真实的模型输出注入 豆伴.html 的 /*REAL*/…/*END*/。页面里这一段不要手改，改数据就重跑这个脚本。

    /Users/qiu/黑客松/.venv/bin/python inject.py

来源：../实验/assistant_results.json（第一轮，三种情形）、../实验/subagent_round2_0919.checked.json（第二轮，四种原因）。
每种情形页面上展示第 1 次运行的输出；同一情形几次运行的决定不一致时，如实标出来。
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
EXP = os.path.join(HERE, "..", "实验")
sys.path.insert(0, EXP)
import assistant_check as a

load = lambda name: json.load(open(os.path.join(EXP, name), encoding="utf-8"))["results"]
r1, r2 = load("assistant_results.json"), load("subagent_round2_0919.checked.json")
assert not any(x["errors"] for x in r1 + r2), "有没过校验的输出，先看清楚再注入"

real = []
for i, c in enumerate(a.CASES[:a.ROUND1]):
    x = next(x for x in r1 if x["case_index"] == i and x["run"] == 1)
    real.append({"name": c["name"], "weeks": c["weeks"], "rule": x["rule"], "assistant": x["out"], "errors": x["errors"]})

third = real[2]                                   # 第二轮接在「占比下降」那一情形后面
third["round2"], third["round2_runs"] = {}, {}
for i, c in enumerate(a.CASES[a.ROUND1:], a.ROUND1):
    runs = sorted((x for x in r2 if x["case_index"] == i), key=lambda x: x["run"])
    third["round2"][c["parent_reason"]] = runs[0]["out"]
    third["round2_runs"][c["parent_reason"]] = [x["out"]["remind"] for x in runs]

path = os.path.join(HERE, "豆伴.html")
s = open(path, encoding="utf-8").read()
blob = json.dumps(real, ensure_ascii=False).replace("</", "<\\/")
s, n = re.subn(r"/\*REAL\*/.*?/\*END\*/", lambda m: "/*REAL*/" + blob + "/*END*/", s, count=1, flags=re.S)
assert n == 1, "页面里找不到 /*REAL*/…/*END*/"
open(path, "w", encoding="utf-8").write(s)

# 私密预览页（claude.ai Artifact）用的变体：发布时外层骨架由平台加，这里去掉 html/head/body 和 meta，字体样式表直接链接。
m = re.search(r"<title>.*?</title>", s, flags=re.S); css = re.search(r"<style>.*?</style>", s, flags=re.S); body = re.search(r"<body>(.*)</body>", s, flags=re.S)
font = re.search(r'<link rel="stylesheet" href="(https://fonts\.googleapis\.com/[^"]+)"', s)
art = f'<title>豆伴原型</title>\n<link rel="stylesheet" href="{font.group(1)}">\n{css.group(0)}\n{body.group(1).strip()}\n'
open(os.path.join(HERE, "豆伴.artifact.html"), "w", encoding="utf-8").write(art)

print("已注入：第一轮", [r["assistant"]["remind"] for r in real], "；第二轮", third["round2_runs"])
