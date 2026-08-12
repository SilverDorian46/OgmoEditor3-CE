attribute vec2 a_position;
attribute vec2 a_textcoord;
attribute vec4 a_color;

uniform mat3 matrix;
uniform mat4 orthoMatrix;

varying highp vec2 v_textcoord;
varying lowp vec4 v_color;

void main(void)
{
	gl_Position = orthoMatrix * vec4(matrix * vec3(a_position, 1.0), 1.0);
	v_textcoord = a_textcoord;
	v_color = a_color;
}