@tool
class_name DwarfSpriteComposer
extends RefCounted

## Composes the in-world dwarf from the Dwarf Fortress layer sheets:
## a clothed body, a head in one of four skin tones, and hair/beard
## styles in the sheet's six natural colors. The same layer choices
## drive the character-creator preview and the player sprite in every
## scene, so the dwarf you design is the dwarf you play.

const HEADS_SHEET := preload("res://resources/images/character_creator/portraits/dwarf_body.png")
const HAIR_SHEET := preload("res://resources/images/character_creator/portraits/dwarf_hair_straight.png")
const CLOTHES_SHEET := preload("res://resources/images/character_creator/portraits/dwarf_clothes.png")

const TILE := 32

## Head rows by skin tone (pale, tan, brown, dark); column 0 is the
## neutral expression.
const SKIN_TONE_ROWS: Array[int] = [1, 4, 7, 10]

## Hair rows on the straight-hair sheet, short to long.
const HAIR_STYLE_ROWS: Array[int] = [0, 2, 3, 5, 6, 8, 11, 12]

## Beard rows on the same sheet, trimmed to braided to full.
const BEARD_STYLE_ROWS: Array[int] = [21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32]

## Hair/beard color columns: white, slate, red, gold, brown, umber.
const COLOR_COLUMN_COUNT := 6
const FIRST_COLOR_COLUMN := 1

## Tunic garment used for the standing body.
const CLOTHES_ROW := 14
const CLOTHES_COLOR_COUNT := 18

static func default_layers() -> Dictionary:
	return {
		"skin_tone": 0,
		"hair_style": 2,
		"hair_color": 4,
		"beard_style": 1,
		"beard_color": 4,
		"clothes_color": 7
	}

static func layers_from_character(character: Dictionary) -> Dictionary:
	var layers_variant: Variant = character.get("dwarf_layers")
	if layers_variant is Dictionary and not (layers_variant as Dictionary).is_empty():
		return layers_variant as Dictionary
	return {}

## Head close-up for the portrait frame: head, hair and beard without
## the clothed body - the DF tile is mostly head, so it reads as a bust.
static func compose_head(layers: Dictionary) -> ImageTexture:
	var image := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var skin_tone := clampi(int(layers.get("skin_tone", 0)), 0, SKIN_TONE_ROWS.size() - 1)
	_blit_tile(image, HEADS_SHEET, 0, SKIN_TONE_ROWS[skin_tone])
	var hair_style := int(layers.get("hair_style", 0))
	if hair_style >= 0:
		var hair_color := clampi(int(layers.get("hair_color", 4)), 0, COLOR_COLUMN_COUNT - 1)
		_blit_tile(image, HAIR_SHEET, FIRST_COLOR_COLUMN + hair_color, HAIR_STYLE_ROWS[clampi(hair_style, 0, HAIR_STYLE_ROWS.size() - 1)])
	var beard_style := int(layers.get("beard_style", 0))
	if beard_style >= 0:
		var beard_color := clampi(int(layers.get("beard_color", 4)), 0, COLOR_COLUMN_COUNT - 1)
		_blit_tile(image, HAIR_SHEET, FIRST_COLOR_COLUMN + beard_color, BEARD_STYLE_ROWS[clampi(beard_style, 0, BEARD_STYLE_ROWS.size() - 1)])
	return ImageTexture.create_from_image(image)

## The composed 32x32 dwarf. beard_style/hair_style of -1 hide the layer.
static func compose(layers: Dictionary) -> ImageTexture:
	var image := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var skin_tone := clampi(int(layers.get("skin_tone", 0)), 0, SKIN_TONE_ROWS.size() - 1)
	var clothes_color := clampi(int(layers.get("clothes_color", 7)), 0, CLOTHES_COLOR_COUNT - 1)
	_blit_tile(image, CLOTHES_SHEET, clothes_color, CLOTHES_ROW)
	_blit_tile(image, HEADS_SHEET, 0, SKIN_TONE_ROWS[skin_tone])
	var hair_style := int(layers.get("hair_style", 0))
	if hair_style >= 0:
		var hair_color := clampi(int(layers.get("hair_color", 4)), 0, COLOR_COLUMN_COUNT - 1)
		_blit_tile(image, HAIR_SHEET, FIRST_COLOR_COLUMN + hair_color, HAIR_STYLE_ROWS[clampi(hair_style, 0, HAIR_STYLE_ROWS.size() - 1)])
	var beard_style := int(layers.get("beard_style", 0))
	if beard_style >= 0:
		var beard_color := clampi(int(layers.get("beard_color", 4)), 0, COLOR_COLUMN_COUNT - 1)
		_blit_tile(image, HAIR_SHEET, FIRST_COLOR_COLUMN + beard_color, BEARD_STYLE_ROWS[clampi(beard_style, 0, BEARD_STYLE_ROWS.size() - 1)])
	return ImageTexture.create_from_image(image)

static func _blit_tile(target: Image, sheet: Texture2D, column: int, row: int) -> void:
	var source := sheet.get_image()
	if source.is_compressed():
		source.decompress()
	if source.get_format() != Image.FORMAT_RGBA8:
		source.convert(Image.FORMAT_RGBA8)
	target.blend_rect(source, Rect2i(column * TILE, row * TILE, TILE, TILE), Vector2i.ZERO)
