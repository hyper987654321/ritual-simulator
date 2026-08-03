from __future__ import annotations

import argparse
from collections import Counter, deque
from pathlib import Path

from PIL import Image


DEFAULT_COLOR_TO_ALPHA_KEY = (255, 0, 255)
DEFAULT_KEY_TOLERANCE = 18
DEFAULT_EDGE_KEY_COLORS = 128
DEFAULT_CLEANUP_RADIUS = 4
DEFAULT_ALPHA_FLOOR = 2
DEFAULT_SIZE = 512
DEFAULT_SCALE = 2.0


def parse_rgb(value: str) -> tuple[int, int, int]:
	if value.startswith("#"):
		value = value[1:]
	if len(value) == 6:
		return tuple(int(value[index : index + 2], 16) for index in (0, 2, 4))

	parts = value.split(",")
	if len(parts) != 3:
		raise argparse.ArgumentTypeError("Use #RRGGBB or R,G,B.")
	return tuple(max(0, min(255, int(part.strip()))) for part in parts)


def key_from_filename(path: Path) -> tuple[int, int, int] | None:
	token = path.stem.rsplit("_", 1)[-1]
	if len(token) != 6:
		return None

	try:
		return tuple(int(token[index : index + 2], 16) for index in (0, 2, 4))
	except ValueError:
		return None


def asset_slug_from_filename(path: Path) -> str:
	parts = path.stem.split("_")
	if key_from_filename(path) is not None:
		parts = parts[:-1]

	return "_".join(parts) if parts else path.stem


def rgb_distance(left: tuple[int, int, int], right: tuple[int, int, int]) -> int:
	return max(abs(left[0] - right[0]), abs(left[1] - right[1]), abs(left[2] - right[2]))


def collect_edge_key_colors(image: Image.Image, max_colors: int) -> list[tuple[int, int, int]]:
	pixels = image.load()
	width, height = image.size
	border_colors: list[tuple[int, int, int]] = []

	for x in range(width):
		border_colors.append(pixels[x, 0][:3])
		border_colors.append(pixels[x, height - 1][:3])
	for y in range(height):
		border_colors.append(pixels[0, y][:3])
		border_colors.append(pixels[width - 1, y][:3])

	return [color for color, _ in Counter(border_colors).most_common(max_colors)]


def is_key_pixel(
	rgb: tuple[int, int, int],
	key_colors: list[tuple[int, int, int]],
	key_tolerance: int,
) -> bool:
	return any(rgb_distance(rgb, key_color) <= key_tolerance for key_color in key_colors)


def build_background_mask(
	image: Image.Image,
	key_colors: list[tuple[int, int, int]],
	key_tolerance: int,
) -> bytearray:
	pixels = image.load()
	width, height = image.size
	mask = bytearray(width * height)
	queue: deque[tuple[int, int]] = deque()

	for x in range(width):
		queue.append((x, 0))
		queue.append((x, height - 1))
	for y in range(height):
		queue.append((0, y))
		queue.append((width - 1, y))

	while queue:
		x, y = queue.popleft()
		if not (0 <= x < width and 0 <= y < height):
			continue

		index = y * width + x
		if mask[index]:
			continue

		red, green, blue, alpha = pixels[x, y]
		if alpha == 0 or is_key_pixel((red, green, blue), key_colors, key_tolerance):
			mask[index] = 1
			queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))

	return mask


def dilate_mask(mask: bytearray, width: int, height: int, radius: int) -> bytearray:
	dilated = bytearray(mask)

	for _ in range(radius):
		next_mask = bytearray(dilated)
		for y in range(height):
			row = y * width
			for x in range(width):
				index = row + x
				if not dilated[index]:
					continue

				for ny in range(max(0, y - 1), min(height, y + 2)):
					neighbor_row = ny * width
					for nx in range(max(0, x - 1), min(width, x + 2)):
						next_mask[neighbor_row + nx] = 1

		dilated = next_mask

	return dilated


def channel_difference(pixel_channel: int, key_channel: int) -> float:
	if pixel_channel > key_channel:
		if key_channel >= 255:
			return 0.0
		return (pixel_channel - key_channel) / (255.0 - key_channel)

	if pixel_channel < key_channel:
		if key_channel <= 0:
			return 0.0
		return (key_channel - pixel_channel) / key_channel

	return 0.0


def color_to_alpha_pixel(
	red: int,
	green: int,
	blue: int,
	alpha: int,
	key_color: tuple[int, int, int],
	alpha_floor: int,
) -> tuple[int, int, int, int]:
	next_alpha_ratio = max(
		channel_difference(red, key_color[0]),
		channel_difference(green, key_color[1]),
		channel_difference(blue, key_color[2]),
	)
	next_alpha = int(round(alpha * next_alpha_ratio))

	if next_alpha <= alpha_floor or next_alpha_ratio <= 0:
		return 0, 0, 0, 0

	red = int(round((red - key_color[0]) / next_alpha_ratio + key_color[0]))
	green = int(round((green - key_color[1]) / next_alpha_ratio + key_color[1]))
	blue = int(round((blue - key_color[2]) / next_alpha_ratio + key_color[2]))

	return (
		max(0, min(255, red)),
		max(0, min(255, green)),
		max(0, min(255, blue)),
		next_alpha,
	)


def remove_keyed_background(
	image: Image.Image,
	key_tolerance: int,
	max_edge_key_colors: int,
	color_to_alpha_key: tuple[int, int, int],
	cleanup_radius: int,
	alpha_floor: int,
) -> Image.Image:
	image = image.convert("RGBA")
	pixels = image.load()
	width, height = image.size
	key_colors = collect_edge_key_colors(image, max_edge_key_colors)
	background_mask = build_background_mask(image, key_colors, key_tolerance)
	cleanup_mask = dilate_mask(background_mask, width, height, cleanup_radius)

	for y in range(height):
		for x in range(width):
			index = y * width + x
			red, green, blue, alpha = pixels[x, y]

			if background_mask[index]:
				pixels[x, y] = (0, 0, 0, 0)
			elif cleanup_mask[index]:
				pixels[x, y] = color_to_alpha_pixel(
					red,
					green,
					blue,
					alpha,
					color_to_alpha_key,
					alpha_floor,
				)

	return image


def content_bbox(image: Image.Image, padding: int) -> tuple[int, int, int, int] | None:
	bbox = image.getchannel("A").getbbox()
	if bbox is None:
		return None

	left, top, right, bottom = bbox
	return (
		max(0, left - padding),
		max(0, top - padding),
		min(image.width, right + padding),
		min(image.height, bottom + padding),
	)


def crop_to_square(image: Image.Image, padding: int) -> Image.Image:
	bbox = content_bbox(image, padding)
	if bbox is None:
		return image

	left, top, right, bottom = bbox
	width = right - left
	height = bottom - top
	size = max(width, height)
	center_x = (left + right) / 2
	center_y = (top + bottom) / 2
	square_left = int(round(center_x - size / 2))
	square_top = int(round(center_y - size / 2))

	output = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	crop_left = max(0, square_left)
	crop_top = max(0, square_top)
	crop_right = min(image.width, square_left + size)
	crop_bottom = min(image.height, square_top + size)
	output.alpha_composite(
		image.crop((crop_left, crop_top, crop_right, crop_bottom)),
		dest=(crop_left - square_left, crop_top - square_top),
	)
	return output


def prepare_asset(
	input_path: Path,
	output_path: Path,
	key_tolerance: int,
	max_edge_key_colors: int,
	color_to_alpha_key: tuple[int, int, int],
	cleanup_radius: int,
	alpha_floor: int,
	size: int,
	scale: float,
	crop: bool,
	padding: int,
) -> None:
	with Image.open(input_path) as source:
		image = remove_keyed_background(
			source,
			key_tolerance,
			max_edge_key_colors,
			color_to_alpha_key,
			cleanup_radius,
			alpha_floor,
		)
		source_size = f"{source.width}x{source.height}"

	if crop:
		image = crop_to_square(image, padding)

	target_size = size
	if target_size > 0:
		target_size = int(round(target_size * scale))
	elif scale > 0 and scale != 1.0:
		target_size = int(round(max(image.size) * scale))

	if target_size > 0 and image.size != (target_size, target_size):
		image = image.resize((target_size, target_size), Image.Resampling.LANCZOS)

	output_path.parent.mkdir(parents=True, exist_ok=True)
	image.save(output_path, optimize=True)
	print(f"{input_path.name}: {source_size} -> {output_path.name}: {image.width}x{image.height}")


def main() -> None:
	script_dir = Path(__file__).parent
	default_input = script_dir / "source"
	default_output = script_dir / "roblox" / str(int(DEFAULT_SIZE * DEFAULT_SCALE))

	parser = argparse.ArgumentParser(
		description="Prepare pet images by flood-removing only pixels close to this image's sampled edge key colors."
	)
	parser.add_argument("--input", type=Path, default=default_input)
	parser.add_argument("--output", type=Path, default=default_output)
	parser.add_argument("--size", type=int, default=DEFAULT_SIZE)
	parser.add_argument("--scale", type=float, default=DEFAULT_SCALE)
	parser.add_argument(
		"--key-tolerance",
		type=int,
		default=DEFAULT_KEY_TOLERANCE,
		help="Max per-channel distance from sampled edge key colors.",
	)
	parser.add_argument(
		"--max-edge-key-colors",
		type=int,
		default=DEFAULT_EDGE_KEY_COLORS,
		help="Number of common border colors to treat as the image-specific background key palette.",
	)
	parser.add_argument(
		"--color-to-alpha-key",
		type=parse_rgb,
		default=DEFAULT_COLOR_TO_ALPHA_KEY,
		help="Specific GIMP-style Color to Alpha key used only on the background edge cleanup band.",
	)
	parser.add_argument(
		"--cleanup-radius",
		type=int,
		default=DEFAULT_CLEANUP_RADIUS,
		help="Pixel radius around removed background where Color to Alpha is applied.",
	)
	parser.add_argument("--alpha-floor", type=int, default=DEFAULT_ALPHA_FLOOR)
	parser.add_argument("--padding", type=int, default=56)
	parser.add_argument("--no-crop", action="store_true")
	args = parser.parse_args()

	input_dir = args.input.resolve()
	output_dir = args.output.resolve()

	for input_path in sorted(input_dir.glob("*.png")):
		if input_path.name.startswith("_"):
			continue

		output_path = output_dir / f"{asset_slug_from_filename(input_path)}.png"
		prepare_asset(
			input_path,
			output_path,
			max(0, args.key_tolerance),
			max(1, args.max_edge_key_colors),
			args.color_to_alpha_key,
			max(0, args.cleanup_radius),
			max(0, min(255, args.alpha_floor)),
			args.size,
			max(0.0, args.scale),
			not args.no_crop,
			max(0, args.padding),
		)


if __name__ == "__main__":
	main()
