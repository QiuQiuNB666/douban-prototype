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

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import app

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
    handler = partial(app.Handler, directory=HERE)
    plain = ThreadingHTTPServer(("0.0.0.0", 8770), handler)
    tls = ThreadingHTTPServer(("0.0.0.0", 8443), handler)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(CRT, KEY)
    tls.socket = ctx.wrap_socket(tls.socket, server_side=True)
    threading.Thread(target=tls.serve_forever, daemon=True).start()
    print(f"手机版（能录音）：https://{ip}:8443/m/\n原型：http://{ip}:8770/豆伴.html", flush=True)
    plain.serve_forever()
