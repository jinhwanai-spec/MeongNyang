shader_type canvas_item;
// 2.5D 벽 가림: 플레이어 앞(남쪽)에 있는 벽은 플레이어 주변만 반투명하게 뚫어 보여 준다
uniform vec2 ppos = vec2(-9999.0);
uniform float radius = 74.0;
varying vec2 wpos;
varying float base_y;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	base_y = MODEL_MATRIX[3].y;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (base_y > ppos.y + 2.0) {
		vec2 d = (wpos - (ppos + vec2(0.0, -26.0))) * vec2(1.0, 0.8);
		float k = smoothstep(radius * 0.55, radius, length(d));
		// 가장자리에 살짝 디더를 넣어 '구멍' 느낌을 줄인다
		c.a *= mix(0.22, 1.0, k);
	}
	COLOR = c * COLOR;
}
