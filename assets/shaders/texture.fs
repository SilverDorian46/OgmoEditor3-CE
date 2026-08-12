precision mediump float;
uniform float alpha;
uniform sampler2D texture;
varying vec2 v_textcoord;
varying vec4 v_color;

void main(void)
{
	gl_FragColor = texture2D(texture, v_textcoord) * vec4(v_color.rgb, v_color.a * alpha);
}