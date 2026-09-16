package rendering;

import util.Matrix;
import util.IntRectangle;
import js.html.CanvasElement;
import js.lib.Float32Array;
import js.lib.Uint8Array;
import js.html.webgl.RenderingContext;
import js.html.webgl.Buffer;
import js.Syntax;
import project.data.Tileset;
import modules.tiles.TileLayer;
import util.Vector;
import util.Color;
import util.Rectangle;
import util.Matrix3D;

class GLRenderer
{
	public static var renderers: Map<String, GLRenderer> = new Map();

	public var name: String;
	public var canvas: CanvasElement;
	public var gl: RenderingContext;
	public var clearColor:Color = Color.fromHex("#171a20", 1);
	public var loadTextures:Bool = true;
	public var width(get,null):Int;
	public var height(get,null):Int;

	var shapeShader: Shader;
	var textureShader: Shader;
	var orthoMatrix: Matrix3D;
	var posBuffer: Buffer;
	var colBuffer: Buffer;
	var uvBuffer: Buffer;
	var positions: Array<Float> = [];
	var colors: Array<Float> = [];
	var uvs: Array<Float> = [];
	var currentDrawMode: Int = -1;
	var currentTexture: Texture = null;
	var currentBlendState: BlendState = BlendState.alphaBlend;
	var lastAlpha: Float;

	public function new(name: String, canvas: CanvasElement)
	{
		GLRenderer.renderers[name] = this;

		this.name = name;
		this.canvas = canvas;

		// init gl
		gl = canvas.getContext("webgl");
		gl.enable(RenderingContext.BLEND);
		gl.enable(RenderingContext.SAMPLE_ALPHA_TO_COVERAGE);
		gl.enable(RenderingContext.SAMPLE_COVERAGE);
		gl.disable(RenderingContext.DEPTH_TEST);
		gl.disable(RenderingContext.CULL_FACE);
		gl.clearColor(clearColor.r, clearColor.g, clearColor.b, clearColor.a);
		gl.blendFunc(currentBlendState.sfactor, currentBlendState.dfactor);

		posBuffer = gl.createBuffer();
		colBuffer = gl.createBuffer();
		uvBuffer = gl.createBuffer();

		// init shaders
		shapeShader = new Shader(gl, "shape");
		textureShader = new Shader(gl, "texture");
	}

	public function dispose(): Void
	{
		Syntax.delete(GLRenderer.renderers, name);

		shapeShader.dispose();
		textureShader.dispose();

		gl.deleteBuffer(posBuffer);
		gl.deleteBuffer(colBuffer);
		gl.deleteBuffer(uvBuffer);
	}

	// OFFSCREEN RENDERING

	var offscreenTexture: js.html.webgl.Texture;
	var offscreenFramebuffer: js.html.webgl.Framebuffer;
	var offscreenTextureSize: Vector;

	public function setupRenderTarget(size: Vector): Void
	{
		offscreenTextureSize = size;

		offscreenTexture = gl.createTexture();
		gl.bindTexture(RenderingContext.TEXTURE_2D, offscreenTexture);

		// hack fix for drawing to work. doesn't look very good at the moment. should investigate further
		gl.disable(RenderingContext.SAMPLE_ALPHA_TO_COVERAGE);
		gl.disable(RenderingContext.SAMPLE_COVERAGE);

		var level = 0;
		var internalFormat = RenderingContext.RGBA;
		var border = 0;
		var format = RenderingContext.RGBA;
		var type = RenderingContext.UNSIGNED_BYTE;
		var data = null;
		gl.texImage2D(RenderingContext.TEXTURE_2D, level, internalFormat, Math.floor(size.x), Math.floor(size.y), border, format, type, data);

		gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_MIN_FILTER, RenderingContext.LINEAR);
		gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_WRAP_S, RenderingContext.CLAMP_TO_EDGE);
		gl.texParameteri(RenderingContext.TEXTURE_2D, RenderingContext.TEXTURE_WRAP_T, RenderingContext.CLAMP_TO_EDGE);

		offscreenFramebuffer = gl.createFramebuffer();
		gl.bindFramebuffer(RenderingContext.FRAMEBUFFER, offscreenFramebuffer);
		gl.framebufferTexture2D(RenderingContext.FRAMEBUFFER, RenderingContext.COLOR_ATTACHMENT0, RenderingContext.TEXTURE_2D, offscreenTexture, level);

		gl.clearColor(0, 0, 0, 0);
		gl.clear(RenderingContext.COLOR_BUFFER_BIT| RenderingContext.DEPTH_BUFFER_BIT);

		gl.viewport(0, 0, Math.floor(size.x), Math.floor(size.y));
		orthoMatrix = Matrix3D.orthographic(0, size.x, 0, size.y, -100, 100);
		EDITOR.camera.setIdentity();

		var canRead = gl.checkFramebufferStatus(RenderingContext.FRAMEBUFFER) == RenderingContext.FRAMEBUFFER_COMPLETE;
	}

	public function getRenderTargetPixels(): Uint8Array
	{
		var pixels = new Uint8Array(Math.floor(offscreenTextureSize.x) * Math.floor(offscreenTextureSize.y) * 4);
		gl.readPixels(0, 0, Math.floor(offscreenTextureSize.x), Math.floor(offscreenTextureSize.y), RenderingContext.RGBA, RenderingContext.UNSIGNED_BYTE, pixels);
		return pixels;
	}

	public function doneRenderTarget(): Void
	{
		gl.bindFramebuffer(RenderingContext.FRAMEBUFFER, null);
		updateCanvasSize();
	}

	public function destroyRenderTarget(): Void
	{
		// hack fix
		gl.enable(RenderingContext.SAMPLE_ALPHA_TO_COVERAGE);
		gl.enable(RenderingContext.SAMPLE_COVERAGE);

		gl.deleteTexture(offscreenTexture);
		gl.deleteFramebuffer(offscreenFramebuffer);
	}

	// SIZE

	public function updateCanvasSize(): Void
	{
		canvas.width = canvas.parentElement.clientWidth;
		canvas.height = canvas.parentElement.clientHeight;

		gl.viewport(0, 0, canvas.width, canvas.height);
		orthoMatrix = Matrix3D.orthographic(-canvas.width/2, canvas.width/2, canvas.height/2, -canvas.height/2, -100, 100);
	}

	// DRAWING

	public function clear(): Void
	{
		gl.clearColor(clearColor.r, clearColor.g, clearColor.b, clearColor.a);
		gl.clear(RenderingContext.COLOR_BUFFER_BIT | RenderingContext.DEPTH_BUFFER_BIT);
	}

	public function finishDrawing(): Void
	{
		setTexture(null);
		setDrawMode(-1);
	}

	public function getAlpha(): Float
	{
		return lastAlpha;
	}

	public function setAlpha(alpha: Float): Void
	{
		if (alpha != lastAlpha)
		{
			finishDrawing();
			lastAlpha = alpha;
		}
	}

	public function getBlendState(): BlendState
	{
		return currentBlendState.clone();
	}

	public function setBlendState(state: BlendState): Void
	{
		if (!currentBlendState.equals(state))
		{
			finishDrawing();
			gl.blendFunc(state.sfactor, state.dfactor);
			currentBlendState = state.clone();
		}
	}

	function setDrawMode(newMode: Int): Void
	{
		if (currentDrawMode != newMode)
		{
			if (currentTexture != null)
				doDraw(RenderingContext.TRIANGLES, currentTexture);
			else if (currentDrawMode != -1)
				doDraw(currentDrawMode, null);

			currentDrawMode = newMode;
			currentTexture = null;
		}
	}

	function setTexture(texture: Texture): Void
	{
		if (currentTexture != texture)
		{
			if (currentTexture != null)
				doDraw(RenderingContext.TRIANGLES, currentTexture);
			else if (currentDrawMode != -1)
				doDraw(currentDrawMode, null);

			currentTexture = texture;
			currentDrawMode = -1;
		}
	}

	inline function getCurrentPixelRect(): IntRectangle
	{
		return (currentTexture != null) ? currentTexture.pixelRect : null;
	}

	function doDraw(drawMode: Int, texture: Texture): Void
	{
		// set up current shader
		var shader:Shader = (texture == null ? shapeShader : textureShader);
		gl.useProgram(shader.program);
		shader.setUniform1f("alpha", lastAlpha);

		// positions
		{
			gl.enableVertexAttribArray(shader.vertexPositionAttribute);
			gl.bindBuffer(RenderingContext.ARRAY_BUFFER, posBuffer);
			gl.vertexAttribPointer(shader.vertexPositionAttribute, 2, RenderingContext.FLOAT, false, 0, 0);
			gl.bufferData(RenderingContext.ARRAY_BUFFER, new Float32Array(positions), RenderingContext.STATIC_DRAW);
		}

		// vertex uv's (texture shader)
		if (texture != null)
		{
			gl.activeTexture(RenderingContext.TEXTURE0);
			gl.bindTexture(RenderingContext.TEXTURE_2D, texture.textures[name]);
			gl.uniform1i(gl.getUniformLocation(shader.program, "texture"), 0);

			gl.enableVertexAttribArray(shader.vertexUVAttribute);
			gl.bindBuffer(RenderingContext.ARRAY_BUFFER, uvBuffer);
			gl.vertexAttribPointer(shader.vertexUVAttribute, 2, RenderingContext.FLOAT, false, 0, 0);
			gl.bufferData(RenderingContext.ARRAY_BUFFER, new Float32Array(uvs), RenderingContext.STATIC_DRAW);
		}

		// vertex colors
		{
			gl.enableVertexAttribArray(shader.vertexColorAttribute);
			gl.bindBuffer(RenderingContext.ARRAY_BUFFER, colBuffer);
			gl.vertexAttribPointer(shader.vertexColorAttribute, 4, RenderingContext.FLOAT, false, 0, 0);
			gl.bufferData(RenderingContext.ARRAY_BUFFER, new Float32Array(colors), RenderingContext.STATIC_DRAW);
		}

		// Set Matrix Uniforms
		// TODO no reason for there to be 2 Matrix. Should just multiply Ortho and Camera together and pass that
		{
			var pUniform = gl.getUniformLocation(shader.program, "orthoMatrix");
			gl.uniformMatrix4fv(pUniform, false, orthoMatrix.flatten());

			var mvUniform = gl.getUniformLocation(shader.program, "matrix");
			gl.uniformMatrix3fv(mvUniform, false, EDITOR.camera.flatten());
		}

		gl.drawArrays(drawMode, 0, Math.floor(positions.length / 2));

		positions.resize(0);
		colors.resize(0);
		uvs.resize(0);
	}

	// TEXTURES

	var topleft:Vector = new Vector();
	var topright:Vector = new Vector();
	var botleft:Vector = new Vector();
	var botright:Vector = new Vector();

	public function drawTexture(x:Float, y:Float, texture:Texture, ?origin:Vector, ?scale:Vector, ?rotation:Float, ?clipX:Float, ?clipY:Float, ?clipW:Float, ?clipH:Float, ?col:Color):Void
	{
		setTexture(texture);

		if (clipX == null) clipX = 0;
		if (clipY == null) clipY = 0;
		if (clipW == null) clipW = texture.width;
		if (clipH == null) clipH = texture.height;

		if (col == null) col = Color.white;

		// relative positions
		topleft.set(0, 0);
		topright.set(clipW, 0);
		botleft.set(0, clipH);
		botright.set(clipW, clipH);

		// offset by origin
		if (origin != null && (origin.x != 0 || origin.y != 0))
		{
			topleft.sub(origin);
			topright.sub(origin);
			botleft.sub(origin);
			botright.sub(origin);
		}

		// scale
		if (scale != null && (scale.x != 1 || scale.y != 1))
		{
			topleft.mult(scale);
			topright.mult(scale);
			botleft.mult(scale);
			botright.mult(scale);
		}

		// rotate
		if (rotation != null && rotation != 0)
		{
			var s = Math.sin(rotation);
			var c = Math.cos(rotation);
			topleft.rotate(s, c);
			topright.rotate(s, c);
			botleft.rotate(s, c);
			botright.rotate(s, c);
		}

		// push vertices
		positions.push(x + topleft.x);
		positions.push(y + topleft.y);
		positions.push(x + topright.x);
		positions.push(y + topright.y);
		positions.push(x + botright.x);
		positions.push(y + botright.y);
		positions.push(x + topleft.x);
		positions.push(y + topleft.y);
		positions.push(x + botright.x);
		positions.push(y + botright.y);
		positions.push(x + botleft.x);
		positions.push(y + botleft.y);

		// push uvs
		var uvx = clipX / texture.width;
		var uvy = clipY / texture.height;
		var uvw = clipW / texture.width;
		var uvh = clipH / texture.height;

		uvs.push(uvx);
		uvs.push(uvy);
		uvs.push(uvx + uvw);
		uvs.push(uvy);
		uvs.push(uvx + uvw);
		uvs.push(uvy + uvh);
		uvs.push(uvx);
		uvs.push(uvy);
		uvs.push(uvx + uvw);
		uvs.push(uvy + uvh);
		uvs.push(uvx);
		uvs.push(uvy + uvh);

		add_color(col, 6);
	}

	public function drawSubtexture(x:Float, y:Float, subtexture:Subtexture, ?origin:Vector, ?scale:Vector, ?rotation:Float, ?clipX:Float, ?clipY:Float, ?clipW:Float, ?clipH:Float, ?col:Color): Void
	{
		setTexture(subtexture.texture);

		if (clipX == null) clipX = 0;
		if (clipY == null) clipY = 0;
		if (clipW == null) clipW = subtexture.width;
		if (clipH == null) clipH = subtexture.height;

		if (col == null) col = Color.white;

		// relative positions
		topleft.set(0, 0);
		topright.set(clipW, 0);
		botleft.set(0, clipH);
		botright.set(clipW, clipH);

		// offset by origin
		if (origin != null && (origin.x != 0 || origin.y != 0))
		{
			topleft.sub(origin);
			topright.sub(origin);
			botleft.sub(origin);
			botright.sub(origin);
		}

		// scale
		if (scale != null && (scale.x != 1 || scale.y != 1))
		{
			topleft.mult(scale);
			topright.mult(scale);
			botleft.mult(scale);
			botright.mult(scale);
		}

		// rotate
		if (rotation != null && rotation != 0)
		{
			var s = Math.sin(rotation);
			var c = Math.cos(rotation);
			topleft.rotate(s, c);
			topright.rotate(s, c);
			botleft.rotate(s, c);
			botright.rotate(s, c);
		}

		// push vertices
		positions.push(x + topleft.x);
		positions.push(y + topleft.y);
		positions.push(x + topright.x);
		positions.push(y + topright.y);
		positions.push(x + botright.x);
		positions.push(y + botright.y);
		positions.push(x + topleft.x);
		positions.push(y + topleft.y);
		positions.push(x + botright.x);
		positions.push(y + botright.y);
		positions.push(x + botleft.x);
		positions.push(y + botleft.y);

		// push uvs, pushing them in a small amount to avoid seams
		var uvx = (subtexture.sourceX + clipX + .01) / subtexture.texture.width;
		var uvy = (subtexture.sourceY + clipY + .01) / subtexture.texture.height;
		var uvw = (clipW - .02) / subtexture.texture.width;
		var uvh = (clipH - .02) / subtexture.texture.height;

		uvs.push(uvx);
		uvs.push(uvy);
		uvs.push(uvx + uvw);
		uvs.push(uvy);
		uvs.push(uvx + uvw);
		uvs.push(uvy + uvh);
		uvs.push(uvx);
		uvs.push(uvy);
		uvs.push(uvx + uvw);
		uvs.push(uvy + uvh);
		uvs.push(uvx);
		uvs.push(uvy + uvh);

		add_color(col, 6);
	}

	public function drawTile(x:Float, y:Float, tileset:Tileset, tile:TileData, ?col:Color): Void
	{
		setTexture(tileset.texture.texture);

		if (col == null) col = Color.white;

		var tx = (tile.idx % tileset.tileColumns);
		var ty = Math.floor(tile.idx / tileset.tileColumns);
		var tw = tileset.tileWidth;
		var th = tileset.tileHeight;

		var topLeft = new Vector(-1, -1);
		var topRight = new Vector(1, -1);
		var botLeft = new Vector(-1, 1);
		var botRight = new Vector(1, 1);

		if (tile.flipDiagonally)
		{
			topRight.copy(botLeft);
			botLeft.set(1, -1);
		}
		if (tile.flipX)
		{
			topLeft.x *= -1;
			botLeft.x *= -1;
			topRight.x *= -1;
			botRight.x *= -1;
		}
		if (tile.flipY)
		{
			topLeft.y *= -1;
			topRight.y *= -1;
			botLeft.y *= -1;
			botRight.y *= -1;
		}

		var tileOrigin = new Vector(x, y);
		var tileWidth = new Vector(tw, th);
		var half = new Vector(0.5, 0.5);
		topLeft = topLeft.scale(0.5).add(half).mult(tileWidth).add(tileOrigin);
		topRight = topRight.scale(0.5).add(half).mult(tileWidth).add(tileOrigin);
		botLeft = botLeft.scale(0.5).add(half).mult(tileWidth).add(tileOrigin);
		botRight = botRight.scale(0.5).add(half).mult(tileWidth).add(tileOrigin);

		positions.push(topLeft.x);
		positions.push(topLeft.y);
		positions.push(topRight.x);
		positions.push(topRight.y);
		positions.push(botLeft.x);
		positions.push(botLeft.y);
		positions.push(topRight.x);
		positions.push(topRight.y);
		positions.push(botLeft.x);
		positions.push(botLeft.y);
		positions.push(botRight.x);
		positions.push(botRight.y);

		// use this to push in the UVs a bit to aVoid seems
		var uvx = (tileset.texture.sourceX + tileset.tileSeparationX + tileset.tileMarginX + tx * (tileset.tileWidth + tileset.tileSeparationX) + .01) / tileset.texture.texture.width;
		var uvy = (tileset.texture.sourceY + tileset.tileSeparationY + tileset.tileMarginY + ty * (tileset.tileHeight + tileset.tileSeparationY) + .01) / tileset.texture.texture.height;
		var uvw = (tileset.tileWidth - .02) / tileset.texture.texture.width;
		var uvh = (tileset.tileHeight - .02) / tileset.texture.texture.height;

		uvs.push(uvx);
		uvs.push(uvy);
		uvs.push(uvx + uvw);
		uvs.push(uvy);
		uvs.push(uvx);
		uvs.push(uvy + uvh);
		uvs.push(uvx + uvw);
		uvs.push(uvy);
		uvs.push(uvx);
		uvs.push(uvy + uvh);
		uvs.push(uvx + uvw);
		uvs.push(uvy + uvh);

		add_color(col, 6);
	}

	// GEOMETRY

	function internalSetRectUVs(uvx: Float, uvy: Float, uvw: Float, uvh: Float): Void
	{
		uvs.push(uvx);
		uvs.push(uvy);
		uvs.push(uvx + uvw);
		uvs.push(uvy);
		uvs.push(uvx);
		uvs.push(uvy + uvh);
		uvs.push(uvx + uvw);
		uvs.push(uvy);
		uvs.push(uvx);
		uvs.push(uvy + uvh);
		uvs.push(uvx + uvw);
		uvs.push(uvy + uvh);
	}

	public function drawRect(x:Float, y:Float, w:Float, h:Float, col:Color):Void
	{
		var pixelRect = getCurrentPixelRect();
		if (pixelRect == null) setDrawMode(RenderingContext.TRIANGLES);

		positions.push(x);
		positions.push(y);
		positions.push(x + w);
		positions.push(y);
		positions.push(x);
		positions.push(y + h);
		positions.push(x + w);
		positions.push(y);
		positions.push(x);
		positions.push(y + h);
		positions.push(x + w);
		positions.push(y + h);

		if (pixelRect != null)
		{
			var uvx = pixelRect.x / currentTexture.width;
			var uvy = pixelRect.y / currentTexture.height;
			var uvw = pixelRect.width / currentTexture.width;
			var uvh = pixelRect.height / currentTexture.height;

			internalSetRectUVs(uvx, uvy, uvw, uvh);
		}

		add_color(col, 6);
	}

	function internalDrawTriangle(x1:Float, y1:Float, x2:Float, y2:Float, x3:Float, y3:Float, col:Color, pixelRect:IntRectangle): Void
	{
		positions.push(x1);
		positions.push(y1);
		positions.push(x2);
		positions.push(y2);
		positions.push(x3);
		positions.push(y3);

		if (pixelRect != null)
		{
			var uvx = pixelRect.x / currentTexture.width;
			var uvy = pixelRect.y / currentTexture.height;
			var uvw = pixelRect.width / currentTexture.width;
			var uvh = pixelRect.height / currentTexture.height;

			uvs.push(uvx);
			uvs.push(uvy);
			uvs.push(uvx + uvw);
			uvs.push(uvy);
			uvs.push(uvx);
			uvs.push(uvy + uvh);
		}

		add_color(col, 3);
	}

	public function drawTriangle(x1:Float, y1:Float, x2:Float, y2:Float, x3:Float, y3:Float, col:Color):Void
	{
		var pixelRect = getCurrentPixelRect();
		if (pixelRect == null) setDrawMode(RenderingContext.TRIANGLES);

		internalDrawTriangle(x1, y1, x2, y2, x3, y3, col, pixelRect);
	}

	public function drawTri(p1: Vector, p2: Vector, p3: Vector, col: Color): Void
	{
		var pixelRect = getCurrentPixelRect();
		if (pixelRect == null) setDrawMode(RenderingContext.TRIANGLES);

		internalDrawTriangle(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, col, pixelRect);
	}

	public function drawTris(points: Array<Vector>, offset: Vector, col: Color): Void
	{
		var pixelRect = getCurrentPixelRect();
		if (pixelRect == null) setDrawMode(RenderingContext.TRIANGLES);

		var i = 0;
		while (i < points.length - 2)
		{
			internalDrawTriangle(
				points[i].x + offset.x,
				points[i].y + offset.y,
				points[i + 1].x + offset.x,
				points[i + 1].y + offset.y,
				points[i + 2].x + offset.x,
				points[i + 2].y + offset.y,
				col,
				pixelRect
			);
			i += 3;
		}
	}

	function internalSetQuadsPosition(tl_x:Float, tl_y:Float, tr_x:Float, tr_y:Float, bl_x:Float, bl_y:Float, br_x:Float, br_y:Float): Void
	{
		positions.push(tl_x);
		positions.push(tl_y);
		positions.push(tr_x);
		positions.push(tr_y);
		positions.push(bl_x);
		positions.push(bl_y);
		positions.push(tr_x);
		positions.push(tr_y);
		positions.push(bl_x);
		positions.push(bl_y);
		positions.push(br_x);
		positions.push(br_y);
	}

	/*function internalDrawQuads(tl_x:Float, tl_y:Float, tr_x:Float, tr_y:Float, bl_x:Float, bl_y:Float, br_x:Float, br_y:Float, col:Color, pixelRect:IntRectangle):Void
	{
		internalSetQuadsPosition(tl_x, tl_y, tr_x, tr_y, bl_x, bl_y, br_x, br_y);

		if (pixelRect != null)
		{
			var uvx = pixelRect.x / currentTexture.width;
			var uvy = pixelRect.y / currentTexture.height;
			var uvw = pixelRect.width / currentTexture.width;
			var uvh = pixelRect.height / currentTexture.height;

			internalSetRectUVs(uvx, uvy, uvw, uvh);
		}

		add_color(col, 6);
	}*/

	static final lineThickness = 1.4;

	/*function internalDrawLineQuads(a: Vector, b: Vector, col: Color, pixelRect: IntRectangle, zoom: Float): Void
	{
		var th_half = lineThickness / (zoom * 2);
		var line = Vector.line(a, b);
		var unit = new Vector(line.x, line.y).normalize();
		var perp = new Vector(-unit.y * th_half, unit.x * th_half); // turned right

		internalDrawQuads(a.x - perp.x, a.y - perp.y, b.x - perp.x, b.y - perp.y, a.x + perp.x, a.y + perp.y, b.x + perp.x, b.y + perp.y, col, pixelRect);
	}*/

	public function drawLineQuads(a: Vector, b: Vector, col: Color, ?zoom: Float): Void
	{
		if (zoom == null) zoom = 1;
		else if (zoom == 0) return;

		var pixelRect = getCurrentPixelRect();
		if (pixelRect == null) setDrawMode(RenderingContext.TRIANGLES);

		var th_half = lineThickness / (zoom * 2);
		var line = Vector.line(a, b);
		var unit = new Vector(line.x, line.y).normalize();
		var perp = new Vector(-unit.y * th_half, unit.x * th_half); // turned right

		internalSetQuadsPosition(a.x - perp.x, a.y - perp.y, b.x - perp.x, b.y - perp.y, a.x + perp.x, a.y + perp.y, b.x + perp.x, b.y + perp.y);

		if (pixelRect != null)
		{
			var uvx = pixelRect.x / currentTexture.width;
			var uvy = pixelRect.y / currentTexture.height;
			var uvw = pixelRect.width / currentTexture.width;
			var uvh = pixelRect.height / currentTexture.height;

			internalSetRectUVs(uvx, uvy, uvw, uvh);
		}

		add_color(col, 6);
	}

	public function drawRectLineQuads(rect: Rectangle, col: Color, ?zoom: Float): Void
	{
		if (zoom == null) zoom = 1;
		else if (zoom == 0) return;

		var pixelRect = getCurrentPixelRect();
		if (pixelRect == null) setDrawMode(RenderingContext.TRIANGLES);

		var th_half = lineThickness / (zoom * 2);
		var left = rect.x;
		var top = rect.y;
		var right = rect.x + rect.width;
		var bottom = rect.y + rect.height;

		internalSetQuadsPosition(left, top - th_half, right, top - th_half, left, top + th_half, right, top + th_half);
		internalSetQuadsPosition(right + th_half, top, right + th_half, bottom, right - th_half, top, right - th_half, bottom);
		internalSetQuadsPosition(right, bottom + th_half, left, bottom + th_half, right, bottom - th_half, left, bottom - th_half);
		internalSetQuadsPosition(left - th_half, bottom, left - th_half, top, left + th_half, bottom, left + th_half, top);

		if (pixelRect != null)
		{
			var uvx = pixelRect.x / currentTexture.width;
			var uvy = pixelRect.y / currentTexture.height;
			var uvw = pixelRect.width / currentTexture.width;
			var uvh = pixelRect.height / currentTexture.height;

			for (i in 0...4) internalSetRectUVs(uvx, uvy, uvw, uvh);
		}

		add_color(col, 24);
	}

	public function drawLine(a: Vector, b: Vector, col: Color): Void
	{
		setDrawMode(RenderingContext.LINES);

		positions.push(a.x);
		positions.push(a.y);
		positions.push(b.x);
		positions.push(b.y);

		add_color(col, 2);
	}

	public function drawLineNode(at: Vector, radius: Float, col: Color): Void
	{
		setDrawMode(RenderingContext.LINES);

		var seg = (Math.PI / 2) / 8;
		var last = new Vector(radius, 0);
		var cur = new Vector();

		for (i in 1...8)
		{
			Vector.fromAngle(seg * i, radius, cur);

			positions.push(at.x + last.x);
			positions.push(at.y + last.y);
			positions.push(at.x + cur.x);
			positions.push(at.y + cur.y);
			positions.push(at.x - last.x);
			positions.push(at.y - last.y);
			positions.push(at.x - cur.x);
			positions.push(at.y - cur.y);
			positions.push(at.x + last.x);
			positions.push(at.y - last.y);
			positions.push(at.x + cur.x);
			positions.push(at.y - cur.y);
			positions.push(at.x - last.x);
			positions.push(at.y + last.y);
			positions.push(at.x - cur.x);
			positions.push(at.y + cur.y);

			add_color(col, 8);

			cur.clone(last);
		}
	}

	public function drawCircle(x:Int, y:Int, radius:Float, segments:Int, col:Color):Void
	{
		setDrawMode(RenderingContext.LINES);

		var p:Array<Float> = [x, y, x + radius, y];
		var c:Array<Float> = [];

		for (i in 1...segments)
		{
			var rads = i * (Math.PI * 2) / segments;
			var atX = x + Math.cos(rads) * radius;
			var atY = y + Math.sin(rads) * radius;

			p.push(atX);
			p.push(atY);
			p.push(x);
			p.push(y);
		}

		for (i in 0...Math.floor(p.length / 2)) {
			colors.push(col.r);
			colors.push(col.g);
			colors.push(col.b);
			colors.push(col.a);
		}
	}

	public function drawGrid(gridSize: Vector, gridOffset: Vector, size: Vector, offset: Vector, zoom: Float, col: Color): Void
	{
		setDrawMode(RenderingContext.LINES);

		var minSpace = 10;
		var intX = gridSize.x;
		while (intX * zoom < minSpace)
			intX += gridSize.x;

		var intY = gridSize.y;
		while (intY * zoom < minSpace)
			intY += gridSize.y;

		var i = intX + gridOffset.x + offset.x;
		var until = size.x + offset.x;
		while (i < until)
		{
			positions.push(i);
			positions.push(1 + gridOffset.y + offset.y);
			positions.push(i);
			positions.push(size.y - 1 + gridOffset.y + offset.y);

			add_color(col, 2);

			i += intX;
		}

		i = intY + gridOffset.y + offset.y;
		until = size.y + offset.y;
		while (i < until)
		{
			positions.push(1 + gridOffset.x + offset.x);
			positions.push(i);
			positions.push(size.x - 1 + gridOffset.x + offset.x);
			positions.push(i);

			add_color(col, 2);

			i += intY;
		}
	}

	public function drawRectLines(x:Float, y:Float, w:Float, h:Float, col:Color)
	{
		drawLine(new Vector(x, y), new Vector(x + w, y), col);
		drawLine(new Vector(x + w, y), new Vector(x + w, y + h), col);
		drawLine(new Vector(x + w, y + h), new Vector(x, y + h), col);
		drawLine(new Vector(x, y + h), new Vector(x, y), col);
	}

	public function drawLineRect(rect: Rectangle, col: Color): Void
	{
		setDrawMode(RenderingContext.LINES);

		positions.push(rect.x);
		positions.push(rect.y);
		positions.push(rect.x + rect.width);
		positions.push(rect.y);

		positions.push(rect.x + rect.width);
		positions.push(rect.y);
		positions.push(rect.x + rect.width);
		positions.push(rect.y + rect.height);

		positions.push(rect.x + rect.width);
		positions.push(rect.y + rect.height);
		positions.push(rect.x);
		positions.push(rect.y + rect.height);

		positions.push(rect.x);
		positions.push(rect.y + rect.height);
		positions.push(rect.x);
		positions.push(rect.y);

		add_color(col, 8);
	}

	inline function add_color(col:Color, amt:Int = 1) {
		for (i in 0...(amt))
		{
			colors.push(col.r);
			colors.push(col.g);
			colors.push(col.b);
			colors.push(col.a);
		}
	}

	function get_width():Int return canvas.width;

	function get_height():Int return canvas.height;
}
