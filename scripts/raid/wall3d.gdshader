shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// 3D 벽: 블렌더에서 구운 텍스처 + 플레이어 앞을 가리는 부분은 디더로 뚫어 보여 준다
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 ppos = vec3(-999.0);
uniform vec2 pscreen = vec2(-9.0);
uniform float aspect = 1.7778;
uniform float radius = 0.13;
uniform float tint = 1.0;
varying vec3 wpos;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 플레이어보다 카메라 쪽(남쪽)에 있는 벽만 뚫는다
	if (wpos.z > ppos.z + 0.12 && wpos.y > 0.45) {
		vec2 d = (SCREEN_UV - pscreen) * vec2(aspect, 1.0);
		float keep = smoothstep(radius * 0.6, radius, length(d));
		keep = max(keep, 0.12);
		ivec2 f = ivec2(FRAGCOORD.xy) % 4;
		float th = (BAYER[f.y * 4 + f.x] + 0.5) / 16.0;
		if (th > keep) {
			discard;
		}
	}
	ALBEDO = texture(tex, UV).rgb * tint;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}
