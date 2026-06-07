#!/usr/bin/env python3
"""
yt-transcript — small YouTube → transcript service for GX10 (spark).

Runs on GX10's residential IP (not bot-blocked like the netcup datacenter
IP) and reuses the local parakeet/whisper ASR server (127.0.0.1:8990) for
the no-captions fallback. rSpace's Notebook calls this over tailscale.

POST /transcript  {"url": "...", "lang": "en"}   (Bearer YT_TRANSCRIPT_TOKEN)
  -> {"ok": true, "title": str, "text": str, "source": "captions"|"asr"}
GET  /health -> {"ok": true}
"""
import json, os, re, subprocess, tempfile, shutil, glob, urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

YT_DLP = os.environ.get("YT_DLP_BIN", os.path.expanduser("~/.local/bin/yt-dlp"))
ASR_URL = os.environ.get("ASR_URL", "http://127.0.0.1:8990/v1/audio/transcriptions")
ASR_MODEL = os.environ.get("ASR_MODEL", "whisper-large-v3")
TOKEN = os.environ.get("YT_TRANSCRIPT_TOKEN", "")
PORT = int(os.environ.get("PORT", "8991"))
MAX_AUDIO = os.environ.get("MAX_FILESIZE", "120M")

YT_RE = re.compile(r"(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([\w-]{11})")


def run(cmd, timeout):
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired:
        return 124, "", "timeout"
    except FileNotFoundError as e:
        return 127, "", f"not found: {e}"


def vtt_to_text(vtt: str) -> str:
    out, last = [], ""
    for line in vtt.splitlines():
        line = line.strip()
        if not line or line == "WEBVTT" or "-->" in line or line.isdigit():
            continue
        if line.startswith(("Kind:", "Language:", "NOTE")):
            continue
        line = re.sub(r"<[^>]+>", "", line).replace("&nbsp;", " ").strip()
        if not line or line == last:
            continue
        out.append(line); last = line
    return re.sub(r"\s+", " ", " ".join(out)).strip()


def get_title(url):
    code, out, _ = run([YT_DLP, "--skip-download", "--no-warnings", "--print", "%(title)s", url], 60)
    return out.strip().splitlines()[0] if code == 0 and out.strip() else None


def transcribe(path):
    with open(path, "rb") as f:
        data = f.read()
    boundary = "----ytb" + os.urandom(8).hex()
    body = b""
    body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"model\"\r\n\r\n{ASR_MODEL}\r\n".encode()
    body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{os.path.basename(path)}\"\r\nContent-Type: audio/mpeg\r\n\r\n".encode()
    body += data + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(ASR_URL, data=body, method="POST",
                                 headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return (json.loads(r.read().decode()).get("text") or "").strip()


def fetch_transcript(url, lang="en"):
    vid = YT_RE.search(url)
    if not vid:
        return {"ok": False, "error": "not a YouTube URL"}
    d = tempfile.mkdtemp(prefix="yt-")
    try:
        title = get_title(url)
        # 1) captions
        run([YT_DLP, "--skip-download", "--write-subs", "--write-auto-subs",
             "--sub-langs", f"{lang}.*,{lang}", "--convert-subs", "vtt", "--no-warnings",
             "-o", os.path.join(d, "v.%(ext)s"), url], 150)
        vtts = glob.glob(os.path.join(d, "*.vtt"))
        if vtts:
            text = vtt_to_text(open(vtts[0], encoding="utf-8", errors="ignore").read())
            if len(text) > 40:
                return {"ok": True, "title": title or f"YouTube {vid.group(1)}", "text": text, "source": "captions"}
        # 2) audio -> ASR
        code, _, err = run([YT_DLP, "-f", "bestaudio", "-x", "--audio-format", "mp3",
                            "--max-filesize", MAX_AUDIO, "--no-warnings",
                            "-o", os.path.join(d, "a.%(ext)s"), url], 300)
        auds = glob.glob(os.path.join(d, "a.*"))
        if auds:
            text = transcribe(auds[0])
            if text:
                return {"ok": True, "title": title or f"YouTube {vid.group(1)}", "text": text, "source": "asr"}
        return {"ok": False, "title": title, "error": (err or "no captions or audio").strip().splitlines()[-1][:200]}
    except Exception as e:
        return {"ok": False, "error": str(e)[:200]}
    finally:
        shutil.rmtree(d, ignore_errors=True)


class H(BaseHTTPRequestHandler):
    def _send(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)

    def log_message(self, *a):
        pass

    def do_GET(self):
        if self.path == "/health":
            self._send(200, {"ok": True, "service": "yt-transcript"})
        else:
            self._send(404, {"ok": False, "error": "not found"})

    def do_POST(self):
        if TOKEN:
            auth = self.headers.get("Authorization", "")
            if auth != f"Bearer {TOKEN}":
                return self._send(401, {"ok": False, "error": "unauthorized"})
        if self.path != "/transcript":
            return self._send(404, {"ok": False, "error": "not found"})
        try:
            n = int(self.headers.get("Content-Length", "0"))
            body = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            return self._send(400, {"ok": False, "error": "bad json"})
        url = (body.get("url") or "").strip()
        if not url:
            return self._send(400, {"ok": False, "error": "url required"})
        res = fetch_transcript(url, (body.get("lang") or "en").strip())
        self._send(200 if res.get("ok") else 502, res)


if __name__ == "__main__":
    print(f"yt-transcript on :{PORT} (yt-dlp={YT_DLP}, asr={ASR_URL}/{ASR_MODEL}, auth={'on' if TOKEN else 'OFF'})", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), H).serve_forever()
