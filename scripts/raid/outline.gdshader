shader_type spatial;
// 캐릭터 외곽선 (일러스트처럼 진한 갈색 테두리). 화면 기준 두께라 멀리서도 가까이서도 같은 굵기.
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 line_color : source_color = vec4(0.17, 0.10, 0.07, 1.0);
uniform float width_px = 2.2;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 vn = mat3(MODELVIEW_MATRIX) * NORMAL;
	vec2 off = (PROJECTION_MATRIX * vec4(vn, 0.0)).xy;
	float l = length(off);
	if (l > 0.0001) {
		off /= l;
	}
	clip.xy += off / VIEWPORT_SIZE * width_px * 2.0 * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = line_color.rgb;
}
