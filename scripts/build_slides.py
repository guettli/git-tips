#!/usr/bin/env python3
from __future__ import annotations

import argparse
import html
import os
import re
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Iterable
from urllib.parse import urldefrag

import markdown
from markdown.extensions import Extension
from markdown.treeprocessors import Treeprocessor


HEADING_RE = re.compile(r"^(#{1,6})[ \t]+(.+?)[ \t]*#*[ \t]*$")
FENCE_RE = re.compile(r"^([ \t]{0,3})(`{3,}|~{3,})(.*)$")
MERMAID_BLOCK_RE = re.compile(
    r'<pre><code class="language-mermaid">(.*?)</code></pre>',
    re.DOTALL,
)
DOUBLE_KEY_INTERVAL_MS = 450
RELOAD_POLL_INTERVAL_MS = 2000
MERMAID_CDN_URL = "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs"


@dataclass
class Section:
    index: int
    level: int
    title: str
    heading_anchor: str
    filename: str
    body: str


@dataclass(frozen=True)
class FilePage:
    source_path: Path
    output_relpath: str


def slugify(value: str) -> str:
    slug = re.sub(r"[^\w\s-]", "", value.lower(), flags=re.UNICODE)
    slug = re.sub(r"[-\s]+", "-", slug).strip("-")
    return slug or "slide"


def parse_sections(text: str) -> list[tuple[int, str, list[str]]]:
    sections: list[tuple[int, str, list[str]]] = []
    current: tuple[int, str, list[str]] | None = None
    in_fence = False
    fence_marker = ""

    for line in text.splitlines():
        fence_match = FENCE_RE.match(line)
        if fence_match:
            marker = fence_match.group(2)
            if not in_fence:
                in_fence = True
                fence_marker = marker[0]
            elif marker[0] == fence_marker:
                in_fence = False
                fence_marker = ""

        if not in_fence:
            heading_match = HEADING_RE.match(line)
            if heading_match:
                if current is not None:
                    sections.append(current)
                current = (len(heading_match.group(1)), heading_match.group(2).strip(), [])
                continue

        if current is not None:
            current[2].append(line)

    if current is not None:
        sections.append(current)

    return sections


def build_sections(raw_sections: Iterable[tuple[int, str, list[str]]]) -> list[Section]:
    sections: list[Section] = []
    anchor_counts: dict[str, int] = {}

    raw_list = list(raw_sections)

    for index, (level, title, body_lines) in enumerate(raw_list, start=1):
        base_anchor = slugify(title)
        suffix = anchor_counts.get(base_anchor, 0)
        anchor_counts[base_anchor] = suffix + 1
        heading_anchor = base_anchor if suffix == 0 else f"{base_anchor}-{suffix}"
        filename = f"{heading_anchor}.html"
        body = "\n".join(body_lines).strip()
        sections.append(
            Section(
                index=index,
                level=level,
                title=title,
                heading_anchor=heading_anchor,
                filename=filename,
                body=body,
            )
        )

    return sections


def build_heading_map(sections: Iterable[Section]) -> dict[str, str]:
    return {section.heading_anchor: section.filename for section in sections}


def build_file_page_relpath(source_dir: Path, source_target: Path) -> str:
    relative = source_target.relative_to(source_dir)
    return str(Path("files") / relative.parent / f"{relative.name}.html")


class LinkRewriter(Treeprocessor):
    def __init__(
        self,
        md: markdown.Markdown,
        heading_map: dict[str, str],
        output_dir: Path,
        source_dir: Path,
        file_pages: dict[Path, FilePage],
    ):
        super().__init__(md)
        self.heading_map = heading_map
        self.output_dir = output_dir
        self.source_dir = source_dir
        self.file_pages = file_pages

    def run(self, root):  # type: ignore[override]
        for element in root.iter():
            for attribute in ("href", "src"):
                target = element.get(attribute)
                if not target:
                    continue
                rewritten = self.rewrite_target(target, attribute)
                if rewritten != target:
                    element.set(attribute, rewritten)
        return root

    def rewrite_target(self, target: str, attribute: str) -> str:
        if target.startswith(("http://", "https://", "mailto:", "data:", "javascript:", "//")):
            return target

        if target.startswith("#"):
            return self.heading_map.get(target[1:], target)

        path_part, fragment = urldefrag(target)
        posix_path = PurePosixPath(path_part)

        if path_part in {"README.md", "./README.md"} and fragment in self.heading_map:
            return self.heading_map[fragment]

        rewritten_path = path_part
        if not posix_path.is_absolute():
            source_target = (self.source_dir / Path(path_part)).resolve()
            try:
                relative_target = source_target.relative_to(self.source_dir)
            except ValueError:
                relative_target = None

            if relative_target is not None and source_target.is_file():
                if attribute == "src":
                    rewritten_path = os.path.relpath(source_target, self.output_dir)
                else:
                    output_relpath = build_file_page_relpath(self.source_dir, source_target)
                    self.file_pages[source_target] = FilePage(
                        source_path=source_target,
                        output_relpath=output_relpath,
                    )
                    rewritten_path = output_relpath
            else:
                rewritten_path = os.path.relpath(source_target, self.output_dir)

        if fragment:
            return f"{rewritten_path}#{fragment}"
        return rewritten_path


class LinkRewriterExtension(Extension):
    def __init__(self, **kwargs):
        self.config = {
            "heading_map": [{}, "Mapping from heading anchors to generated files"],
            "output_dir": [Path("."), "Directory containing generated HTML files"],
            "source_dir": [Path("."), "Directory containing the Markdown source file"],
            "file_pages": [{}, "Mapping for generated local file viewer pages"],
        }
        super().__init__(**kwargs)

    def extendMarkdown(self, md: markdown.Markdown) -> None:
        processor = LinkRewriter(
            md=md,
            heading_map=self.getConfig("heading_map"),
            output_dir=self.getConfig("output_dir"),
            source_dir=self.getConfig("source_dir"),
            file_pages=self.getConfig("file_pages"),
        )
        md.treeprocessors.register(processor, "slide_link_rewriter", 15)


def markdown_to_html(
    source: str,
    heading_map: dict[str, str],
    output_dir: Path,
    source_dir: Path,
    file_pages: dict[Path, FilePage],
) -> str:
    converter = markdown.Markdown(
        extensions=[
            "fenced_code",
            "tables",
            "sane_lists",
            LinkRewriterExtension(
                heading_map=heading_map,
                output_dir=output_dir,
                source_dir=source_dir,
                file_pages=file_pages,
            ),
        ]
    )
    return converter.convert(source)


def render_mermaid_blocks(article_html: str) -> tuple[str, bool]:
    has_mermaid = False

    def replace(match: re.Match[str]) -> str:
        nonlocal has_mermaid
        has_mermaid = True
        diagram_source = html.unescape(match.group(1)).strip()
        return f'<div class="mermaid">{diagram_source}</div>'

    return MERMAID_BLOCK_RE.sub(replace, article_html), has_mermaid


def mermaid_bootstrap_script(has_mermaid: bool) -> str:
    if not has_mermaid:
        return ""

    return f"""
<script type="module">
if (!new URLSearchParams(window.location.search).has('__slide_probe__')) {{
  try {{
    const {{ default: mermaid }} = await import({MERMAID_CDN_URL!r});
    mermaid.initialize({{
      startOnLoad: false,
      theme: 'neutral',
    }});
    await mermaid.run({{ querySelector: '.mermaid' }});
  }} catch (error) {{
    console.error('Failed to render Mermaid diagram.', error);
  }}
}}
</script>
""".strip()


def page_script(prev_href: str | None, next_href: str | None, home_href: str = "index.html") -> str:
    prev_js = "null" if prev_href is None else repr(prev_href)
    next_js = "null" if next_href is None else repr(next_href)
    return f"""
<script>
(() => {{
  const prevHref = {prev_js};
  const nextHref = {next_js};
  const homeHref = {home_href!r};
  const thresholdMs = {DOUBLE_KEY_INTERVAL_MS};
  const reloadPollMs = {RELOAD_POLL_INTERVAL_MS};
  const probeParam = '__slide_probe__';
  const isProbe = new URLSearchParams(window.location.search).has(probeParam);
  let lastKey = null;
  let lastAt = 0;
  let currentSignature = null;
  let probeFrame = null;

  function documentSignature() {{
    const source = document.documentElement.outerHTML;
    let hash = 5381;
    for (let index = 0; index < source.length; index += 1) {{
      hash = ((hash << 5) + hash + source.charCodeAt(index)) | 0;
    }}
    return `${{document.lastModified}}:${{source.length}}:${{hash}}`;
  }}

  if (isProbe) {{
    if (window.parent && window.parent !== window) {{
      window.parent.postMessage({{
        type: 'slide-probe-signature',
        pathname: window.location.pathname,
        signature: documentSignature(),
      }}, '*');
    }}
    return;
  }}

  function isEditable(target) {{
    if (!(target instanceof HTMLElement)) return false;
    return target.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName);
  }}

  function navigate(href) {{
    if (href) {{
      window.location.href = href;
    }}
  }}

  function responseSignature(response, text) {{
    const etag = response.headers.get('etag');
    const lastModified = response.headers.get('last-modified');
    const length = response.headers.get('content-length');
    return JSON.stringify({{
      etag,
      lastModified,
      length,
      textLength: text.length,
      prefix: text.slice(0, 256),
    }});
  }}

  async function fetchSignature() {{
    const url = new URL(window.location.href);
    url.searchParams.set('__slide_reload__', String(Date.now()));
    const response = await fetch(url, {{
      method: 'GET',
      cache: 'no-store',
      headers: {{
        'Cache-Control': 'no-cache',
      }},
    }});
    if (!response.ok) {{
      throw new Error(`Unexpected status ${{response.status}}`);
    }}
    const text = await response.text();
    return responseSignature(response, text);
  }}

  async function watchForChanges() {{
    if (window.location.protocol === 'file:') {{
      probeFrame = document.createElement('iframe');
      probeFrame.setAttribute('aria-hidden', 'true');
      probeFrame.tabIndex = -1;
      probeFrame.style.position = 'fixed';
      probeFrame.style.width = '0';
      probeFrame.style.height = '0';
      probeFrame.style.opacity = '0';
      probeFrame.style.pointerEvents = 'none';
      probeFrame.style.border = '0';
      document.body.appendChild(probeFrame);

      window.addEventListener('message', (event) => {{
        if (!event.data || event.data.type !== 'slide-probe-signature') {{
          return;
        }}
        if (event.data.pathname !== window.location.pathname) {{
          return;
        }}

        if (currentSignature === null) {{
          currentSignature = event.data.signature;
          return;
        }}

        if (event.data.signature !== currentSignature) {{
          window.location.reload();
        }}
      }});

      const loadProbe = () => {{
        const url = new URL(window.location.href);
        url.searchParams.set(probeParam, String(Date.now()));
        probeFrame.src = url.toString();
      }};

      loadProbe();
      window.setInterval(loadProbe, reloadPollMs);
      return;
    }}

    if (!window.fetch) {{
      return;
    }}

    try {{
      currentSignature = await fetchSignature();
    }} catch (_error) {{
      return;
    }}

    window.setInterval(async () => {{
      try {{
        const nextSignature = await fetchSignature();
        if (currentSignature !== null && nextSignature !== currentSignature) {{
          window.location.reload();
          return;
        }}
        currentSignature = nextSignature;
      }} catch (_error) {{
        // Ignore transient polling failures and keep trying.
      }}
    }}, reloadPollMs);
  }}

  document.addEventListener('keydown', (event) => {{
    if (isEditable(event.target)) return;

    const key = event.key;
    if (key === 'Home' || event.code === 'Home') {{
      event.preventDefault();
      navigate(homeHref);
      return;
    }}

    if (key !== 'PageDown' && key !== 'PageUp') {{
      lastKey = null;
      return;
    }}

    const now = performance.now();
    const isDoublePress = lastKey === key && (now - lastAt) <= thresholdMs;
    lastKey = key;
    lastAt = now;

    if (!isDoublePress) {{
      return;
    }}

    event.preventDefault();
    if (key === 'PageDown') {{
      navigate(nextHref);
      return;
    }}

    navigate(prevHref);
  }});

  watchForChanges();
}})();
</script>
""".strip()


def generated_warning_css(bg: str, ink: str, border: str) -> str:
    return f"""
    .generated-warning {{
      margin: 1rem 0;
      padding: 1rem 1.25rem;
      border: 3px solid {border};
      border-radius: 1rem;
      background: {bg};
      color: {ink};
      font-family: "Avenir Next", "Segoe UI", sans-serif;
      font-size: 1rem;
      font-weight: 800;
      letter-spacing: 0.03em;
      text-transform: uppercase;
      text-align: center;
    }}

    .generated-warning strong {{
      display: block;
      margin-bottom: 0.2rem;
      font-size: 1.05rem;
    }}

    .generated-warning span {{
      display: block;
      font-size: 0.88rem;
      font-weight: 700;
      letter-spacing: 0.02em;
      text-transform: none;
    }}
    """.strip()


def render_generated_warning() -> str:
    return """
    <div class="generated-warning" role="note" aria-label="Generated file warning">
      <strong>Generated File: Do Not Edit Directly</strong>
      <span>Edit the source files and rerun the generator.</span>
    </div>
    """.strip()


def generated_file_comment() -> str:
    return """<!--
###############################################################################
# GENERATED FILE - DO NOT EDIT DIRECTLY
# Edit the source files and rerun the generator instead.
###############################################################################
-->"""


def wrap_generated_html(document: str) -> str:
    warning = generated_file_comment()
    return f"{warning}\n{document}\n{warning}\n"


def render_page(
    section: Section,
    article_html: str,
    prev_href: str | None,
    next_href: str | None,
    has_mermaid: bool,
) -> str:
    nav_prev = (
        f'<a class="nav-link" href="{html.escape(prev_href)}" rel="prev">Previous</a>'
        if prev_href
        else '<span class="nav-link disabled">Previous</span>'
    )
    nav_next = (
        f'<a class="nav-link" href="{html.escape(next_href)}" rel="next">Next</a>'
        if next_href
        else '<span class="nav-link disabled">Next</span>'
    )

    return wrap_generated_html(f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(section.title)} | Git Tips Slides</title>
  <style>
    :root {{
      color-scheme: light;
      --bg: #f7f1e4;
      --bg-accent: #efe5d1;
      --paper: rgba(255, 252, 246, 0.96);
      --ink: #1f2328;
      --muted: #5b5f67;
      --line: rgba(31, 35, 40, 0.12);
      --link: #0057b8;
      --link-hover: #0a72e8;
      --code-bg: #f2e8d8;
      --shadow: 0 18px 48px rgba(60, 43, 14, 0.12);
    }}

    * {{
      box-sizing: border-box;
    }}

    html {{
      scroll-behavior: smooth;
    }}

    body {{
      margin: 0;
      font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", Palatino, serif;
      color: var(--ink);
      background:
        radial-gradient(circle at top left, rgba(255, 255, 255, 0.75), transparent 36rem),
        linear-gradient(180deg, var(--bg) 0%, var(--bg-accent) 100%);
      line-height: 1.65;
    }}

    .shell {{
      width: min(72rem, calc(100vw - 2rem));
      margin: 0 auto;
      padding: 1.5rem 0 3rem;
    }}

    .topbar {{
      display: flex;
      flex-wrap: wrap;
      gap: 0.75rem;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 1rem;
      color: var(--muted);
      font-family: "Avenir Next", "Segoe UI", sans-serif;
      font-size: 0.95rem;
    }}

    .frame {{
      background: var(--paper);
      border: 1px solid var(--line);
      border-radius: 1.5rem;
      box-shadow: var(--shadow);
      overflow: hidden;
    }}

    .nav {{
      display: flex;
      gap: 0.75rem;
      justify-content: space-between;
      align-items: center;
      padding: 1rem 1.25rem;
      border-bottom: 1px solid var(--line);
      background: rgba(255, 255, 255, 0.55);
      font-family: "Avenir Next", "Segoe UI", sans-serif;
    }}

    .nav-group {{
      display: flex;
      flex-wrap: wrap;
      gap: 0.75rem;
      align-items: center;
    }}

    .nav-link {{
      color: var(--link);
      text-decoration: none;
      font-weight: 600;
    }}

    .nav-link:hover {{
      color: var(--link-hover);
      text-decoration: underline;
    }}

    .disabled {{
      color: var(--muted);
      opacity: 0.7;
    }}

    article {{
      padding: clamp(1.25rem, 3vw, 2.75rem);
      font-size: clamp(1rem, 0.92rem + 0.32vw, 1.15rem);
    }}

    article > :first-child {{
      margin-top: 0;
    }}

    h1, h2, h3, h4, h5, h6 {{
      line-height: 1.15;
      margin: 1.5em 0 0.6em;
      font-family: "Avenir Next Condensed", "Segoe UI", sans-serif;
      letter-spacing: 0.01em;
    }}

    h1 {{
      font-size: clamp(2rem, 1.55rem + 2vw, 3.35rem);
      margin-top: 0;
    }}

    h2 {{
      font-size: clamp(1.5rem, 1.25rem + 1.1vw, 2.25rem);
    }}

    h3 {{
      font-size: clamp(1.25rem, 1.1rem + 0.7vw, 1.7rem);
    }}

    a {{
      color: var(--link);
    }}

    a:hover {{
      color: var(--link-hover);
    }}

    code {{
      font-family: "JetBrains Mono", "SFMono-Regular", Consolas, monospace;
      font-size: 0.92em;
      background: var(--code-bg);
      border-radius: 0.35rem;
      padding: 0.08em 0.35em;
    }}

    pre {{
      background: #211d1a;
      color: #f9f4ec;
      padding: 1rem;
      border-radius: 1rem;
      overflow-x: auto;
      box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.06);
    }}

    pre code {{
      background: transparent;
      padding: 0;
      color: inherit;
    }}

    blockquote {{
      margin: 1.5rem 0;
      padding: 0.25rem 1rem;
      border-left: 0.35rem solid #d4b16a;
      color: var(--muted);
      background: rgba(212, 177, 106, 0.08);
    }}

    table {{
      width: 100%;
      border-collapse: collapse;
      margin: 1.5rem 0;
      font-size: 0.96em;
    }}

    th, td {{
      padding: 0.7rem 0.8rem;
      border: 1px solid var(--line);
      vertical-align: top;
    }}

    th {{
      background: rgba(0, 0, 0, 0.035);
      text-align: left;
    }}

    img {{
      max-width: 100%;
      height: auto;
    }}

    ul, ol {{
      padding-left: 1.4rem;
    }}

    .hint {{
      color: var(--muted);
      font-size: 0.94rem;
    }}

    {generated_warning_css(bg="#ffe8a3", ink="#442c00", border="#b7791f")}

    .mermaid {{
      margin: 1.5rem 0;
      padding: 1rem;
      border: 1px solid var(--line);
      border-radius: 1rem;
      background: rgba(255, 255, 255, 0.45);
      overflow-x: auto;
      white-space: pre-wrap;
      font-family: "JetBrains Mono", "SFMono-Regular", Consolas, monospace;
      font-size: 0.95rem;
    }}

    .mermaid[data-processed="true"] {{
      padding: 0;
      border: 0;
      background: transparent;
      white-space: normal;
      font-family: inherit;
      font-size: inherit;
    }}

    .mermaid svg {{
      max-width: 100%;
      height: auto;
    }}

    @media (max-width: 700px) {{
      .shell {{
        width: min(100vw - 1rem, 72rem);
        padding-top: 0.75rem;
      }}

      .nav {{
        padding: 0.9rem 1rem;
      }}

      article {{
        padding: 1rem;
      }}
    }}
  </style>
</head>
  <body>
  <div class="shell">
    {render_generated_warning()}
    <div class="topbar">
      <div>Git Tips Slides</div>
      <div class="hint">PageUp x2: previous · PageDown x2: next · Home: index</div>
    </div>
    <div class="frame">
      <nav class="nav" aria-label="Slide navigation">
        <div class="nav-group">
          <a class="nav-link" href="index.html">Index</a>
          {nav_prev}
          {nav_next}
        </div>
        <div class="hint">Slide {section.index}</div>
      </nav>
      <article>
        {article_html}
      </article>
    </div>
    {render_generated_warning()}
  </div>
  {page_script(prev_href=prev_href, next_href=next_href)}
  {mermaid_bootstrap_script(has_mermaid)}
</body>
</html>
""")


def render_index(sections: list[Section]) -> str:
    items = []
    for section in sections:
        margin = (section.level - 1) * 1.1
        items.append(
            f'<li style="margin-left: {margin:.1f}rem">'
            f'<a href="{html.escape(section.filename)}">{html.escape(section.title)}</a>'
            f'<span class="meta">Slide {section.index}</span>'
            f"</li>"
        )

    return wrap_generated_html(f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Git Tips Slides</title>
  <style>
    :root {{
      color-scheme: light;
      --bg: #14213d;
      --panel: rgba(255, 248, 235, 0.98);
      --ink: #1f2328;
      --muted: #5f646d;
      --line: rgba(20, 33, 61, 0.12);
      --link: #0057b8;
      --link-hover: #1c7df0;
      --accent: #fca311;
      --shadow: 0 28px 72px rgba(0, 0, 0, 0.22);
    }}

    * {{
      box-sizing: border-box;
    }}

    body {{
      margin: 0;
      min-height: 100vh;
      color: var(--ink);
      background:
        radial-gradient(circle at top right, rgba(252, 163, 17, 0.18), transparent 25rem),
        linear-gradient(135deg, #0f172a 0%, var(--bg) 55%, #283c63 100%);
      font-family: "Avenir Next", "Segoe UI", sans-serif;
    }}

    main {{
      width: min(78rem, calc(100vw - 2rem));
      margin: 0 auto;
      padding: clamp(1rem, 4vw, 3rem) 0 3rem;
    }}

    .hero {{
      background: var(--panel);
      border-radius: 1.75rem;
      box-shadow: var(--shadow);
      overflow: hidden;
      border: 1px solid var(--line);
    }}

    .hero-head {{
      padding: clamp(1.5rem, 3vw, 2.5rem);
      background:
        linear-gradient(135deg, rgba(252, 163, 17, 0.18), rgba(255, 255, 255, 0)),
        linear-gradient(180deg, rgba(20, 33, 61, 0.03), rgba(20, 33, 61, 0));
      border-bottom: 1px solid var(--line);
    }}

    h1 {{
      margin: 0 0 0.5rem;
      font-size: clamp(2rem, 1.2rem + 3vw, 4rem);
      line-height: 0.98;
      font-family: "Avenir Next Condensed", "Segoe UI", sans-serif;
    }}

    p {{
      margin: 0;
      color: var(--muted);
      font-size: clamp(1rem, 0.96rem + 0.3vw, 1.15rem);
    }}

    .start {{
      display: inline-block;
      margin-top: 1rem;
      padding: 0.75rem 1rem;
      border-radius: 999px;
      background: var(--accent);
      color: #111827;
      font-weight: 700;
      text-decoration: none;
    }}

    .start:hover {{
      filter: brightness(1.03);
    }}

    ol {{
      list-style: none;
      margin: 0;
      padding: 1rem clamp(1rem, 3vw, 2.5rem) clamp(1.5rem, 3vw, 2.5rem);
      columns: 2 22rem;
      column-gap: 2rem;
    }}

    li {{
      break-inside: avoid;
      padding: 0.45rem 0;
      border-bottom: 1px solid rgba(20, 33, 61, 0.06);
    }}

    a {{
      color: var(--link);
      text-decoration: none;
      font-weight: 600;
    }}

    a:hover {{
      color: var(--link-hover);
      text-decoration: underline;
    }}

    .meta {{
      margin-left: 0.65rem;
      color: var(--muted);
      font-size: 0.92rem;
      white-space: nowrap;
    }}

    .hint {{
      margin-top: 0.9rem;
      color: var(--muted);
      font-size: 0.95rem;
    }}

    {generated_warning_css(bg="#ffe8a3", ink="#442c00", border="#b7791f")}

    @media (max-width: 700px) {{
      main {{
        width: min(100vw - 1rem, 78rem);
        padding-top: 0.5rem;
      }}

      ol {{
        columns: 1;
      }}
    }}
  </style>
</head>
<body>
  <main>
    {render_generated_warning()}
    <section class="hero">
      <div class="hero-head">
        <h1>Git Tips</h1>
        <p>Generated from README.md. Each heading becomes a page, with quick keyboard navigation for reading.</p>
        <p class="hint">PageDown x2 jumps to the next slide. PageUp x2 goes back. Home keeps you on this index.</p>
        <a class="start" href="{html.escape(sections[0].filename)}">Start Reading</a>
      </div>
      <ol>
        {''.join(items)}
      </ol>
    </section>
    {render_generated_warning()}
  </main>
  {page_script(prev_href=None, next_href=sections[0].filename)}
</body>
</html>
""")


def render_file_page(file_page: FilePage, output_dir: Path, source_dir: Path) -> str:
    source_label = str(file_page.source_path.relative_to(source_dir))
    raw_href = os.path.relpath(file_page.source_path, output_dir / Path(file_page.output_relpath).parent)
    file_content = file_page.source_path.read_text(encoding="utf-8", errors="replace")

    return wrap_generated_html(f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(source_label)} | Git Tips File View</title>
  <style>
    :root {{
      color-scheme: light;
      --bg: #0f172a;
      --panel: #111827;
      --ink: #e5e7eb;
      --muted: #9ca3af;
      --line: rgba(255, 255, 255, 0.12);
      --link: #7dd3fc;
      --code-bg: #020617;
    }}

    * {{
      box-sizing: border-box;
    }}

    body {{
      margin: 0;
      min-height: 100vh;
      color: var(--ink);
      background:
        radial-gradient(circle at top right, rgba(125, 211, 252, 0.08), transparent 20rem),
        linear-gradient(180deg, var(--bg), #020617);
      font-family: "Avenir Next", "Segoe UI", sans-serif;
    }}

    main {{
      width: min(84rem, calc(100vw - 1rem));
      margin: 0 auto;
      padding: 1rem 0 2rem;
    }}

    .panel {{
      background: rgba(17, 24, 39, 0.9);
      border: 1px solid var(--line);
      border-radius: 1rem;
      overflow: hidden;
    }}

    .topbar {{
      display: flex;
      justify-content: space-between;
      gap: 1rem;
      align-items: center;
      padding: 1rem 1.25rem;
      border-bottom: 1px solid var(--line);
    }}

    .title {{
      font-weight: 700;
    }}

    .meta {{
      color: var(--muted);
      font-size: 0.95rem;
    }}

    a {{
      color: var(--link);
    }}

    pre {{
      margin: 0;
      padding: 1.25rem;
      overflow-x: auto;
      background: var(--code-bg);
      color: var(--ink);
      font-family: "JetBrains Mono", "SFMono-Regular", Consolas, monospace;
      font-size: 0.95rem;
      line-height: 1.5;
    }}

    {generated_warning_css(bg="#facc15", ink="#1f2937", border="#f59e0b")}
  </style>
</head>
<body>
  <main>
    {render_generated_warning()}
    <section class="panel">
      <div class="topbar">
        <div>
          <div class="title">{html.escape(source_label)}</div>
          <div class="meta">Generated viewer for local file links from slides</div>
        </div>
        <div><a href="{html.escape(raw_href)}">Raw file</a></div>
      </div>
      <pre><code>{html.escape(file_content)}</code></pre>
    </section>
    {render_generated_warning()}
  </main>
</body>
</html>
""")


def build_markdown_source(section: Section) -> str:
    source = f"{'#' * section.level} {section.title}\n"
    if section.body:
        source += f"\n{section.body}\n"
    return source


def prepare_output_dir(output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)


def write_if_changed(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text(encoding="utf-8") == content:
        return
    path.write_text(content, encoding="utf-8")


def remove_obsolete_html_files(output_dir: Path, expected_names: set[str]) -> None:
    for old_file in output_dir.rglob("*.html"):
        relative_name = old_file.relative_to(output_dir).as_posix()
        if relative_name not in expected_names:
            old_file.unlink()


def write_output(readme_path: Path, output_dir: Path) -> None:
    readme_path = readme_path.resolve()
    output_dir = output_dir.resolve()
    raw_sections = parse_sections(readme_path.read_text(encoding="utf-8"))
    sections = build_sections(raw_sections)
    if not sections:
        raise SystemExit(f"No Markdown headings found in {readme_path}")

    prepare_output_dir(output_dir)
    heading_map = build_heading_map(sections)
    file_pages: dict[Path, FilePage] = {}
    expected_names = {section.filename for section in sections}
    expected_names.add("index.html")

    for offset, section in enumerate(sections):
        prev_href = sections[offset - 1].filename if offset > 0 else None
        next_href = sections[offset + 1].filename if offset + 1 < len(sections) else None
        markdown_source = build_markdown_source(section)
        article_html = markdown_to_html(
            markdown_source,
            heading_map=heading_map,
            output_dir=output_dir,
            source_dir=readme_path.parent,
            file_pages=file_pages,
        )
        article_html, has_mermaid = render_mermaid_blocks(article_html)
        page_html = render_page(
            section,
            article_html=article_html,
            prev_href=prev_href,
            next_href=next_href,
            has_mermaid=has_mermaid,
        )
        write_if_changed(output_dir / section.filename, page_html)

    write_if_changed(output_dir / "index.html", render_index(sections))
    for file_page in file_pages.values():
        expected_names.add(Path(file_page.output_relpath).as_posix())
        write_if_changed(
            output_dir / file_page.output_relpath,
            render_file_page(file_page, output_dir, readme_path.parent),
        )
    remove_obsolete_html_files(output_dir, expected_names)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate HTML slides from a Markdown README.")
    parser.add_argument(
        "--input",
        default="README.md",
        type=Path,
        help="Path to the Markdown file to convert.",
    )
    parser.add_argument(
        "--output-dir",
        default=Path("slides"),
        type=Path,
        help="Directory for generated HTML files.",
    )
    args = parser.parse_args()
    write_output(readme_path=args.input, output_dir=args.output_dir)


if __name__ == "__main__":
    main()
