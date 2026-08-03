import argparse
from pathlib import Path

from PIL import Image


DEFAULT_SIZES = (64, 128, 256)


def resize_icons(input_dir: Path, output_root: Path, sizes: tuple[int, ...]) -> None:
	output_root.mkdir(parents=True, exist_ok=True)

	for size in sizes:
		if size <= 0:
			raise ValueError("Icon sizes must be greater than 0.")

		output_dir = output_root / str(size)
		output_dir.mkdir(parents=True, exist_ok=True)

		for input_path in sorted(input_dir.glob("*.png")):
			output_path = output_dir / input_path.name

			with Image.open(input_path).convert("RGBA") as image:
				resized = image.resize((size, size), Image.Resampling.LANCZOS)
				resized.save(output_path)
				print(f"{input_path.name}: {image.width}x{image.height} -> {size}x{size}")


def main() -> None:
	script_dir = Path(__file__).parent

	parser = argparse.ArgumentParser(description="Resize source UI icons into Roblox-friendly square PNGs.")
	parser.add_argument("--input", type=Path, default=script_dir / "source", help="Folder containing source PNG icons.")
	parser.add_argument("--output", type=Path, default=script_dir / "roblox", help="Root folder for resized outputs.")
	parser.add_argument("--sizes", type=int, nargs="+", default=DEFAULT_SIZES, help="Square output sizes in pixels.")
	args = parser.parse_args()

	resize_icons(args.input.resolve(), args.output.resolve(), tuple(args.sizes))


if __name__ == "__main__":
	main()
