class_name FramedIcon
extends RefCounted

const FRAME: Texture2D = preload("res://assets/icons/shared/icon_frame.png")

static var _cache: Dictionary = {}


static func compose(art: Texture2D) -> Texture2D:
	if art == null:
		return null
	if _cache.has(art):
		return _cache[art] as Texture2D

	var background: Image = FRAME.get_image()
	var foreground: Image = art.get_image()
	if background == null or foreground == null:
		return art
	if background.is_compressed() and background.decompress() != OK:
		return art
	if foreground.is_compressed() and foreground.decompress() != OK:
		return art
	background.convert(Image.FORMAT_RGBA8)
	foreground.convert(Image.FORMAT_RGBA8)
	var size: Vector2i = background.get_size()
	var factor: float = minf(float(size.x) / foreground.get_width(), float(size.y) / foreground.get_height())
	var fitted: Vector2i = Vector2i(Vector2(foreground.get_size()) * factor)
	if foreground.get_size() != fitted:
		foreground.resize(maxi(1, fitted.x), maxi(1, fitted.y), Image.INTERPOLATE_LANCZOS)
	var offset: Vector2i = (size - foreground.get_size()) / 2
	background.blend_rect(foreground, Rect2i(Vector2i.ZERO, foreground.get_size()), offset)
	var texture := ImageTexture.create_from_image(background)
	_cache[art] = texture
	return texture
