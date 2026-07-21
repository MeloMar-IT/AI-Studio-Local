# Pixar-Style Character LoRA — Reference Set & Prompts

Built from the 5 reference photos (front, back, two profiles, front-smiling). This document gives you everything needed to generate a stylized image set with your image generator of choice (Midjourney, GPT-Image, SDXL/ComfyUI, Leonardo, etc.), then train a character LoRA from the results.

> Note: I don't have an image-generation tool connected in this session, so I can't render these images myself. This package is the prompt/production plan — run each prompt below through your generator to build the actual image set.

---

## 1. Identity Reference (extracted from your photos)

- Adult male, late 50s–60s
- Long, straight, light ash-blonde hair, center-parted, thinning/receding at the crown, reaching past the shoulders
- Full, neatly trimmed white-and-grey beard and mustache
- Fair skin, high forehead, average-to-heavier build
- Rectangular, thin wire-frame glasses with a light amber/gold tint
- Calm, neutral resting expression; warm slight smile when posed
- Everyday outfit in source photos: soft peach/salmon graphic t-shirt (samurai-cat print), black jeans, black shoes

For the LoRA, keep the **face, hair, beard, glasses, and build** identical across every generated image — that consistency is what the LoRA will learn. Clothing, background, lighting, and expression should **vary** from shot to shot (see Section 3) so the model learns the character, not a specific outfit or scene.

---

## 2. Master Character Prompt (Pixar Style)

Use this as the fixed "core" block in every generation — paste it in full, then append the shot-specific variation from Section 3.

**Core character block:**

```
Pixar-style 3D animated character, a stylized portrait of a middle-aged man in his early 60s,
long straight light-blonde hair center-parted and thinning at the crown, reaching past the
shoulders, full neatly-trimmed white and grey beard and mustache, fair skin with soft stylized
shading, rectangular thin wire-frame glasses with a warm amber tint, kind expressive eyes,
high forehead, warm approachable "favorite uncle" character design, rounded soft proportions,
clean smooth 3D animation topology, Pixar/Disney animation studio character render, soft
global illumination, subsurface scattering skin, vibrant warm color palette, high detail,
octane render, cinematic character turnaround quality
```

**Negative prompt (avoid):**

```
photorealistic, realistic skin pores, uncanny valley, horror, deformed hands, extra fingers,
asymmetrical face, blurry, low detail, flat lighting, anime style, 2D flat illustration,
text, watermark, logo
```

**Consistency tip:** if your tool supports a character/seed reference (Midjourney `--cref`, SDXL IP-Adapter, ComfyUI face-lock, etc.), lock the seed or reference image after your first good generation and reuse it across every shot in Section 3 — this keeps facial identity far more consistent than prompt text alone.

---

## 3. Reference Shot List (30 prompts)

Append each line below to the Master Character Prompt. This mix of angles, expressions, framing, and lighting is what a video character LoRA needs to generalize well.

### Angles — neutral expression, plain grey studio background (8)
1. `, front-facing portrait, looking directly at camera, neutral expression`
2. `, three-quarter view from the left, neutral expression`
3. `, three-quarter view from the right, neutral expression`
4. `, full left profile view, neutral expression`
5. `, full right profile view, neutral expression`
6. `, back view, three-quarter, showing hair and shoulders`
7. `, slightly low camera angle looking up at the character, neutral expression`
8. `, slightly high camera angle looking down at the character, neutral expression`

### Expressions — front-facing, studio background (8)
9. `, front-facing, warm smiling expression, eyes crinkled`
10. `, front-facing, laughing expression, mouth open`
11. `, front-facing, surprised expression, eyebrows raised`
12. `, front-facing, thoughtful expression, one eyebrow raised, hand near chin`
13. `, front-facing, concerned/worried expression`
14. `, front-facing, calm closed-mouth smile`
15. `, front-facing, mid-speech expression, mouth slightly open as if talking`
16. `, front-facing, wink, playful expression`

### Framing variety — neutral expression (6)
17. `, extreme close-up headshot, shoulders not visible`
18. `, close-up bust portrait, shoulders visible`
19. `, half-body shot, hands visible, standing`
20. `, full-body shot, standing straight, arms relaxed`
21. `, full-body shot, walking pose, mid-stride`
22. `, full-body, sitting pose, relaxed`

### Lighting variety — front three-quarter angle (4)
23. `, soft studio lighting, even and diffused`
24. `, warm golden-hour outdoor lighting, soft shadows`
25. `, dramatic rim lighting from behind, moody`
26. `, cool blue evening lighting`

### Outfit variety — front-facing, neutral background (4, optional but recommended for generalization)
27. `, wearing a simple plain grey crew-neck t-shirt`
28. `, wearing a casual button-up shirt, sleeves rolled`
29. `, wearing a cozy knit sweater`
30. `, wearing the original peach graphic t-shirt with a samurai cat print, black jeans` *(signature outfit from your source photos — include 1–2 shots if you want the LoRA able to reproduce this specific look)*

---

## 4. Building the LoRA Dataset

- **Count:** 30 images is a strong minimum for a character LoRA; 40–60 is better if you have generation budget — add more angle/expression combinations from Section 3 by mixing rows.
- **Resolution:** generate at 1024×1024 (SDXL) or your video model's native resolution; keep a consistent aspect ratio across the set where possible.
- **File naming:** simple sequential, e.g. `char_001.png` … `char_030.png`.
- **Captions:** create a matching `.txt` file per image (same basename) with a short caption using a unique trigger token, e.g.:
  `char_007.png` → `char_007.txt`:
  ```
  ohwx man, front-facing portrait, warm smiling expression, pixar style
  ```
  Pick a rare token like `ohwx` or `zksman` as the trigger so it doesn't collide with existing model vocabulary. Keep captions short and consistent — describe pose/expression/lighting (what varies), not the fixed identity traits (what should always be there).
- **Curation pass before training:** discard any generation with face drift, extra fingers, or broken glasses/hair — a few bad images hurt a small character LoRA more than having fewer total images.
- **Training settings (typical starting point for SDXL/video character LoRA):** rank 16–32, 1500–2500 steps, learning rate ~1e-4 (unet), batch size 1–2 with gradient accumulation. Adjust to your specific trainer (Kohya, OneTrainer, or your video model's native LoRA trainer).

---

## 5. Ready-to-Use Character Prompt (for reuse after training)

Once trained, use the trigger token plus a trimmed version of the identity description to invoke the character in new generations/video:

```
ohwx man, Pixar-style 3D animated character, warm approachable middle-aged man, long
light-blonde hair thinning at the crown, full white and grey beard, rectangular amber-tinted
glasses, kind expressive eyes, Pixar/Disney animation render, soft cinematic lighting
```
