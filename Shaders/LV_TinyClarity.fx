/*
	Copyright (c) 2026 LVutner

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.


	[TinyClarity]
	Basic clarity shader that aims to minimalize ringing artifacts.

	Author: LVutner
	Credits: MartyMcFly (3x3 upscaling offsets)
	Site: github.com/LVutner/reeShaders
*/

#include "ReShade.fxh"

uniform float TINYCLARITY_INT
<
	ui_type = "slider";
	ui_min = -0.500; 
	ui_max = 1.0;
	ui_tooltip = "Intensity";
> = 0.5;

texture2D t_tinyclarity_layer
{
	Width = BUFFER_WIDTH >> 1;
	Height = BUFFER_HEIGHT >> 1;
	Format = RG8;
};

sampler2D s_tinyclarity_layer
{
	Texture = t_tinyclarity_layer;
	MinFilter = LINEAR;
	MipFilter = LINEAR;
	MagFilter = LINEAR;
};

storage2D u_tinyclarity_layer
{
	Texture = t_tinyclarity_layer;
};

static const int2 offsets_3x3[8] = 
{
	int2(-1, -1), 
	int2(0, -1),
	int2(1, -1),
	int2(-1, 0),
	int2(1, 0),
	int2(-1, 1),
	int2(0, 1),
	int2(1, 1),
};

groupshared float2 lds_luma_guide[576]; //24x24, 4 pix border

void lv_tinyclarity_generate_layers(uint3 DTid : SV_DispatchThreadID, uint3 GTid : SV_GroupThreadID, uint3 Gid : SV_GroupID, uint Tid : SV_GroupIndex)
{
	const float2 rcp_res = BUFFER_PIXEL_SIZE * 2.0;

	int2 base_coord = Gid.xy * 16 - 4;	

	//prefetch luma + guide into LDS
	for(uint i = Tid; i < 576; i += 256)
	{
		int2 sample_coord = base_coord + uint2(i % 24, i / 24);
		sample_coord = clamp(sample_coord, 0, uint2(BUFFER_SCREEN_SIZE) - 1);

		float2 texcoord = (float2(sample_coord) + 0.5) * rcp_res;

		float3 color = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0)).xyz;

		float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
		float guide = min(color.x, min(color.y, color.z));

		lds_luma_guide[i] = float2(luma, guide);
	}
	barrier();

	int2 lds_coord = GTid.xy + 4;
	uint lds_idx = lds_coord.y * 24 + lds_coord.x;
	float2 center_lds = lds_luma_guide[lds_idx];

	float4 blurred = float4(0.0, 0.0, 0.0, 1.0);

	[unroll]
	for(uint j = 0; j < 3; j++)
	{
		uint spread = 1 << j;

		float2 current_blur = lds_luma_guide[lds_idx];
		float2 blur_weight = float2(current_blur.x, 1.0);

		for(uint k = 0; k < 8; k++)
		{
			int2 sample_pos = lds_coord + offsets_3x3[k] * spread;
		
			float2 sampled_data = lds_luma_guide[sample_pos.y * 24 + sample_pos.x];

			float weight = exp(-abs(sampled_data.y - center_lds.y) * 8.0);

			blur_weight += float2(sampled_data.x, 1.0) * weight;
		}

		blurred[j] = blur_weight.x * rcp(blur_weight.y);
		lds_luma_guide[lds_idx] = float2(blurred[j], center_lds.y);

		if(j < 2)
		{
			barrier();
		}
	}

	float3 weights = float3(0.3, 0.7, 1.0);
	float merged = dot(blurred.xyz, weights);
	merged /= dot(weights, 1.0);

	tex2Dstore(u_tinyclarity_layer, DTid.xy, float2(merged, center_lds.y).xyyy);
}

float4 lv_tinyclarity_final(float4 hpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	//https://bartwronski.com/2019/09/22/local-linear-models-guided-filter/
	//upscale the blurred luma. its mediocre, i only care about the edges
	float4 offsets = float4(0.5, 1.0, 1.0, -0.5) * BUFFER_PIXEL_SIZE.xyxy;	

	float2 temp = tex2Dlod(s_tinyclarity_layer, float4(texcoord, 0.0, 0.0)).xy;
	float4 moments = float4(temp.y, temp.y * temp.y, temp.y * temp.x, temp.x);

	temp = tex2Dlod(s_tinyclarity_layer, float4(texcoord + offsets.xy, 0.0, 0.0)).xy;
	moments += float4(temp.y, temp.y * temp.y, temp.y * temp.x, temp.x);

	temp = tex2Dlod(s_tinyclarity_layer, float4(texcoord - offsets.xy, 0.0, 0.0)).xy;
	moments += float4(temp.y, temp.y * temp.y, temp.y * temp.x, temp.x);

	temp = tex2Dlod(s_tinyclarity_layer, float4(texcoord + offsets.zw, 0.0, 0.0)).xy;
	moments += float4(temp.y, temp.y * temp.y, temp.y * temp.x, temp.x);

	temp = tex2Dlod(s_tinyclarity_layer, float4(texcoord - offsets.zw, 0.0, 0.0)).xy;
	moments += float4(temp.y, temp.y * temp.y, temp.y * temp.x, temp.x);

	moments *= 0.2;

	float alpha = (moments.z - moments.x * moments.w) / max(moments.y - moments.x * moments.x, 1e-5);
	float beta = moments.w - alpha * moments.x;

	float4 center = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0));

	float luma = dot(center.xyz, float3(0.2126, 0.7152, 0.0722));
	float guide_fullres = min(center.x, min(center.y, center.z));

	float diff = luma - saturate(alpha * guide_fullres + beta);
	diff *= TINYCLARITY_INT * exp(-550.0 * diff * diff); //i could use weighting from tinysharpen but it resulted in more ringing

	center.xyz *= (luma + diff) / (luma + 1e-5);

	return center;
}

technique TinyClarity
<
	ui_label = "LVutner: TinyClarity";
	ui_tooltip =
	"========================  \n"
	"      TinyClarity   	   \n"
	"    I can clearly!!!      \n"
	"========================  \n";
>
{
	pass lv_tinyclarity_generate
	{ 
		ComputeShader = lv_tinyclarity_generate_layers<16, 16, 1>;
		DispatchSizeX = ((BUFFER_WIDTH - 1) / 32) + 1;
		DispatchSizeY = ((BUFFER_HEIGHT - 1) / 32) + 1;
		DispatchSizeZ = 1;
	}

	pass lv_tinyclarity_final
	{
		VertexShader = PostProcessVS;
		PixelShader = lv_tinyclarity_final;
	}
}
