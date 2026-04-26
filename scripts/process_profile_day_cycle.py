#!/usr/bin/env python3

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, "/tmp/codex_cv2")
sys.path.insert(0, "/tmp/codex_pillow")

import cv2
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "assets/profile/day_cycle"
OUTPUT_DIR = ROOT / "assets/profile/day_cycle_registered_v3"
JPEG_OUTPUT_DIR = ROOT / "assets/profile/day_cycle_registered_v3_jpg"
PRIMARY_NIGHT_DIR = ROOT / "assets/profile/PRIMARY"
PRIMARY_NIGHT_IMAGE_NAME = "primary_night_pyramid.png"
ANCHOR_NAME = "12am.png"

FRAME_ORDER = [
    "12am.png",
    "1am.png",
    "2am.png",
    "3am.png",
    "4am.png",
    "5am.png",
    "6am.png",
    "7am.png",
    "8am.png",
    "9am.png",
    "10am.png",
    "11am.png",
    "12pm.png",
    "1pm.png",
    "2pm.png",
    "3pm.png",
    "4pm.png",
    "5pm.png",
    "6pm.png",
    "7pm.png",
    "8pm.png",
    "9pm.png",
    "10pm.png",
    "11pm.png",
]

FIT_CENTERING = {
    "7pm.png": (0.5, 0.43),
}

# Use adjacent real night images to ease stars out during predawn.
STAR_BLEND = {
    "5am.png": ("4am.png", 0.08),
}

NIGHT_PYRAMID_FRAMES = {
    "8pm.png",
    "9pm.png",
    "10pm.png",
    "11pm.png",
    "12am.png",
    "1am.png",
    "2am.png",
    "3am.png",
    "4am.png",
    "5am.png",
}

EARLY_NIGHT_STAR_BLEND = {
    "8pm.png": 0.56,
    "9pm.png": 0.78,
}


def gradient_mask(
    size: tuple[int, int],
    start_y: float,
    end_y: float,
    top_alpha: float,
    bottom_alpha: float,
) -> Image.Image:
    width, height = size
    mask = Image.new("L", (1, height))
    pixels = []
    for y in range(height):
        t = y / max(1, height - 1)
        if t <= start_y:
            alpha = top_alpha
        elif t >= end_y:
            alpha = bottom_alpha
        else:
            local_t = (t - start_y) / (end_y - start_y)
            alpha = (top_alpha * (1 - local_t)) + (bottom_alpha * local_t)
        pixels.append(int(max(0.0, min(1.0, alpha)) * 255))
    mask.putdata(pixels)
    return mask.resize((width, height))


def horizontal_gradient_mask(
    size: tuple[int, int],
    start_x: float,
    end_x: float,
    left_alpha: float,
    right_alpha: float,
) -> Image.Image:
    width, height = size
    mask = Image.new("L", (width, 1))
    pixels = []
    for x in range(width):
        t = x / max(1, width - 1)
        if t <= start_x:
            alpha = left_alpha
        elif t >= end_x:
            alpha = right_alpha
        else:
            local_t = (t - start_x) / (end_x - start_x)
            alpha = (left_alpha * (1 - local_t)) + (right_alpha * local_t)
        pixels.append(int(max(0.0, min(1.0, alpha)) * 255))
    mask.putdata(pixels)
    return mask.resize((width, height))


def build_sky_mask(size: tuple[int, int]) -> Image.Image:
    width, height = size
    polygon = [
        (0, 0),
        (width, 0),
        (width, int(height * 0.60)),
        (int(width * 0.86), int(height * 0.54)),
        (int(width * 0.62), int(height * 0.54)),
        (int(width * 0.56), int(height * 0.48)),
        (int(width * 0.23), 0),
    ]
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon(polygon, fill=255)
    return mask.filter(ImageFilter.GaussianBlur(16))


def build_alignment_mask(size: tuple[int, int]) -> np.ndarray:
    width, height = size
    mask = np.zeros((height, width), dtype=np.uint8)
    mask[:, : int(width * 0.62)] = 255
    mask[int(height * 0.58) :, :] = 255
    return mask


def build_pyramid_mask(size: tuple[int, int]) -> Image.Image:
    width, height = size
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon(
        [
            (0, int(height * 0.01)),
            (int(width * 0.228), int(height * 0.01)),
            (int(width * 0.544), int(height * 0.701)),
            (int(width * 0.548), int(height * 0.779)),
            (0, int(height * 0.886)),
        ],
        fill=255,
    )
    draw.polygon(
        [
            (int(width * 0.500), int(height * 0.673)),
            (int(width * 0.559), int(height * 0.673)),
            (int(width * 0.587), int(height * 0.770)),
            (int(width * 0.529), int(height * 0.787)),
            (int(width * 0.476), int(height * 0.722)),
        ],
        fill=220,
    )
    return mask.filter(ImageFilter.GaussianBlur(3))


def build_upper_right_sky_mask(size: tuple[int, int], sky_mask: Image.Image) -> Image.Image:
    return multiply_masks(
        sky_mask,
        gradient_mask(
            size,
            start_y=0.0,
            end_y=0.60,
            top_alpha=1.0,
            bottom_alpha=0.0,
        ),
        horizontal_gradient_mask(
            size,
            start_x=0.40,
            end_x=0.66,
            left_alpha=0.0,
            right_alpha=1.0,
        ),
    ).filter(ImageFilter.GaussianBlur(18))


def build_star_field_overlay(image: Image.Image) -> Image.Image:
    high_pass = ImageChops.subtract(
        image.convert("RGB"),
        image.convert("RGB").filter(ImageFilter.GaussianBlur(24)),
    )
    return high_pass.point(lambda value: min(255, int(value * 2.4)))


def multiply_masks(*masks: Image.Image) -> Image.Image:
    result = masks[0]
    for mask in masks[1:]:
        result = ImageChops.multiply(result, mask)
    return result


def fit_to_anchor(image: Image.Image, target_size: tuple[int, int], name: str) -> Image.Image:
    centering = FIT_CENTERING.get(name, (0.5, 0.5))
    if image.size == target_size:
        return image.convert("RGB")
    return ImageOps.fit(
        image.convert("RGB"),
        target_size,
        method=Image.Resampling.LANCZOS,
        centering=centering,
    )


def align_to_anchor(
    image: Image.Image,
    anchor_image: Image.Image,
    alignment_mask: np.ndarray,
) -> Image.Image:
    anchor_rgb = np.array(anchor_image.convert("RGB"))
    source_rgb = np.array(image.convert("RGB"))

    anchor_gray = cv2.cvtColor(anchor_rgb, cv2.COLOR_RGB2GRAY).astype(np.float32) / 255.0
    source_gray = cv2.cvtColor(source_rgb, cv2.COLOR_RGB2GRAY).astype(np.float32) / 255.0

    warp = np.eye(2, 3, dtype=np.float32)
    criteria = (
        cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT,
        600,
        1e-7,
    )

    try:
        _, warp = cv2.findTransformECC(
            anchor_gray,
            source_gray,
            warp,
            cv2.MOTION_AFFINE,
            criteria,
            alignment_mask,
            5,
        )
        aligned_rgb = cv2.warpAffine(
            source_rgb,
            warp,
            (anchor_rgb.shape[1], anchor_rgb.shape[0]),
            flags=cv2.INTER_LINEAR + cv2.WARP_INVERSE_MAP,
            borderMode=cv2.BORDER_REPLICATE,
        )
        return Image.fromarray(aligned_rgb, mode="RGB")
    except cv2.error:
        return image.convert("RGB")


def screen_blend(base: Image.Image, overlay: Image.Image, mask: Image.Image) -> Image.Image:
    screened = ImageChops.screen(base.convert("RGB"), overlay.convert("RGB"))
    return Image.composite(screened, base.convert("RGB"), mask)


def composite_with_mask(
    base: Image.Image,
    overlay: Image.Image,
    mask: Image.Image,
) -> Image.Image:
    return Image.composite(overlay.convert("RGB"), base.convert("RGB"), mask)


def resolve_primary_night_image_path() -> Path | None:
    preferred = PRIMARY_NIGHT_DIR / PRIMARY_NIGHT_IMAGE_NAME
    if preferred.exists():
        return preferred

    candidates: list[Path] = []
    for pattern in ("*.png", "*.jpg", "*.jpeg", "*.webp"):
        candidates.extend(sorted(PRIMARY_NIGHT_DIR.glob(pattern)))
    if not candidates:
        return None
    return candidates[0]


def main() -> None:
    anchor_image = Image.open(SOURCE_DIR / ANCHOR_NAME).convert("RGB")
    target_size = anchor_image.size

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    JPEG_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    sky_mask = build_sky_mask(target_size)
    pyramid_mask = build_pyramid_mask(target_size)
    alignment_mask = build_alignment_mask(target_size)
    primary_night_path = resolve_primary_night_image_path()
    primary_night_image = anchor_image
    if primary_night_path is not None:
        primary_night_image = align_to_anchor(
            fit_to_anchor(Image.open(primary_night_path), target_size, primary_night_path.name),
            anchor_image,
            alignment_mask,
        )
    twilight_fade = gradient_mask(
        target_size,
        start_y=0.0,
        end_y=0.74,
        top_alpha=1.0,
        bottom_alpha=0.0,
    )
    star_mask = multiply_masks(sky_mask, twilight_fade)
    early_night_star_mask = build_upper_right_sky_mask(target_size, sky_mask)
    primary_night_star_field = build_star_field_overlay(primary_night_image)

    processed_cache: dict[str, Image.Image] = {}
    aligned_cache: dict[str, Image.Image] = {}

    for frame_name in FRAME_ORDER:
        source_path = SOURCE_DIR / frame_name
        fitted = fit_to_anchor(Image.open(source_path), target_size, frame_name)
        aligned_cache[frame_name] = (
            anchor_image if frame_name == ANCHOR_NAME else align_to_anchor(fitted, anchor_image, alignment_mask)
        )

    for frame_name, processed in aligned_cache.items():
        output_image = processed

        if frame_name in NIGHT_PYRAMID_FRAMES:
            output_image = composite_with_mask(
                output_image,
                primary_night_image,
                pyramid_mask,
            )

        if frame_name in EARLY_NIGHT_STAR_BLEND:
            output_image = screen_blend(
                output_image,
                primary_night_star_field,
                early_night_star_mask.point(
                    lambda value, alpha=EARLY_NIGHT_STAR_BLEND[frame_name]: int(value * alpha)
                ),
            )

        if frame_name in STAR_BLEND:
            overlay_name, alpha = STAR_BLEND[frame_name]
            overlay_image = aligned_cache[overlay_name]
            overlay_mask = star_mask.point(lambda value: int(value * alpha))
            output_image = screen_blend(output_image, overlay_image, overlay_mask)
        processed_cache[frame_name] = output_image

    for frame_name, processed in processed_cache.items():
        output_path = OUTPUT_DIR / frame_name
        processed.save(output_path, format="PNG", optimize=True)
        jpg_output_path = JPEG_OUTPUT_DIR / f"{Path(frame_name).stem}.jpg"
        processed.save(
            jpg_output_path,
            format="JPEG",
            quality=96,
            subsampling=0,
            optimize=True,
        )
        print(output_path.relative_to(ROOT))


if __name__ == "__main__":
    main()
