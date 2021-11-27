//
//  Shaders.metal
//  MetalMeshViewer
//
//  Created by Andreas Bærentzen on 06/11/2021.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

typedef struct
{
    float3 position [[attribute(VertexAttributePosition)]];
    float3 normal [[attribute(VertexAttributeNormal)]];
} Vertex;

typedef struct
{
    float3 eye_pos;
    float4 position [[position]];
    float3 normal;
} ColorInOut;

vertex ColorInOut vertexShader(Vertex in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    ColorInOut out;

    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.normal = normalize(float3(uniforms.modelViewMatrix * float4(in.normal, 0.0)));
    out.eye_pos = float3(uniforms.modelViewMatrix * position);
    return out;
}

fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               texture2d<half> colorMap     [[ texture(TextureIndexColor) ]])
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);
    float3 normal = normalize(in.normal);
    float2 texCoord = float2(0.5+0.5*normal[0], 0.5-0.5*normal[1]);
    return float4(colorMap.sample(colorSampler, texCoord.xy));
}



fragment float4 fragmentShader_wire(ColorInOut in [[stage_in]],
                               float3 barycentric_coord [[barycentric_coord]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               texture2d<half> colorMap     [[ texture(TextureIndexColor) ]])
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);
    float3 normal = normalize(in.normal);
    float3 ed = barycentric_coord;
    float3 deddx = dfdx(barycentric_coord);
    float3 deddy = dfdy(barycentric_coord);
    ed[0] /= length(float2(deddx[0],deddy[0]));
    ed[1] /= length(float2(deddx[1],deddy[1]));
    ed[2] /= length(float2(deddx[2],deddy[2]));
    float edge = min3(ed[0],ed[1],ed[2]);
    float2 texCoord = float2(0.5+0.5*normal[0], 0.5-0.5*normal[1]);
    return float4(colorMap.sample(colorSampler, texCoord.xy))*(float4(0.4,0.2,0.0,0)+float4(0.6,0.8,1,0)*smoothstep(1.0,2.0, edge));
}

typedef struct
{
    float3 eye_pos;
    float4 position [[position]];
    float3 normal;
} ColorInOut_flat;


vertex ColorInOut_flat vertexShader_flat(Vertex in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    ColorInOut_flat out;

    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.normal = normalize(float3(uniforms.modelViewMatrix * float4(in.normal, 0.0)));
    out.eye_pos = float3(uniforms.modelViewMatrix * position);
    return out;
}


fragment float4 fragmentShader_flat(ColorInOut_flat in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               texture2d<half> colorMap     [[ texture(TextureIndexColor) ]])
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);
    float3 t0 = dfdx(float3(in.eye_pos));
    float3 t1 = dfdy(float3(in.eye_pos));
    float3 normal = -normalize(cross(t0, t1));
    float2 texCoord = float2(0.5+0.5*normal[0], 0.5-0.5*normal[1]);
    return float4(colorMap.sample(colorSampler, texCoord.xy));
}

fragment float4 fragmentShader_flat_wire(ColorInOut_flat in [[stage_in]],
                               float3 barycentric_coord [[barycentric_coord]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               texture2d<half> colorMap     [[ texture(TextureIndexColor) ]])
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);
    float3 t0 = dfdx(float3(in.eye_pos));
    float3 t1 = dfdy(float3(in.eye_pos));
    float3 normal = -normalize(cross(t0, t1));
    float3 ed = barycentric_coord;
    float3 deddx = dfdx(barycentric_coord);
    float3 deddy = dfdy(barycentric_coord);
    ed[0] /= length(float2(deddx[0],deddy[0]));
    ed[1] /= length(float2(deddx[1],deddy[1]));
    ed[2] /= length(float2(deddx[2],deddy[2]));
    float edge = min3(ed[0],ed[1],ed[2]);
    float2 texCoord = float2(0.5+0.5*normal[0], 0.5-0.5*normal[1]);
    return float4(colorMap.sample(colorSampler, texCoord.xy))*(float4(0.4,0.2,0.0,0)+float4(0.6,0.8,1,0)*smoothstep(1.0, 2.0, edge));
}
