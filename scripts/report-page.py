#!/usr/bin/env python3
"""Render a Markdown report as one self-contained HTML page in the diffwright look.

Dark is the default; the toggle switches to light and the choice is remembered per
browser. Styling follows the diffwright palette (site/style.css): warm paper in light,
near-black #161513 in dark, teal accent.

Usage:
  scripts/report-page.py <file.md> [--out DIR] [--title TITLE] [--source LABEL]
  scripts/report-page.py <file.md> --serve [--port N] [--bind ADDR]

--serve renders into a temp dir and blocks on python3 -m http.server, printing the URL.
"""
import argparse
import datetime
import html
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

try:
    import markdown
except ImportError:  # pragma: no cover - environment guard
    sys.exit("report-page.py needs the python3-markdown package (apt: python3-markdown)")

CSS = """
:root {
  color-scheme: dark;
  --bg: #161513; --surface: #201f1c; --surface-2: #2a2925;
  --text: #ece9e2; --muted: #a9a59c; --border: #3d3b36;
  --accent: #4fd1c0; --accent-ink: #0d1a18;
  --code-bg: #26251f; --table-head: #2a2925;
  --shadow: 0 6px 24px rgba(0,0,0,.55);
}
:root[data-theme="light"] {
  color-scheme: light;
  --bg: #f7f5f0; --surface: #ffffff; --surface-2: #f0ede6;
  --text: #1f1d1a; --muted: #5d5a54; --border: #d9d4c9;
  --accent: #0f766e; --accent-ink: #ffffff;
  --code-bg: #f0ede6; --table-head: #f0ede6;
  --shadow: 0 6px 24px rgba(0,0,0,.14);
}
* { box-sizing: border-box; }
html { background: var(--bg); }
body {
  margin: 0; background: var(--bg); color: var(--text);
  font: 17px/1.62 ui-sans-serif, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
}
.bar {
  position: sticky; top: 0; z-index: 5; display: flex; gap: .8rem; align-items: center;
  justify-content: space-between; padding: .55rem clamp(1rem, 4vw, 2rem);
  background: color-mix(in srgb, var(--bg) 82%, transparent);
  backdrop-filter: blur(8px); border-bottom: 1px solid var(--border);
  font-size: .82rem; color: var(--muted);
}
.bar .where { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.bar button {
  font: inherit; color: var(--text); background: var(--surface); border: 1px solid var(--border);
  border-radius: 999px; padding: .25rem .8rem; cursor: pointer; white-space: nowrap;
}
.bar button:hover { border-color: var(--accent); }
.bar button:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
main { max-width: 47rem; margin: 0 auto; padding: 2rem clamp(1rem, 4vw, 2rem) 5rem; }
h1 { font-size: 1.85rem; line-height: 1.22; letter-spacing: -.015em; margin: .4rem 0 .9rem; }
h2 {
  font-size: 1.32rem; line-height: 1.3; margin: 2.8rem 0 .8rem; padding-top: 1.2rem;
  border-top: 1px solid var(--border);
}
h3 { font-size: 1.07rem; margin: 1.8rem 0 .5rem; }
p { margin: .8rem 0; }
ul, ol { padding-left: 1.35rem; margin: .7rem 0; }
li { margin: .28rem 0; }
li > p { margin: .3rem 0; }
strong { font-weight: 660; }
a { color: var(--accent); text-decoration: none; border-bottom: 1px solid color-mix(in srgb, var(--accent) 35%, transparent); }
a:hover { border-bottom-color: var(--accent); }
table { border-collapse: collapse; width: 100%; margin: 1.1rem 0 1.5rem; font-size: .94rem; display: block; overflow-x: auto; }
th, td { text-align: left; vertical-align: top; padding: .5rem .6rem; border-bottom: 1px solid var(--border); }
th { background: var(--table-head); font-weight: 640; white-space: nowrap; }
tr:last-child td { border-bottom: 0; }
blockquote { margin: 1.1rem 0; padding: .2rem 1rem; border-left: 3px solid var(--border); color: var(--muted); }
code { font: .9em ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; background: var(--code-bg); padding: .12em .34em; border-radius: 4px; }
pre { background: var(--surface-2); border: 1px solid var(--border); padding: 1rem; border-radius: 8px; overflow-x: auto; }
pre code { background: none; padding: 0; font-size: .88em; }
hr { border: 0; border-top: 1px solid var(--border); margin: 2.6rem 0; }
img { max-width: 100%; height: auto; }
.foot { margin-top: 3rem; padding-top: 1rem; border-top: 1px solid var(--border); color: var(--muted); font-size: .8rem; }
@media print { .bar { display: none; } body { background: #fff; color: #000; } a { color: #000; } }
"""

JS = """
(function () {
  var KEY = 'report-page-theme';
  var root = document.documentElement;
  var saved = null;
  try { saved = localStorage.getItem(KEY); } catch (e) {}
  if (saved === 'light' || saved === 'dark') root.dataset.theme = saved;
  else root.dataset.theme = 'dark';
  var btn = document.getElementById('theme');
  function label() {
    var dark = root.dataset.theme !== 'light';
    btn.textContent = dark ? '\\u263e Dark' : '\\u2600 Light';
    btn.setAttribute('aria-label', dark ? 'Switch to light theme' : 'Switch to dark theme');
  }
  btn.addEventListener('click', function () {
    root.dataset.theme = root.dataset.theme === 'light' ? 'dark' : 'light';
    try { localStorage.setItem(KEY, root.dataset.theme); } catch (e) {}
    label();
  });
  label();
})();
"""

def render(md_path: pathlib.Path, title: str | None, source: str | None) -> str:
    text = md_path.read_text(encoding="utf-8")
    body = markdown.markdown(
        text,
        extensions=["tables", "fenced_code", "sane_lists", "attr_list", "toc"],
        extension_configs={"toc": {"permalink": False}},
    )
    # The report's own H1 is the page title; do not repeat it in the bar.
    heading = title
    if not heading:
        m = re.search(r"^#\s+(.+)$", text, re.M)
        heading = m.group(1).strip() if m else md_path.stem
    where = source or str(md_path)
    stamp = datetime.date.today().isoformat()
    return f"""<!doctype html>
<html lang="en" data-theme="dark">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(re.sub(r"<[^>]+>", "", heading))}</title>
<style>{CSS}</style>
</head>
<body>
<div class="bar"><span class="where">{html.escape(where)} &middot; {stamp}</span><button id="theme" type="button">&#9790; Dark</button></div>
<main>
{body}
<div class="foot">Rendered by crafting-guild scripts/report-page.py &middot; diffwright palette, dark by default.</div>
</main>
<script>{JS}</script>
</body>
</html>
"""

def main() -> int:
    ap = argparse.ArgumentParser(description="Render a Markdown report as one HTML page (dark by default).")
    ap.add_argument("file", type=pathlib.Path)
    ap.add_argument("--out", type=pathlib.Path, help="directory to write index.html into (default: beside the file, .page/)")
    ap.add_argument("--title")
    ap.add_argument("--source", help="label in the top bar (default: the file path)")
    ap.add_argument("--serve", action="store_true", help="render to a temp dir and serve it")
    ap.add_argument("--port", type=int, default=8811)
    ap.add_argument("--bind", default="127.0.0.1")
    args = ap.parse_args()
    if not args.file.is_file():
        sys.exit(f"no such file: {args.file}")

    page = render(args.file.resolve(), args.title, args.source)
    if args.serve:
        out = pathlib.Path(tempfile.mkdtemp(prefix="report-page-"))
    else:
        out = args.out or (args.file.resolve().parent / ".page")
    out.mkdir(parents=True, exist_ok=True)
    (out / "index.html").write_text(page, encoding="utf-8")
    print(out / "index.html")
    if args.serve:
        url = f"http://{args.bind}:{args.port}/"
        print(url, flush=True)
        try:
            subprocess.run(
                [sys.executable, "-m", "http.server", str(args.port), "--bind", args.bind, "--directory", str(out)],
                check=False,
            )
        except KeyboardInterrupt:
            pass
        finally:
            shutil.rmtree(out, ignore_errors=True)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
