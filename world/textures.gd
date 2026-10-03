class_name Tex
extends RefCounted
## The game's textures, made from noise the first time it runs and kept in
## user:// after that. Three noise detail scales packed in RGB, matching
## normal maps, a big soft macro map, and fur and bark detail.

static var _cache: Dictionary = {}


static func get_tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := "user://tex_v2_%s.png" % name
	var img: Image = null
	if FileAccess.file_exists(path):
		img = Image.load_from_file(path)
	if img == null:
		img = _make(name)
		img.save_png(path)
	if not img.has_mipmaps():
		img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[name] = t
	return t


static func _noise(sd: int, f: float, oct: int, kind: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH, frac: int = FastNoiseLite.FRACTAL_FBM) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = sd
	n.frequency = f
	n.fractal_octaves = oct
	n.noise_type = kind
	n.fractal_type = frac
	return n


static func _rgb(size: int, a: FastNoiseLite, b: FastNoiseLite, c: FastNoiseLite) -> Image:
	var ia := a.get_seamless_image(size, size)
	var ib := b.get_seamless_image(size, size)
	var ic := c.get_seamless_image(size, size)
	var out := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			out.set_pixel(x, y, Color(ia.get_pixel(x, y).r, ib.get_pixel(x, y).r, ic.get_pixel(x, y).r))
	return out


static func _make(name: String) -> Image:
	match name:
		"detail":
			return _rgb(512, _noise(11, 0.012, 5), _noise(12, 0.03, 4, FastNoiseLite.TYPE_CELLULAR), _noise(13, 0.06, 3))
		"detail_n":
			var b := _noise(14, 0.04, 5).get_seamless_image(512, 512)
			b.convert(Image.FORMAT_RGBA8)
			b.bump_map_to_normal_map(6.0)
			return b
		"macro":
			return _rgb(256, _noise(21, 0.008, 4), _noise(22, 0.015, 3), _noise(23, 0.03, 2))
		"fur":
			# Long strands: stretched noise.
			var n := _noise(31, 0.02, 4)
			var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
			var src := n.get_seamless_image(1024, 256)
			for y in 256:
				for x in 256:
					var v := src.get_pixel(x * 4 % 1024, y).r
					var v2 := src.get_pixel((x * 4 + 512) % 1024, (y + 128) % 256).r
					img.set_pixel(x, y, Color(v, v2, (v + v2) * 0.5))
			return img
		"fur_n":
			var n2 := _noise(32, 0.05, 4)
			var src2 := n2.get_seamless_image(256, 256)
			var b2 := Image.create(256, 256, false, Image.FORMAT_RGBA8)
			for y in 256:
				for x in 256:
					var s := 0.0
					for k in 4:
						s += src2.get_pixel(x, (y + k * 3) % 256).r
					var v3 := s / 4.0
					b2.set_pixel(x, y, Color(v3, v3, v3))
			b2.bump_map_to_normal_map(4.0)
			return b2
		"bark":
			var nb := _noise(41, 0.02, 4, FastNoiseLite.TYPE_CELLULAR)
			var ib := Image.create(256, 256, false, Image.FORMAT_RGB8)
			var sb := nb.get_seamless_image(256, 1024)
			for y in 256:
				for x in 256:
					var v4 := sb.get_pixel(x, y * 4 % 1024).r
					ib.set_pixel(x, y, Color(v4, v4, v4))
			return ib
		"bark_n":
			var b3 := _noise(42, 0.06, 4, FastNoiseLite.TYPE_CELLULAR).get_seamless_image(256, 256)
			b3.convert(Image.FORMAT_RGBA8)
			b3.bump_map_to_normal_map(8.0)
			return b3
		"wood":
			var nw := _noise(51, 0.01, 4)
			var iw := Image.create(256, 256, false, Image.FORMAT_RGB8)
			var sw := nw.get_seamless_image(64, 1024)
			for y in 256:
				for x in 256:
					var v5 := sw.get_pixel(x / 4, y * 4 % 1024).r
					var ring := 0.5 + 0.5 * sin(v5 * 40.0)
					iw.set_pixel(x, y, Color(v5, ring, v5 * 0.5 + ring * 0.5))
			return iw
		"rust":
			return _rgb(256, _noise(61, 0.02, 5), _noise(62, 0.08, 3, FastNoiseLite.TYPE_CELLULAR), _noise(63, 0.15, 2))
	return Image.create(4, 4, false, Image.FORMAT_RGB8)
