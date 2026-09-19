#!/usr/bin/env python3
"""
豆伴验证工具的本地服务：把 原型/ 当静态站点发出去，外加一个接口 —— 传一段真录音，真的算出「一起说了多久、各说几成」。

    /Users/qiu/黑客松/.venv/bin/python app.py                 # 只在本机：http://localhost:8770/豆伴.html
    /Users/qiu/黑客松/.venv/bin/python app.py 0.0.0.0         # 手机、iPad 连同一个 WiFi 也能打开（上传接口没有鉴权，只在可信网络里开）

录音不落盘：收到的字节写进临时文件，交给 ffmpeg 解码，算完即删；只回数字，和产品的承诺一致。
这是赛前的验证工具，不是参赛成品；决赛的 App 现场开发（细则 515）。
"""
import json, os, re, sys, tempfile, time
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "实验"))
import shape

MAX_BYTES = 300 * 1024 * 1024          # 一小时的 m4a 也就几十 MB；再大多半是传错了文件
MAX_SECONDS = 3 * 3600


class Handler(SimpleHTTPRequestHandler):
    def _json(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def end_headers(self):                                  # 原型改得勤，别让浏览器缓存旧页面
        if not self.path.startswith("/api/"):
            self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self):
        if self.path.split("?")[0] == "/api/ping":
            return self._json(200, {"ok": True})
        super().do_GET()

    def do_POST(self):
        if self.path.split("?")[0] != "/api/analyze":
            return self._json(404, {"error": "没有这个接口"})
        try:
            n = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            n = 0
        if not 0 < n <= MAX_BYTES:
            return self._json(413, {"error": f"文件是空的，或者超过了 {MAX_BYTES // 2**20} MB"})
        ext = re.sub(r"[^A-Za-z0-9]", "", self.headers.get("X-Ext", ""))[:8] or "bin"      # 只拿来给 ffmpeg 提示格式
        t0, path = time.time(), None
        try:
            with tempfile.NamedTemporaryFile(suffix="." + ext, delete=False) as f:
                path = f.name
                left = n
                while left:
                    chunk = self.rfile.read(min(left, 1 << 20))
                    if not chunk:
                        raise ValueError("上传中断了，再传一次")
                    f.write(chunk)
                    left -= len(chunk)
            x = shape.decode(path)
            if x.size > MAX_SECONDS * shape.SR:
                raise ValueError("录音超过 3 小时，先截一段再传")
            r = shape.analyze_free(x)
            r.pop("pred")
            r.update(seconds=round(time.time() - t0, 1), deleted=True)
            self._json(200, r)
        except ValueError as e:
            self._json(400, {"error": str(e)})
        except RuntimeError:                                # ffmpeg 解不开。它的报错里有临时路径，不往外给
            self._json(400, {"error": "这个文件解不开，可能不是录音。m4a、wav、mp3、aac 这些都可以。"})
        finally:
            if path and os.path.exists(path):
                os.unlink(path)                             # 算完就删

    def log_message(self, fmt, *args):
        if "/api/" in (args[0] if args else ""):
            sys.stderr.write("%s %s\n" % (self.log_date_time_string(), fmt % args))


def demo():
    """自检：合成一段「豆子」录音，走一遍真实的 HTTP 上传，检查返回的占比和临时文件清理。"""
    import threading, urllib.request, glob, numpy as np
    srv = ThreadingHTTPServer(("127.0.0.1", 0), partial(Handler, directory=HERE))
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    base = f"http://127.0.0.1:{srv.server_address[1]}"
    bead = shape.synth()[0]
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, "bead.wav"); shape.encode(bead, wav); data = open(wav, "rb").read()
    before = set(glob.glob(os.path.join(tempfile.gettempdir(), "tmp*.wav")))
    post = lambda body, ext: urllib.request.urlopen(urllib.request.Request(base + "/api/analyze", data=body, headers={"X-Ext": ext}, method="POST"))
    r = json.load(post(data, "wav"))
    assert json.load(urllib.request.urlopen(base + "/api/ping"))["ok"]
    assert r["mode"] == "opening" and 30 <= r["share"] <= 50 and r["deleted"] and len(r["strip"]) == shape.STRIP_BINS, r
    assert set(glob.glob(os.path.join(tempfile.gettempdir(), "tmp*.wav"))) == before, "临时文件没删干净"
    try:
        post(b"not audio at all", "../../etc/passwd"); raise AssertionError("乱传的文件没被拒绝")
    except urllib.error.HTTPError as e:
        assert e.code == 400 and "error" in json.load(e)
    srv.shutdown()
    print(f"DEMO PASSED：上传 {len(data) // 1024} KB → 我 {r['share']:.0f}%，一起说了 {r['me'] + r['you']:.0f} 秒，用时 {r['seconds']}s；临时文件已删；乱传的文件返回 400")


if __name__ == "__main__":
    if sys.argv[1:2] == ["demo"]:
        demo()
    else:
        host = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
        port = int(sys.argv[2]) if len(sys.argv) > 2 else 8770
        print(f"豆伴验证工具：http://{'localhost' if host == '127.0.0.1' else host}:{port}/豆伴.html", flush=True)
        ThreadingHTTPServer((host, port), partial(Handler, directory=HERE)).serve_forever()
