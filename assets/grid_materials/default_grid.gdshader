// NOTE: Shader automatically converted from Godot Engine 4.3.stable's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 albedo : source_color = vec3(0.5);
uniform sampler2D grid_texture : source_color, filter_linear_mipmap, repeat_enable;

uniform float fill_roughness : hint_range(0.0, 1.0) = 0.5;
uniform float fill_specular : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float fill_metallic : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec3 line_albedo : source_color = vec3(1.0);
uniform float line_roughness : hint_range(0.0, 1.0) = 0.5;
uniform float line_specular : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float line_metallic : hint_range(0.0, 1.0, 0.01) = 0.0;

uniform float uv_blend_sharpness : hint_range(0.001, 150.0, 0.001) = 1.0;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);

varying vec3 uv_triplanar_pos;
varying vec3 uv_power_normal;

vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
    vec4 samp = vec4(0.0);
    samp += texture(p_sampler, p_triplanar_pos.xy) * p_weights.z;
    samp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y;
    samp += texture(p_sampler, p_triplanar_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
    return samp;
}

void vertex() {
    vec3 normal = NORMAL;

    TANGENT = vec3(0.0, 0.0, -1.0) * abs(normal.x);
    TANGENT += vec3(1.0, 0.0, 0.0) * abs(normal.y);
    TANGENT += vec3(1.0, 0.0, 0.0) * abs(normal.z);
    TANGENT = normalize(TANGENT);

    BINORMAL = vec3(0.0, 1.0, 0.0) * abs(normal.x);
    BINORMAL += vec3(0.0, 0.0, -1.0) * abs(normal.y);
    BINORMAL += vec3(0.0, 1.0, 0.0) * abs(normal.z);
    BINORMAL = normalize(BINORMAL);

    uv_power_normal = pow(abs(NORMAL), vec3(uv_blend_sharpness));
    uv_power_normal /= dot(uv_power_normal, vec3(1.0));
    uv_triplanar_pos = VERTEX * uv_scale + uv_offset;
    uv_triplanar_pos *= vec3(1.0, -1.0, 1.0);
}

void fragment() {
    vec4 texel = triplanar_texture(grid_texture, uv_power_normal, uv_triplanar_pos);
    ALBEDO = albedo.rgb * texel.r;
    ALBEDO = mix(ALBEDO, line_albedo, texel.g);

    METALLIC = fill_metallic;
    METALLIC = mix(METALLIC, line_metallic, texel.g);
    SPECULAR = fill_specular;
    SPECULAR = mix(SPECULAR, line_specular, texel.g);
    ROUGHNESS = fill_roughness;
    ROUGHNESS = mix(ROUGHNESS, line_roughness, texel.g);
}
