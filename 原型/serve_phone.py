#!/usr/bin/env python3
"""
手机版的启动器：同一个服务同时开两个口。

    http://<这台电脑>:8770   原型和上传（浏览器不给 HTTP 页面用麦克风，只能传已有的录音）
    https://<这台电脑>:8443  手机版：网页里直接录音。证书是自签名的，手机第一次打开要点一次「继续访问」

    /Users/qiu/黑客松/.venv/bin/python serve_phone.py

接口和静态文件都复用 app.py（归 D 真录音线），这里不改它，只是再包一层 TLS。
证书放在 ~/黑客松-预赛/.cert/（不进仓库），局域网地址变了就自动重签。
"""
import os, socket, ssl, subprocess, sys, threading
from functools import partial
from http.server import ThreadingHTTPServer
from urllib.parse import unquote

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import app

# 这两个口绑在 0.0.0.0 上，同一个 WiFi 上的人都够得着，所以只放行页面真正用到的路径。
# 不加白名单的话，整个 原型/ 会被当成静态站点发出去：目录列表、全部源码（含别的线写死的主机地址）、历史版本草稿。
ALLOW = {"/豆伴.html", "/m/", "/m/index.html", "/m/icon.png", "/m/icon-512.png", "/m/manifest.webmanifest", "/api/ping"}
app.MAX_BYTES = 80 * 1024 * 1024        # 手机录的 m4a 一小时约 30 MB；默认的 300 MB 对一个开在 WiFi 上的口太宽


class PhoneHandler(app.Handler):
    def _allowed(self):
        return unquote(self.path.split("?")[0].split("#")[0]) in ALLOW      # 精确匹配：/./、/%2e/、/hr.py、/__pycache__/ 都不在里面

    def do_GET(self):
        return super().do_GET() if self._allowed() else self._json(404, {"error": "没有这个页面"})

    def do_HEAD(self):
        if self._allowed():
            return super().do_HEAD()
        self.send_response(404); self.send_header("Content-Length", "0"); self.end_headers()


CERT_DIR = os.path.join(HERE, "..", ".cert")
CRT, KEY, SAN = (os.path.join(CERT_DIR, n) for n in ("douban.crt", "douban.key", "san.txt"))


def lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))            # 不发包，只是让系统选出走局域网的那块网卡
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


def ensure_cert(ip):
    san = f"IP:{ip},IP:127.0.0.1,DNS:localhost,DNS:{socket.gethostname()}"
    if all(map(os.path.exists, (CRT, KEY, SAN))) and open(SAN).read() == san:
        return
    os.makedirs(CERT_DIR, exist_ok=True)
    subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "60", "-keyout", KEY, "-out", CRT,
                    "-subj", "/CN=douban-local", "-addext", f"subjectAltName={san}"], check=True, capture_output=True)
    os.chmod(KEY, 0o600)
    open(SAN, "w").write(san)


if __name__ == "__main__":
    ip = lan_ip()
    ensure_cert(ip)
    handler = partial(PhoneHandler, directory=HERE)
    plain = ThreadingHTTPServer(("0.0.0.0", 8770), handler)
    tls = ThreadingHTTPServer(("0.0.0.0", 8443), handler)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(CRT, KEY)
    tls.socket = ctx.wrap_socket(tls.socket, server_side=True)
    threading.Thread(target=tls.serve_forever, daemon=True).start()
    print(f"手机版（能录音）：https://{ip}:8443/m/\n原型：http://{ip}:8770/豆伴.html", flush=True)
    plain.serve_forever()
