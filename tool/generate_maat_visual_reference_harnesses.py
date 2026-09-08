#!/usr/bin/env python3
"""Generate deterministic, non-authoritative state drivers for Ma'at HTML refs.

The supplied HTML files remain byte-for-byte untouched.  Each generated file is
an exact copy with one appended script that places the existing mockup in a
named interaction/scroll state.  These files exist only so screenshot evidence
can be reproduced at an exact viewport without accepting Flutter output as the
reference.
"""

from __future__ import annotations

import argparse
from pathlib import Path


SOURCES = {
    "djed-detail": "djed-detail-page-v12-ember-eventblocks.html",
    "djed-day": "djed-day-view-amber-v8-exact-eventblock.html",
    "reading-house-detail": "reading-house-detail-featured-scroll-icon.html",
    "reading-house-inbox": "reading-house-inbox-invites-mockup-v4.html",
    "reading-house-day": "reading-house-day-view-v16.html",
    "offering-day": "offering-table-day-view-bottom-detail-sheet-layered-v8.html",
    "offering-detail": "offering-table-bottom-sheet-ritual-first-mockup (7).html",
    "discovery": "maat-flow-discovery-copy-v3.html",
}


STATES = {
    "djed-detail-hero": ("djed-detail", ""),
    "djed-detail-supports": (
        "djed-detail",
        "viewport.scrollTop=Math.min(820,viewport.scrollHeight-viewport.clientHeight);",
    ),
    "djed-detail-support-2-selected": (
        "djed-detail",
        "setActiveDetailSupport(1,{focus:false});viewport.scrollTop=Math.min(820,viewport.scrollHeight-viewport.clientHeight);",
    ),
    "djed-day-view": ("djed-day", ""),
    "djed-day-sheet": ("djed-day", "openEvent(4);"),
    "djed-day-sheet-docked": (
        "djed-day",
        "openEvent(4);setTimeout(()=>{measureLayeredScroll();setLayeredPos(revealDistance);},80);",
    ),
    "djed-day-result": ("djed-day", "updateFixture(3);openEvent(3);"),
    "djed-day-retry": ("djed-day", "updateFixture(5);openEvent(5);"),
    "djed-day-raising": ("djed-day", "updateFixture(9);openEvent(9);"),
    "reading-house-detail-hero": ("reading-house-detail", ""),
    "reading-house-detail-setup": (
        "reading-house-detail",
        "viewport.scrollTop=Math.min(650,viewport.scrollHeight-viewport.clientHeight);",
    ),
    "reading-house-detail-calendar": (
        "reading-house-detail",
        "viewport.scrollTop=Math.min(1400,viewport.scrollHeight-viewport.clientHeight);",
    ),
    "reading-house-detail-sittings": (
        "reading-house-detail",
        "viewport.scrollTop=Math.min(2300,viewport.scrollHeight-viewport.clientHeight);",
    ),
    "reading-house-inbox": ("reading-house-inbox", ""),
    "reading-house-inbox-pending": (
        "reading-house-inbox",
        "resetDemo();openInvites();",
    ),
    "reading-house-inbox-chat": (
        "reading-house-inbox",
        "showAcceptedHouse();openChat();",
    ),
    "reading-house-day-view": ("reading-house-day", ""),
    "reading-house-day-sheet": (
        "reading-house-day",
        "announcements=['Bring one sentence that changed the way you entered the chapter.'];renderAnnouncements();openSheet();",
    ),
    "reading-house-day-sheet-docked": (
        "reading-house-day",
        "announcements=['Bring one sentence that changed the way you entered the chapter.'];renderAnnouncements();openSheet();setTimeout(()=>{measureLayeredScroll();setLayeredPos(revealDistance);},80);",
    ),
    "reading-house-day-sheet-bottom": (
        "reading-house-day",
        "announcements=['Bring one sentence that changed the way you entered the chapter.'];renderAnnouncements();openSheet();setTimeout(()=>{measureLayeredScroll();setLayeredPos(revealDistance+innerMax);},80);",
    ),
    "reading-house-day-incoming": (
        "reading-house-day",
        "openSheet();setTimeout(()=>{injectIncomingMessage();},80);",
    ),
    "reading-house-day-complete": (
        "reading-house-day",
        "openSheet();document.querySelector('[data-completion=\"Observed\"]').click();setTimeout(()=>{measureLayeredScroll();setLayeredPos(revealDistance+innerMax);},80);",
    ),
    "offering-day-view": ("offering-day", "localStorage.clear();courseState={};"),
    "offering-day-sheet": (
        "offering-day",
        "localStorage.clear();courseState={};openSheet();",
    ),
    "offering-day-sheet-docked": (
        "offering-day",
        "localStorage.clear();courseState={};openSheet();setTimeout(()=>{measureLayeredScroll();setLayeredPos(revealDistance);},80);",
    ),
    "offering-day-sheet-bottom": (
        "offering-day",
        "localStorage.clear();courseState={};openSheet();setTimeout(()=>{measureLayeredScroll();setLayeredPos(revealDistance+innerMax);},80);",
    ),
    "offering-day-sheet-context": (
        "offering-day",
        "localStorage.clear();courseState={};openSheet();setTimeout(()=>{measureLayeredScroll();setLayeredPos(revealDistance+innerMax);contextBtn.click();},80);",
    ),
    "offering-detail": (
        "offering-detail",
        "localStorage.clear();courseState={};renderAllDays();",
    ),
    "offering-detail-sheet": (
        "offering-detail",
        "localStorage.clear();courseState={};openPractice(1);",
    ),
    "offering-detail-context": (
        "offering-detail",
        "localStorage.clear();courseState={};openPractice(1);practice.ctxBtn.click();",
    ),
    "offering-detail-complete": (
        "offering-detail",
        "localStorage.clear();courseState={};openPractice(1);const supply=practice.fields.querySelector('[data-field-slot=\"supply\"]');supply.value='medication';supply.dispatchEvent(new Event('input',{bubbles:true}));supply.dispatchEvent(new Event('blur',{bubbles:true}));practice.moves.querySelector('[data-move-action=\"refill\"]').click();practice.moves.querySelector('[data-move-action=\"visible\"]').click();practice.ctxBtn.click();setTimeout(()=>{practice.sheet.scrollTop=practice.returned.offsetTop-120;},80);",
    ),
    "discovery": ("discovery", ""),
    "discovery-offering": (
        "discovery",
        "document.querySelector('[data-haw-flow=\"offering\"]').scrollIntoView({block:'start'});",
    ),
    "discovery-reading-house": (
        "discovery",
        "const spacer=document.createElement('div');spacer.style.height='844px';spacer.setAttribute('aria-hidden','true');document.body.appendChild(spacer);document.querySelector('[data-haw-flow=\"reading\"]').scrollIntoView({block:'start'});",
    ),
}


def state_script(source: str) -> str:
    if not source:
        return ""
    return (
        "\n<script>window.addEventListener('load',()=>setTimeout(()=>{"
        + source
        + "},120));</script>\n"
    )


def normalize_fragment(source_key: str, html: str) -> str:
    if source_key == "offering-detail":
        normalization = """<style>
html,body{margin:0!important;padding:0!important;background:#000!important}
.phone{width:100vw!important;height:100dvh!important;border-radius:0!important;box-shadow:none!important}
</style>
"""
        return html.replace("</head>", normalization + "</head>", 1)
    if source_key != "discovery":
        return html
    # The discovery authority is an embeddable fragment rather than a full
    # document. Supply only the missing UTF-8 host and remove its demonstrator
    # phone frame; neither adjustment changes the authored app surface.
    return """<!doctype html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
html,body{margin:0;background:#000}
#haw-maat-discovery-v3{padding:0!important}
#haw-maat-discovery-v3 .haw-phone{border:0!important;border-radius:0!important}
</style></head><body>
""" + html + "\n</body></html>\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--mockup-dir",
        type=Path,
        default=Path.home() / "Desktop" / "UI MOCKUPS",
    )
    parser.add_argument(
        "--output-dir", type=Path, default=Path("/tmp/maat-html-harness")
    )
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    for state_name, (source_key, driver) in STATES.items():
        source_path = args.mockup_dir / SOURCES[source_key]
        html = normalize_fragment(
            source_key, source_path.read_text(encoding="utf-8")
        )
        target = args.output_dir / f"{state_name}.html"
        target.write_text(html + state_script(driver), encoding="utf-8")
        print(target)


if __name__ == "__main__":
    main()
