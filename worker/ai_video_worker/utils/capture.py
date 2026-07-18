import sys
import io
import re
from typing import Callable, Optional

from ai_video_worker.logging_config import logger

class ProgressStreamInterceptor(io.TextIOBase):
    def __init__(self, original_stream, callback: Callable[[str], None]):
        self.original_stream = original_stream
        self.callback = callback
        self._buffer = ""

    def write(self, s):
        try:
            self.original_stream.write(s)
        except Exception:
            pass
        self._buffer += s
        if '\n' in self._buffer:
            lines = self._buffer.split('\n')
            for line in lines[:-1]:
                try:
                    self.callback(line)
                except Exception as e:
                    logger.debug(f"Progress callback failed: {e}")
            self._buffer = lines[-1]
        return len(s)

    def flush(self):
        self.original_stream.flush()

class MLXProgressParser:
    def __init__(self, progress_callback: Optional[Callable[[str, float, str], None]]):
        self.progress_callback = progress_callback
        self.current_stage = "preparing_inputs"
        self._highest_stage_rank = 0
        self._job_logger = None

        # Rank stages to ensure strict monotonicity
        self._stage_ranks = {
            "preparing_prompt": 1,
            "checking_hardware": 2,
            "loading_model": 3,
            "preparing_inputs": 4,
            "generating_video": 5,
            "generating_audio": 6,
            "upscaling": 7,
            "decoding": 8,
            "encoding_output": 9,
            "saving_metadata": 10,
            "completed": 11,
            "failed": 12,
            "cancelled": 13
        }

        # Regex patterns for mlx-video v0.1.36
        self.stage_step_re = re.compile(r"STAGE:(\d+):STEP:(\d+):(\d+):Denoising")
        self.text_encoder_re = re.compile(r"TEXT_ENCODER:EVAL_CHUNK:(\d+):(\d+):(\d+)")
        self.vae_decode_re = re.compile(r"VAE:DECODE:STEP:(\d+):(\d+)")

    def set_job_logger(self, job_logger: Optional[Callable[[str], None]]):
        self._job_logger = job_logger

    def _log_job(self, message: str):
        if self._job_logger:
            try:
                self._job_logger(message)
            except Exception:
                pass

    def _emit_progress(self, stage: str, progress: float, message: str):
        if not self.progress_callback:
            return

        new_rank = self._stage_ranks.get(stage, 0)

        # If we are just starting generating_video, emit a prefix message
        if stage == "generating_video" and self._highest_stage_rank < self._stage_ranks["generating_video"]:
             self.progress_callback("generating_video", 0.15, "Starting unified AV generation (this can take several minutes)...")

        # Don't go backwards in major stages
        if new_rank < self._highest_stage_rank:
            # If we are in generating_video but get a preparing_inputs event,
            # keep it as generating_video but maybe update the message if helpful,
            # or just ignore it to avoid UI jitter.
            return

        self._highest_stage_rank = max(self._highest_stage_rank, new_rank)
        self.current_stage = stage
        self.progress_callback(stage, progress, message)

    def parse_line(self, line: str):
        # Capture enhanced prompt if present
        if line.startswith("ENHANCED_PROMPT:"):
            enhanced_prompt = line[len("ENHANCED_PROMPT:"):].strip()
            logger.info(f"MLXLTXAdapter: Captured ENHANCED PROMPT: '{enhanced_prompt}'")
            self._log_job(f"MLXLTXAdapter: Captured ENHANCED PROMPT: '{enhanced_prompt}'")

        if not self.progress_callback:
            return

        # Text Encoder Progress (roughly 10% to 15%)
        te_match = self.text_encoder_re.search(line)
        if te_match:
            chunk = int(te_match.group(1))
            total = int(te_match.group(2))

            # mlx-video v0.1.36 has multiple phases with different totals.
            # We track the maximum chunk seen so far to keep progress monotonic
            # and use a weighted average if total changes, or just a safe clamp.

            # Simple fix: if chunk > total (happens in multi-pass), cap it at total.
            # But really we should know which pass we are in.
            # Given the logs, we have passes with total=1, 16, 16, 3, 1, 16, 16, 13, 13...

            # Better heuristic: just use (chunk/total) and clamp to 1.0,
            # then map to the 10-15% range. This prevents 105% values.
            safe_ratio = min(1.0, chunk / total) if total > 0 else 0
            progress = 0.10 + (safe_ratio * 0.05)
            self._emit_progress("preparing_inputs", progress, f"Encoding text prompt (chunk {chunk}/{total})...")
            return

        # Stage/Step Progress (roughly 15% to 85%)
        ss_match = self.stage_step_re.search(line)
        if ss_match:
            stage = int(ss_match.group(1))
            step = int(ss_match.group(2))
            total_steps = int(ss_match.group(3))

            if stage == 1:
                # Stage 1: 15% to 50%
                progress = 0.15 + (step / total_steps) * 0.35
                self._emit_progress("generating_video", progress, f"Denoising Stage 1: Step {step}/{total_steps}...")
            elif stage == 2:
                # Stage 2: 50% to 85%
                progress = 0.50 + (step / total_steps) * 0.35
                self._emit_progress("generating_video", progress, f"Denoising Stage 2: Step {step}/{total_steps}...")
            return

        # VAE Decoding (roughly 85% to 92%)
        vd_match = self.vae_decode_re.search(line)
        if vd_match:
            step = int(vd_match.group(1))
            total = int(vd_match.group(2))
            progress = 0.85 + (step / total) * 0.07
            self._emit_progress("decoding", progress, f"Decoding video frames ({step}/{total})...")
            return

        if "VAE:DECODE:START" in line or "🎞️  Decoding video..." in line:
            self._emit_progress("decoding", 0.85, "Decoding latents to video...")
        elif "VAE:ENCODE:START" in line:
             self._emit_progress("preparing_inputs", 0.12, "Encoding input image...")
        elif "VAE:DECODE:COMPLETE" in line or "✅ Video encoded" in line:
             self._emit_progress("decoding", 0.92, "Video decoding complete.")
        elif "AUDIO:DECODE:START" in line or "🔊 Decoding audio..." in line:
             self._emit_progress("decoding", 0.93, "Decoding audio...")
        elif "Combined video and audio" in line or "✅ Saved video" in line:
             self._emit_progress("encoding_output", 0.96, "Encoding final MP4...")

        # Also handle fallsback for visibility
        elif "ENHANCER_FALLBACK:" in line:
            logger.warning(f"MLXLTXAdapter: Captured {line}")
            self._log_job(f"MLXLTXAdapter: Captured {line}")
