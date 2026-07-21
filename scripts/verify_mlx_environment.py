import sys
import platform
import sysconfig
import os
from pathlib import Path

def main():
    print(f"sys.executable: {sys.executable}")
    print(f"platform.machine(): {platform.machine()}")
    print(f"sysconfig.get_platform(): {sysconfig.get_platform()}")
    print(f"platform.platform(): {platform.platform()}")
    print(f"VIRTUAL_ENV: {os.environ.get('VIRTUAL_ENV')}")

    try:
        import mlx.core
        print(f"MLX import status: SUCCESS")
        # Attempt to get version if possible (mlx.core doesn't always have __version__)
        try:
            import mlx
            if hasattr(mlx, "__version__"):
                print(f"MLX version: {mlx.__version__}")
            else:
                # mlx-core version is often in mlx.__version__ but let's be safe
                print("MLX version: Available (could not determine version string)")
        except:
            print("MLX version: Available")
    except ImportError:
        print(f"MLX import status: FAILED")
        print(f"MLX is not installed in {sys.executable}")
        sys.exit(1)

    if sys.platform == "darwin":
        if platform.machine() != "arm64":
            print("ERROR: MLX requires Apple Silicon ARM64 Python.")
            sys.exit(1)
        else:
            print("Architecture check: PASSED (ARM64)")

    print("Environment verification: SUCCESS")

if __name__ == "__main__":
    main()
