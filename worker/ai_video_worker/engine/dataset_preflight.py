"""
Pre-training dataset quality check for character LoRA training.

Runs entirely on the raw list of image paths the app is about to send to
POST /train/lora (TrainingRequest.training_data_paths), before any training
job is actually created. Nothing here writes anything to disk or touches the
trainer -- it's read-only analysis meant to catch problems that either
(a) crash training outright, (b) silently produce a LoRA that's learned
nothing, or (c) just make for a worse LoRA than the images could otherwise
support.

These checks are grounded in how ltx_trainer_mlx actually behaves (see
preprocess.py / trainer.py in the ltx-trainer package), not generic advice:
  - No aspect-ratio bucketing: each image is independently resized to its own
    floor(h/32)*32 x floor(w/32)*32. Mixing resolutions/aspect ratios means
    two images can land in the same training batch with different tensor
    shapes, which crashes _collate_batch's mx.stack call mid-training.
  - _simple_dataloader drops the last incomplete batch every epoch. With the
    trainer's default batch_size=2, an odd image count (or a count smaller
    than batch_size) can silently produce zero training batches per epoch --
    the job "succeeds" having learned nothing, with no error anywhere.
  - Captions are written as just the trigger word (see
    ltx_training_wrapper.prepare_dataset) -- the LoRA is never invoked at
    generation time unless that exact word is in the prompt.
  - No dataset validation exists anywhere in the trainer today; this module
    is the first line of defense the app has before submitting a job.
"""
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional, Tuple

from PIL import Image

DEFAULT_BATCH_SIZE = 2
MIN_RECOMMENDED_IMAGES = 15
LOW_IMAGE_WARNING_THRESHOLD = 10
CRITICAL_IMAGE_THRESHOLD = 5
# Out of 64 bits in the average-hash below. Empirically, near-identical
# images (e.g. consecutive video frames) land well under 5; unrelated photos
# of the same subject are usually 15+.
NEAR_DUPLICATE_HAMMING_THRESHOLD = 5


@dataclass
class Finding:
    severity: str  # "critical" | "warning" | "info"
    message: str


@dataclass
class PreflightResult:
    score: int
    image_count: int
    valid_image_count: int
    findings: List[Finding] = field(default_factory=list)
    recommendation: str = ""


def _average_hash(image: Image.Image) -> int:
    """
    8x8 grayscale average hash. Deliberately simple (no extra dependency
    beyond Pillow, which the worker already requires) -- good enough to flag
    near-identical consecutive video frames or accidental duplicate imports,
    not meant to be a rigorous perceptual-hash implementation.
    """
    small = image.convert("L").resize((8, 8), Image.Resampling.LANCZOS)
    pixels = list(small.getdata())
    avg = sum(pixels) / len(pixels)
    bits = 0
    for i, p in enumerate(pixels):
        if p > avg:
            bits |= (1 << i)
    return bits


def _hamming_distance(a: int, b: int) -> int:
    return bin(a ^ b).count("1")


def analyze_training_dataset(
    image_paths: List[str],
    trigger_word: Optional[str] = None,
    batch_size: int = DEFAULT_BATCH_SIZE,
    description: Optional[str] = None,
) -> PreflightResult:
    findings: List[Finding] = []
    score = 100

    # --- Load what we can, and flag anything that's already broken ---
    valid_images: List[Tuple[str, Image.Image]] = []
    missing: List[str] = []
    unreadable: List[Tuple[str, str]] = []
    for p in image_paths:
        path = Path(p)
        if not path.exists():
            missing.append(p)
            continue
        try:
            with Image.open(path) as img:
                img.load()
                valid_images.append((p, img.copy()))
        except Exception as e:
            unreadable.append((p, str(e)))

    if missing:
        score -= 25
        findings.append(Finding(
            "critical",
            f"{len(missing)} image path(s) don't exist on disk and will fail training: "
            + ", ".join(Path(m).name for m in missing[:5]) + ("..." if len(missing) > 5 else "")
        ))
    if unreadable:
        score -= 25
        findings.append(Finding(
            "critical",
            f"{len(unreadable)} image(s) couldn't be opened/decoded (corrupt or unsupported format): "
            + ", ".join(Path(p).name for p, _ in unreadable[:5]) + ("..." if len(unreadable) > 5 else "")
        ))

    image_count = len(image_paths)
    valid_count = len(valid_images)

    if valid_count == 0:
        findings.append(Finding("critical", "No usable images -- training cannot proceed."))
        return PreflightResult(
            score=0, image_count=image_count, valid_image_count=0,
            findings=findings, recommendation="Add valid training images before continuing."
        )

    # --- Image count ---
    if valid_count < CRITICAL_IMAGE_THRESHOLD:
        score -= 30
        findings.append(Finding(
            "critical",
            f"Only {valid_count} image(s). This is very likely to produce an overfit, unreliable LoRA. "
            f"Aim for at least {MIN_RECOMMENDED_IMAGES}."
        ))
    elif valid_count < LOW_IMAGE_WARNING_THRESHOLD:
        score -= 15
        findings.append(Finding(
            "warning",
            f"Only {valid_count} images. {MIN_RECOMMENDED_IMAGES}+ with varied poses/angles/lighting "
            f"usually generalizes noticeably better."
        ))
    elif valid_count < MIN_RECOMMENDED_IMAGES:
        score -= 5
        findings.append(Finding(
            "info",
            f"{valid_count} images is workable but on the low side; {MIN_RECOMMENDED_IMAGES}+ tends to help."
        ))

    # --- Batch-size divisibility (silent zero-batch training) ---
    if valid_count < batch_size:
        score -= 30
        findings.append(Finding(
            "critical",
            f"With only {valid_count} image(s) and a training batch size of {batch_size}, the trainer "
            f"will silently run with zero batches per epoch -- it will finish and report success, but "
            f"the LoRA won't have learned anything. Add at least {batch_size} images."
        ))
    elif valid_count % batch_size != 0:
        dropped = valid_count % batch_size
        needed = batch_size - dropped
        score -= 5
        findings.append(Finding(
            "warning",
            f"{valid_count} images isn't a multiple of the training batch size ({batch_size}); "
            f"{dropped} image(s) will be dropped from every epoch. Add or remove {needed} "
            f"image(s) to use all of them."
        ))

    # --- Resolution / aspect-ratio consistency ---
    buckets = {}
    for p, img in valid_images:
        w, h = img.size
        bucket = ((h // 32) * 32, (w // 32) * 32)
        buckets.setdefault(bucket, []).append(p)

    if len(buckets) > 1:
        score -= 25
        bucket_summary = ", ".join(f"{h}x{w} ({len(paths)} image(s))" for (h, w), paths in buckets.items())
        findings.append(Finding(
            "critical",
            f"Images resize to {len(buckets)} different resolutions after training's automatic rounding "
            f"({bucket_summary}). The trainer has no aspect-ratio bucketing, so mixed resolutions in the "
            f"same batch can crash training partway through. Crop/resize all images to the same aspect ratio."
        ))

    # --- Near-duplicate detection ---
    hashes = [(p, _average_hash(img)) for p, img in valid_images]
    near_dupe_pairs = 0
    flagged_paths = set()
    for i in range(len(hashes)):
        for j in range(i + 1, len(hashes)):
            if _hamming_distance(hashes[i][1], hashes[j][1]) <= NEAR_DUPLICATE_HAMMING_THRESHOLD:
                near_dupe_pairs += 1
                flagged_paths.add(hashes[i][0])
                flagged_paths.add(hashes[j][0])

    if near_dupe_pairs > 0:
        total_pairs = max(1, valid_count * (valid_count - 1) / 2)
        ratio = near_dupe_pairs / total_pairs
        deduction = 20 if ratio > 0.3 else 10
        score -= deduction
        findings.append(Finding(
            "warning",
            f"{len(flagged_paths)} image(s) look like near-duplicates of another image in the set "
            f"({near_dupe_pairs} similar pair(s), e.g. consecutive video frames). These can dominate "
            f"training instead of teaching general appearance. Consider thinning them out."
        ))

    # --- Trigger word ---
    if not trigger_word or not trigger_word.strip():
        score -= 20
        findings.append(Finding(
            "critical",
            "No trigger word set. Captions are written as just this word, and generation prompts must "
            "include it to invoke the trained identity -- without it the LoRA will train but never "
            "visibly affect generations."
        ))
    elif description and description.strip():
        findings.append(Finding(
            "info",
            f"Captions will be \"{trigger_word}, {description.strip()}\". Combining the trigger word with "
            f"a description generally helps the LoRA separate \"this is the character\" from "
            f"\"this is the pose/background\"."
        ))
    else:
        findings.append(Finding(
            "info",
            f"Captions will be written as just the trigger word (\"{trigger_word}\") -- no description is "
            f"set on this element. Adding one generally helps the LoRA separate \"this is the character\" "
            f"from \"this is the pose/background\"."
        ))

    score = max(0, min(100, score))

    if score >= 85:
        recommendation = "Looks solid -- safe to start training."
    elif score >= 60:
        recommendation = "Workable, but addressing the warnings above will likely improve the result."
    elif score >= 35:
        recommendation = "Risky. Review the issues above -- some could produce a broken or low-quality LoRA."
    else:
        recommendation = "Not recommended to proceed as-is -- see the critical issues above."

    return PreflightResult(
        score=score,
        image_count=image_count,
        valid_image_count=valid_count,
        findings=findings,
        recommendation=recommendation,
    )
