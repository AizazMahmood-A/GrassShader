shader_type spatial;
render_mode cull_disabled;

group_uniforms Wind;
uniform sampler2D noise_texture : repeat_enable;

uniform float noise_wind_strength : hint_range(0.0, 10.0) = 2.0;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.0;
uniform float wind_scale = 0.05;
uniform float max_lean_distance = 1.0;

group_uniforms Color;
uniform vec3 base_color : source_color = vec3(0.2, 0.5, 0.1);
uniform vec3 tip_color : source_color = vec3(0.4, 0.5, 0.1);

group_uniforms CubicBazierControlPoints;
uniform vec3 p0 = vec3(0.0, 0.0, 0.0);
uniform vec3 p1 = vec3(0.25, 0.3, 0.25);
uniform vec3 p2 = vec3(0.6, 0.6, 0.6);
uniform vec3 p3 = vec3(0.6, 1.0, 0.6);

group_uniforms;
uniform float grass_width = 0.1;
uniform float grass_density = 1.0;

group_uniforms HashValues;
// Hash functions from:
// https://www.shadertoy.com/view/4djSRW
uniform float HASHSCALE1 = 0.1031;
uniform vec3 HASHSCALE3 = vec3(0.1031, 0.1030, 0.0973);

float hash12(vec2 p)
{
	vec3 pp  = fract(vec3(p.xyx) * HASHSCALE1);
	pp += dot(pp, pp.yzx + 19.19);
	return fract((pp.x + pp.y) * pp.z);
}

vec2 hash22(vec2 p)
{
	vec3 pp = fract(vec3(p.xyx) * HASHSCALE3);
	pp += dot(pp, pp.yzx+19.19);
	return fract((pp.xx+pp.yz)*pp.zy);
}

mat3 rotate_x(float angle) {
    float c = cos(angle);
    float s = sin(angle);
	mat3 rot = mat3(
        vec3(1.0,  0.0, 0.0),
        vec3(0.0,    c,  -s),
        vec3(0.0,    s,   c)
    );
    return rot;
}

mat3 rotate_y(float angle)
{
	float c = cos(angle);
	float s = sin(angle);
	mat3 rot = mat3(
		vec3(c, 0.0, s),
		vec3(0.0, 1.0, 0.0),
		vec3(-s, 0.0, c)
	);
	return rot;
}

mat3 rotate_z(float angle)
{
    float c = cos(angle);
    float s = sin(angle);   
    mat3 rot = mat3(
        vec3(c, -s, 0.0),
        vec3(s,  c, 0.0),
        vec3(0.0, 0.0, 1.0)
	);
	return rot;
}

float ease_out_quad(float x){
	return 1.0 - (1.0 - x) * (1.0 - x);
}

float ease_in_quad(float x){
	return x * x;
}

vec3 eval_cubic_bezier(vec3 a, vec3 b, vec3 c, vec3 d, float t){
	float u = 1.0 - t;
	float tt = t * t;
	float uu = u * u;
	float uuu = uu * u;
	float ttt = t * t * t;
	
	vec3 value = (uuu * a) + (3.0 * uu * t * b) + (3.0 * u * tt * c) + (ttt * d); 
	
	return value;
}

float remap(float value, float in_min, float in_max, float out_min, float out_max) {
    return out_min + (value - in_min) * (out_max - out_min) / (in_max - in_min);
}

varying float testf;
varying vec4 testv4;
void vertex() {
	float height = 1.0 - UV.y;
	vec3 vertex_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	//// Blade Rotation
	float per_blade_hash = hash12(NODE_POSITION_WORLD.xz);
	float randomAngle = per_blade_hash * 2.0 * PI;
	mat3 rot = rotate_y(randomAngle);
	
	VERTEX = rot * VERTEX;
	NORMAL = rot * NORMAL;
	////

	////// Wind Displacement and Grass Curve
	vec2 noise_uv = (vertex_world_position.xz * 0.01) + (TIME * wind_speed * 0.02);
    float noise_val = texture(noise_texture, noise_uv).r;

    float angle_rad = (noise_val * (TAU))+ radians(randomAngle);
    vec2 wind_dir = vec2(cos(angle_rad), sin(angle_rad));
    float strength_noise = texture(noise_texture, noise_uv + vec2(0.47, 0.61)).r;
    float wind_strength = strength_noise * noise_wind_strength;
    vec3 wind_vector = vec3(wind_dir.x, 0.0, wind_dir.y) * wind_strength * max_lean_distance;
	
	vec3 m_p1 = wind_vector + p1 * sin(TIME);
	vec3 m_p2 = wind_vector + p2;
	vec3 m_p3 = wind_vector + p3;
	
	float t = height;
	vec3 bend = eval_cubic_bezier(p0, m_p1, m_p2, m_p3, t);
	VERTEX.xz += bend.xz;
	////

	//// View Space Thickening
	vertex_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 vertex_view = (VIEW_MATRIX * vec4(vertex_world_position, 1.0)).xyz;
	vec3 normal_world = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 cam_offset = vertex_world_position - CAMERA_POSITION_WORLD;
	float cam_distance = length(cam_offset);
	
	float view_dot_normal =  dot(normalize(normal_world), normalize(cam_offset));
	float view_space_thicken_factor = ease_out_quad(1.0 - abs(view_dot_normal));
	view_space_thicken_factor *= smoothstep(0.0, 0.2, view_dot_normal);
	vertex_view.x += view_space_thicken_factor * grass_width;
	
	mat4 inv_modelview = inverse(MODEL_MATRIX) * INV_VIEW_MATRIX;
	VERTEX = (inv_modelview * vec4(vertex_view, 1.0)).xyz;
	////
}

void fragment() {
	float height = 1.0 - UV.y;
	vec3 diffuse_color = mix(base_color, tip_color, ease_in_quad(height));
	
	float blend_factor = length(VERTEX)*0.03;
	NORMAL = mix(NORMAL, vec3(0, 1, 0), ease_in_quad(blend_factor));
	
	float aoForDensity = mix(1.0, 0.25, grass_density);
	AO = mix(aoForDensity, 1.0, ease_in_quad(height));
	
	vec3 final_color = diffuse_color * mix(0.1, 1.0, (height));
	
	ALBEDO = final_color;//testv4.xxx;
}

//void light() {
	//// Called for every pixel for every light affecting the material.
	//// Uncomment to replace the default light processing function with this one.
//}
