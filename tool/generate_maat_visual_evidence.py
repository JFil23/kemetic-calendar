#!/usr/bin/env python3
"""Build mockup-to-Flutter visual evidence without accepting new baselines.

HTML screenshots are captured separately from the eight supplied authorities.
Flutter screenshots are the actual production widgets exercised by widget tests.
This tool only pairs those independent renders and produces inspectable evidence;
it never updates either side of the comparison.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageChops, ImageEnhance, ImageOps


@dataclass(frozen=True)
class Pair:
    state: str
    golden: str
    authority: str
    scope: str
    html_content_top_inset: int = 0
    mask_top: int = 0


PAIRS = (
    Pair("djed-detail-hero", "djed-detail-390x844.png", "djed-detail", "full detail viewport"),
    Pair("djed-detail-supports", "djed-detail-supports-390x844.png", "djed-detail", "support editor scroll checkpoint"),
    Pair("djed-detail-support-2-selected", "djed-detail-support-2-selected-390x844.png", "djed-detail", "support 2 selected in row and spine"),
    Pair("djed-day-view", "djed-day-view-390x844.png", "djed-day", "authored event block in Day View"),
    Pair("djed-day-sheet", "djed-day-sheet-390x844.png", "djed-day", "initial shared instrument sheet"),
    Pair("djed-day-sheet-docked", "djed-day-sheet-practice-raised-production-390x844.png", "djed-day", "foreground practice content raised"),
    Pair("djed-day-result", "djed-day-result-390x720.png", "djed-day", "result state"),
    Pair("djed-day-retry", "djed-day-retry-390x720.png", "djed-day", "smaller retry state"),
    Pair("djed-day-raising", "djed-day-raising-390x720.png", "djed-day", "final raising state"),
    Pair("reading-house-detail-hero", "reading-house-detail-390x844.png", "reading-house-detail", "full detail hero viewport"),
    Pair("reading-house-detail-setup", "reading-house-detail-setup-390x844.png", "reading-house-detail", "setup scroll checkpoint"),
    Pair("reading-house-detail-calendar", "reading-house-detail-calendar-390x844.png", "reading-house-detail", "calendar scroll checkpoint"),
    Pair("reading-house-detail-sittings", "reading-house-detail-sittings-390x844.png", "reading-house-detail", "sittings scroll checkpoint"),
    Pair("reading-house-inbox", "reading-house-inbox-390x844.png", "reading-house-inbox", "accepted House Inbox cell"),
    Pair("reading-house-inbox-pending", "reading-house-inbox-pending-invite-390x844.png", "reading-house-inbox", "pending invitation sub-sheet"),
    Pair("reading-house-inbox-chat", "reading-house-inbox-chat-390x844.png", "reading-house-inbox", "House Chat sub-sheet"),
    Pair("reading-house-day-view", "reading-house-day-view-390x844.png", "reading-house-day", "authored event block in Day View", mask_top=47),
    Pair("reading-house-day-sheet", "reading-house-day-sheet-390x844.png", "reading-house-day", "initial shared Ma'at Day View housing", mask_top=47),
    Pair("reading-house-day-sheet-docked", "reading-house-day-sheet-body-390x844.png", "reading-house-day", "foreground House practice raised", mask_top=47),
    Pair("reading-house-day-sheet-bottom", "reading-house-day-sheet-bottom-390x844.png", "reading-house-day", "House practice scrolled to bottom", mask_top=47),
    Pair("reading-house-day-incoming", "reading-house-day-sheet-incoming-390x720.png", "reading-house-day", "incoming-message state"),
    Pair("reading-house-day-complete", "reading-house-day-sheet-complete-390x720.png", "reading-house-day", "Observed completion selected"),
    Pair("offering-day-view", "offering-table-day-view-390x844.png", "offering-day", "authored event block in Day View", mask_top=47),
    Pair("offering-day-sheet", "offering-table-day-sheet-initial-390x844.png", "offering-day", "initial shared Ma'at Day View housing", mask_top=47),
    Pair("offering-day-sheet-docked", "offering-table-day-sheet-raised-390x844.png", "offering-day", "foreground ritual content raised", mask_top=47),
    Pair("offering-day-sheet-bottom", "offering-table-day-sheet-body-390x844.png", "offering-day", "ritual card scrolled to lower controls", mask_top=47),
    Pair("offering-day-sheet-context", "offering-table-day-sheet-context-390x844.png", "offering-day", "expanded context disclosure", mask_top=47),
    Pair("offering-detail", "offering-table-detail-390x844.png", "offering-detail", "full detail viewport"),
    Pair("offering-detail-sheet", "offering-table-detail-ritual-sheet-390x844.png", "offering-detail", "preview ritual sheet"),
    Pair("offering-detail-context", "offering-table-detail-ritual-body-390x844.png", "offering-detail", "preview context disclosure"),
    Pair("offering-detail-complete", "offering-table-detail-ritual-complete-390x844.png", "offering-detail", "preview completion state"),
    Pair("discovery", "maat-flow-discovery-390x844.png", "discovery", "Follow the Sky and list opening", mask_top=32),
    Pair("discovery-offering", "maat-flow-discovery-offering-390x844.png", "discovery", "Offering Table discovery card", 32),
    Pair("discovery-reading-house", "maat-flow-discovery-reading-house-390x844.png", "discovery", "Reading House discovery card", 32),
)


AUTHORITIES = {
    "djed-detail": "djed-detail-page-v12-ember-eventblocks.html",
    "djed-day": "djed-day-view-amber-v8-exact-eventblock.html",
    "reading-house-detail": "reading-house-detail-featured-scroll-icon.html",
    "reading-house-inbox": "reading-house-inbox-invites-mockup-v4.html",
    "reading-house-day": "reading-house-day-view-v16.html",
    "offering-day": "offering-table-day-view-bottom-detail-sheet-layered-v8.html",
    "offering-detail": "offering-table-bottom-sheet-ritual-first-mockup (7).html",
    "discovery": "maat-flow-discovery-copy-v3.html",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def metrics(reference: Image.Image, app: Image.Image) -> dict[str, float | int]:
    diff = ImageChops.difference(reference.convert("RGB"), app.convert("RGB"))
    histogram = diff.histogram()
    samples = reference.width * reference.height * 3
    absolute_sum = sum((index % 256) * count for index, count in enumerate(histogram))
    changed = sum(
        1
        for pixel in diff.get_flattened_data()
        if max(pixel) > 8
    )
    return {
        "mean_absolute_channel_error": round(absolute_sum / samples, 4),
        "changed_pixels_over_8": changed,
        "changed_pixel_percent_over_8": round(
            changed * 100 / (reference.width * reference.height), 4
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--html-dir", type=Path, default=Path("/tmp"))
    parser.add_argument(
        "--golden-dir",
        type=Path,
        default=Path("test/visual_reference/maat_flows/goldens"),
    )
    parser.add_argument(
        "--mockup-dir", type=Path, default=Path.home() / "Desktop" / "UI MOCKUPS"
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("test/visual_reference/maat_flows/evidence"),
    )
    args = parser.parse_args()

    for directory in (
        "reference",
        "app",
        "normalized_reference",
        "normalized_app",
        "overlay",
        "difference",
        "contact",
    ):
        (args.output_dir / directory).mkdir(parents=True, exist_ok=True)

    authority_hashes = {
        key: {
            "file": filename,
            "sha256": sha256(args.mockup_dir / filename),
        }
        for key, filename in AUTHORITIES.items()
    }
    results: list[dict[str, object]] = []

    for pair in PAIRS:
        height = 720 if pair.golden.endswith("390x720.png") else 844
        reference_source = args.html_dir / f"html-exact-{pair.state}-390x{height}.png"
        app_source = args.golden_dir / pair.golden
        if not reference_source.is_file():
            raise FileNotFoundError(reference_source)
        if not app_source.is_file():
            raise FileNotFoundError(app_source)

        reference = Image.open(reference_source).convert("RGB")
        app = Image.open(app_source).convert("RGB")
        if reference.size != app.size:
            raise ValueError(
                f"{pair.state}: reference {reference.size} != app {app.size}"
            )

        reference_path = args.output_dir / "reference" / f"{pair.state}.png"
        app_path = args.output_dir / "app" / f"{pair.state}.png"
        shutil.copyfile(reference_source, reference_path)
        shutil.copyfile(app_source, app_path)

        comparison_reference = reference.copy()
        comparison_app = app.copy()
        if pair.html_content_top_inset:
            inset = pair.html_content_top_inset
            comparison_reference = Image.new("RGB", reference.size, "black")
            comparison_reference.paste(
                reference.crop((0, 0, reference.width, reference.height - inset)),
                (0, inset),
            )
            comparison_app.paste(
                Image.new("RGB", (app.width, inset), "black"),
                (0, 0),
            )
        if pair.mask_top:
            mask = Image.new("RGB", (app.width, pair.mask_top), "black")
            comparison_reference.paste(mask, (0, 0))
            comparison_app.paste(mask, (0, 0))
        comparison_reference.save(
            args.output_dir / "normalized_reference" / f"{pair.state}.png"
        )
        comparison_app.save(
            args.output_dir / "normalized_app" / f"{pair.state}.png"
        )

        overlay = Image.blend(comparison_reference, comparison_app, 0.5)
        overlay.save(args.output_dir / "overlay" / f"{pair.state}.png")

        raw_diff = ImageChops.difference(comparison_reference, comparison_app)
        visible_diff = ImageEnhance.Contrast(raw_diff).enhance(4)
        visible_diff = ImageOps.autocontrast(visible_diff, cutoff=0)
        visible_diff.save(args.output_dir / "difference" / f"{pair.state}.png")

        contact = Image.new("RGB", (reference.width * 4, reference.height), "black")
        for column, image in enumerate(
            (comparison_reference, comparison_app, overlay, visible_diff)
        ):
            contact.paste(image, (reference.width * column, 0))
        contact.save(args.output_dir / "contact" / f"{pair.state}.png")

        results.append(
            {
                "state": pair.state,
                "authority": authority_hashes[pair.authority],
                "golden": pair.golden,
                "scope": pair.scope,
                "html_content_top_inset": pair.html_content_top_inset,
                "mask_top": pair.mask_top,
                "size": list(reference.size),
                "metrics": metrics(comparison_reference, comparison_app),
            }
        )

    report = {
        "method": {
            "reference": "rendered from supplied HTML plus deterministic state driver",
            "app": "actual production Flutter screen/widget rendered by widget test; Day View states use DayViewPage rather than an isolated grid",
            "normalization": "Only mock phone/status chrome is excluded: Discovery reserves the app's 32 px OS safe area, while Reading House and Offering Table Day View comparisons mask the shared 47 px status-bar area on both sides. No authored app surface is resized, recolored, blurred, or masked.",
            "overlay": "50/50 HTML and Flutter blend",
            "difference": "absolute RGB difference, contrast-amplified for inspection",
            "acceptance": "human inspection of every contact sheet; metrics are diagnostic only",
        },
        "explained_context_differences": [
            {
                "states": ["djed-day-view", "reading-house-day-view", "offering-day-view"],
                "difference": "The raw app captures include the real shared Day View header, mini-calendar behavior, and floating shortcuts. The HTML files use illustrative phone/status glyphs and simplified shared chrome.",
                "reason": "The user explicitly froze shared Day View; acceptance for these authorities governs the authored event block and opened sheet. Raw full-screen captures remain available so the context difference is visible.",
            },
            {
                "states": ["djed-day-view", "djed-day-sheet", "djed-day-sheet-docked"],
                "difference": "The three ordinary context events use production scheduled-event cards in Flutter and simplified unlabeled bars in the HTML fixture.",
                "reason": "Those events are surrounding calendar context, not Djed-authored surfaces. Their titles, times, and colors are retained in the raw app fixture.",
            },
            {
                "states": ["djed-day-sheet", "djed-day-sheet-docked", "djed-day-result", "djed-day-retry", "djed-day-raising"],
                "difference": "The HTML capture uses Djed's older 0.71 layered host, forced 30 px practice peek, decorative inner handle, and three instrument-header sections. Production uses Follow the Sky's 0.58 standard host, the shared frame's authored foreground stop, and only the outer host handle. The sitting/day/phase label, time/duration row, and TODAY/context block are removed entirely, leaving the sitting title, a 12 px gap, and the fixed-size graphic. The Djed stage remains 230 px, or 205 px when the full viewport is at most 720 px, with the 390 x 214 SVG uniformly scaled. The fully lowered stop includes the instrument's top padding, title line, gap, complete stage, and existing 24 px bottom padding, leaving the angle label 32 px clear of the foreground edge and its upward shadow. Unselected supports use the HTML's 34% opacity (78% during orientation); the selected support stays at full opacity with its outline/glow, and each support condition uses its authored gradient. The existing diagonal rise guides render behind the pillar in sittings 3–8 and remain absent in sittings 1, 2, and 9. Raising may cover the stage, and lowering reveals it again.",
                "reason": "The user's corrections explicitly supersede the older Djed sheet and instrument-header composition while retaining the authored title, complete graphic size, support hierarchy and palette, actions, footer, and single shared content scroll.",
            },
            {
                "states": ["djed-day-sheet", "djed-day-sheet-docked", "reading-house-day-sheet", "reading-house-day-sheet-docked", "reading-house-day-sheet-bottom", "offering-day-sheet", "offering-day-sheet-docked", "offering-day-sheet-bottom", "offering-day-sheet-context"],
                "difference": "Follow the Sky is the mechanical housing authority for the four canonical Ma'at Day View sheets. They open at 0.58 with one outer handle, one foreground scroll owner, shared menu/completion/footer placement, and fixed natural-size artwork that is revealed or covered rather than resized. Older per-flow custom extents, inner handles, and nested-layer geometry shown by the HTML are superseded.",
                "reason": "The user's September 17 instruction explicitly standardizes only the canonical Day View housing while preserving each flow's authored artwork, copy, fields, and interactive states. Flow-detail sheets, user-created flows, and Kꜣr are outside this contract.",
            },
            {
                "states": ["offering-day-view", "offering-day-sheet", "offering-day-sheet-docked", "offering-day-sheet-bottom", "offering-day-sheet-context"],
                "difference": "The explicit September 17 correction removes the teaser and embedded 7:30 AM label from every Offering Table event block. The prompt remains in the sheet, calendar placement remains 7:30, and Flutter maps the supplied Kemetic date through canonical calendar math to SAT AUG 29 rather than the HTML's FRI SEP 4.",
                "reason": "The user's event-block correction supersedes the older HTML card copy without changing sheet content, schedule placement, or Gregorian metadata.",
            },
            {
                "states": ["offering-day-view", "offering-day-sheet", "offering-day-sheet-docked", "offering-day-sheet-bottom", "offering-day-sheet-context", "offering-detail", "offering-detail-sheet", "offering-detail-context", "offering-detail-complete"],
                "difference": "Offering Table event blocks use the same solid amber edge rule as Djed instead of the HTML's dotted preview outline.",
                "reason": "The user's September 9 instruction explicitly supersedes the supplied Offering Table border treatment.",
            },
            {
                "states": ["discovery", "discovery-offering", "discovery-reading-house"],
                "difference": "Discovery cards have no separate Open button or reserved button row; the complete card is the accessible tap target.",
                "reason": "The user's September 9 instruction explicitly supersedes the supplied Discovery call-to-action layout and requires its space to collapse.",
            },
            {
                "states": ["reading-house-day-view", "reading-house-day-sheet", "reading-house-day-sheet-docked", "reading-house-day-sheet-bottom"],
                "difference": "The HTML clips a late-day timeline after 9 PM; production Day View keeps midnight reachable and therefore clamps the late-day scroll, leaving the 7 PM block about 24 px lower in the raw viewport.",
                "reason": "The Reading House block remains at 7 PM in both and has matching authored geometry. The difference belongs to frozen shared timeline behavior.",
            },
            {
                "states": ["all"],
                "difference": "Browser CSS and Flutter/Skia have small anti-aliasing and platform-glyph rasterization differences.",
                "reason": "These are reviewed only as renderer artifacts; they do not excuse changed bounds, line breaks, artwork geometry, palette values, copy, or interaction state.",
            },
        ],
        "authorities": authority_hashes,
        "pairs": results,
        "supplemental_product_states": [
            {
                "golden": "djed-day-sheet-practice-raised-390x844.png",
                "reason": "Presentation-frame coverage of the same authored raised state; the direct production-screen comparison uses djed-day-sheet-practice-raised-production-390x844.png.",
            },
            {
                "golden": "djed-day-support-states-390x844.png",
                "reason": "One regression fixture combines the four support-condition gradients authored separately in the Djed HTML CSS; the supplied HTML does not present them together in one captured state.",
            },
            {
                "golden": "reading-house-day-sheet-locked-390x720.png",
                "reason": "Ended/locked write-authority safety state; the supplied HTML does not define it.",
            },
            {
                "golden": "reading-house-day-sheet-ended-390x720.png",
                "reason": "Ended/locked write-authority safety state; the supplied HTML does not define it.",
            },
            {
                "golden": "reading-house-inbox-multiple-390x844.png",
                "reason": "Per-House room multiplicity and isolation; the supplied Inbox HTML contains one House fixture.",
            },
            {
                "golden": "maat-flow-discovery-djed-390x844.png",
                "reason": "The approved four-flow product adds Djed, but the supplied Discovery HTML contains only the other three cards.",
            },
            {
                "golden": "djed-day-released-filled-390x720.png",
                "reason": "The latest explicit user instruction supersedes the older HTML: release remains stored history but every support stays a filled beam, and every sitting renders exactly one pillar with no ghost.",
            },
        ],
    }
    (args.output_dir / "manifest.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )

    lines = [
        "# Ma'at mockup-to-app visual evidence",
        "",
        "Each row pairs an independently rendered supplied HTML state with the actual Flutter widget. The Flutter golden is regression evidence only; it is never used as the visual authority.",
        "",
        "Contact sheets are ordered **HTML reference | Flutter app | 50/50 overlay | amplified absolute difference**.",
        "",
        "The raw captures remain in `reference/` and `app/`. In comparison inputs, only mock phone/status chrome is excluded: Discovery content is aligned below the app's real 32 px OS safe area, and the shared 47 px status-bar area is masked for Reading House and Offering Table Day View states. No authored app surface is resized, recolored, blurred, or masked.",
        "",
        "## Explicitly reviewed context differences",
        "",
        "- The Day View raw app captures now use the real production `DayViewPage`, including its shared header, mini-calendar behavior, and floating shortcuts. The HTML uses illustrative phone/status glyphs and simplified shared chrome. Per the user's frozen-Day-View instruction, direct fidelity authority applies to each authored event block and opened sheet; the full raw context remains visible.",
        "- Djed's three surrounding ordinary events use production scheduled-event cards in Flutter and simplified unlabeled bars in the HTML. Their titles, times, and colors are retained; they are not Djed-authored surfaces.",
        "- The Djed corrections supersede the HTML's older `.71` layered host, forced 30 px practice peek, decorative inner handle, and three instrument-header sections. Production uses Follow the Sky's `.58` standard host, the shared frame's authored foreground stop, and one outer handle. The sitting/day/phase label, time/duration row, and TODAY/context block are absent with no reserved height; the sitting title is followed by a 12 px gap and the graphic. The stage remains 230 px (205 px only when the full viewport is at most 720 px) and never rescales to the remaining sheet height. The fully lowered stop includes the instrument's top padding, title line, gap, complete stage, and existing 24 px bottom padding, leaving the angle label 32 px clear of the foreground edge and its upward shadow. Unselected supports use the HTML's 34% opacity (78% during orientation); the selected support stays at full opacity with its outline/glow, and holding, under-pressure, wobbling, and unassessed supports use their authored gradients. The existing diagonal rise guides appear behind the pillar in sittings 3–8 with unchanged geometry, color, and dash spacing; they remain absent in sittings 1, 2, and 9 and are not beam outlines. Sitting 9 retains the authored radial raising glow. Raising may cover the stage, and lowering reveals it again. At the exact foreground dock the focus heading and primary controls clear the fixed footer; the same single scroll exposes each remaining control above it. Djed's actions, footer, and single shared scroll remain intact. The latest explicit instruction additionally supersedes the HTML's released/ghost state: release remains stored history, but it has no alternate beam treatment; all four beams remain filled and every sitting shows exactly one pillar. That state is a supplemental Flutter visual contract rather than a direct HTML comparison.",
        "- The September 17 product instruction makes Follow the Sky the mechanical housing authority for the four canonical Ma'at Day View sheets: Follow the Sky, Offering Table, Reading House, and Djed. They open at `.58` with one outer handle, one foreground scroll owner, the shared menu/completion/footer placement, and fixed natural-size artwork that is revealed or covered rather than resized. The per-flow HTML remains authoritative for each flow's artwork, copy, fields, and interactive states, but its older custom sheet extent, inner handle, and nested-layer geometry are superseded. Flow-detail sheets, user-created flows, and Kꜣr are outside this housing contract.",
        "- Offering Table's HTML labels the event `7:30 AM` but visually places it near the 9:30 row, and pairs `Rekh-Wer 13` with `FRI SEP 4`. Flutter correctly places it at 7:30 and maps that Kemetic date to `SAT AUG 29` through the canonical calendar. Event-block/sheet visuals follow the HTML; the functioning shared calendar math remains unchanged.",
        "- The September 9 product instruction supersedes two older mockup details: Offering Table event blocks now share Djed's solid amber border rule, and Discovery cards are complete accessible tap targets with no separate `Open` button or reserved button row.",
        "- Reading House's HTML clips the late-day grid after 9 PM. Production Day View keeps midnight reachable, so its clamped late-day viewport places the same 7 PM block about 24 px lower. The block itself retains matching geometry.",
        "- Chromium CSS and Flutter/Skia produce minor anti-aliasing and platform-glyph differences. These do not excuse changed bounds, line breaks, artwork geometry, palette values, copy, or state.",
        "",
        "| State | Authority | Scope | Contact |",
        "| --- | --- | --- | --- |",
    ]
    for pair in PAIRS:
        authority_file = AUTHORITIES[pair.authority]
        lines.append(
            f"| `{pair.state}` | `{authority_file}` | {pair.scope} | [inspect](contact/{pair.state}.png) |"
        )
    lines.extend(
        [
            "",
            "Six additional goldens cover product states the HTML does not author as one capture: Djed's mixed support-condition palette, its approved fourth Discovery card, Reading House locked/ended rooms, Inbox room multiplicity, and a redundant component-frame capture of Djed's authored raised state. They are supplemental regression contracts, not mockup-fidelity evidence.",
            "",
        ]
    )
    (args.output_dir / "README.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {len(results)} direct comparison sets to {args.output_dir}")


if __name__ == "__main__":
    main()
