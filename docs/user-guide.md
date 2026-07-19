# User Guide: Getting Started with AI Studio Local

This guide will help you set up and run AI Studio Local on your Mac.

## 1. Hardware Requirements

AI Studio Local is optimized for **Apple Silicon** (M1, M2, M3, M4) and runs entirely on your local machine.

- **Processor**: Apple Silicon Mac (M1 Pro/Max or better recommended).
- **Memory (Unified Memory)**:
    - **16GB**: Minimum (Best for "Fast Draft" or quantized models).
    - **32GB+**: Recommended for high-quality production work.
- **Disk Space**: 20GB+ free space (for models and generated videos).
- **macOS**: 14.0 (Sonoma) or newer.

## 2. Software Prerequisites

Before running the application, you need a few tools installed on your Mac:

### Python 3.11+
The video generation engine uses Python.
1. Check if you have it: `python3 --version`
2. If not installed, download it from [python.org](https://www.python.org/downloads/macos/) or install via Homebrew: `brew install python@3.11`

### FFmpeg
Required for encoding and processing video files.
- Install via Homebrew: `brew install ffmpeg`

### Xcode (Optional, for developers)
If you want to build the app from source, you'll need Xcode 15+.

## 3. Installation

1. **Clone or Download the Repository**:
   ```bash
   git clone https://github.com/your-org/ai-studio-local.git
   cd ai-studio-local
   ```

2. **Run the Installer**:
   The project includes a `Makefile` to simplify setup.
   ```bash
   make install
   ```
   *This will set up the Python virtual environment and install all necessary worker dependencies.*

## 4. Downloading AI Models

AI Studio Local requires LTX-Video model weights in MLX format.

1. Create a `models` folder in the project root if it doesn't exist.
2. Download the MLX-compatible LTX-Video weights (see the [Model Download Guide](model-download-guide.md) for details).
3. Place them in `models/ltx-video-0.1-mlx/`.

## 5. Running the Application

To run AI Studio Local, you need to start two components: the **Python Worker** (the engine) and the **SwiftUI App** (the interface).

### Step 1: Start the Worker
In your terminal, run:
```bash
make run-worker
```
*The worker must be running for the app to generate video.*

### Step 2: Start the App
In a new terminal tab, run:
```bash
make run-app
```
*Alternatively, you can open `app/AIStudioLocal.xcodeproj` in Xcode and press Cmd+R.*

## 6. Your First Generation

1. Launch the app and click **New Project**.
2. Go to the **Project Studio**.
3. In the **Scene Inspector** (right panel), enter a prompt (e.g., "A cinematic shot of a sunset over a calm ocean").
4. Click the **Generate** button.
5. Watch the progress in the **Render Queue**.
6. Once finished, your video will appear in the preview area!

## Troubleshooting

- **"Worker not connected"**: Ensure you ran `make run-worker` and it's still running.
- **Out of Memory**: If generation fails with a memory error, try closing other apps or using a "Fast Draft" model profile in the Model Manager.
- **FFmpeg not found**: Ensure `ffmpeg` is installed and available in your PATH.

For more technical details, see the [Development Setup](development-setup.md) guide.
