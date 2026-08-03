from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


DEFAULT_SIZE = 2048


def upscale_image(input_path: Path, output_path: Path, size: int) -> None:
	with Image.open(input_path) as image:
		resized = image.resize((size, size), Image.Resampling.LANCZOS)
		output_path.parent.mkdir(parents=True, exist_ok=True)
		resized.save(output_path, optimize=True)
		print(f"{input_path.name}: {image.width}x{image.height} -> {output_path.name}: {size}x{size}")


def main() -> None:
	script_dir = Path(__file__).parent

	parser = argparse.ArgumentParser(
		description="Upscale pet source images to a 2K square without background removal or color cleanup."
	)
	parser.add_argument("--input", type=Path, default=script_dir / "source")
	parser.add_argument("--output", type=Path, default=script_dir / "model_maker" / "source_2048")
	parser.add_argument("--size", type=int, default=DEFAULT_SIZE)
	args = parser.parse_args()

	input_dir = args.input.resolve()
	output_dir = args.output.resolve()
	size = max(1, args.size)

	for input_path in sorted(input_dir.glob("*.png")):
		if input_path.name.startswith("_"):
			continue

		upscale_image(input_path, output_dir / input_path.name, size)


if __name__ == "__main__":
	main()
