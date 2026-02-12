/*
	Copyright (c) 2026 LVutner

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.


	[TinySharpen]
	A shrimple & subtle sharpen effect for ReShade.

	Author: LVutner
	Site: github.com/LVutner/reeShaders
*/

#include "ReShade.fxh"

uniform float TINYSHARP_INT <
	ui_type = "drag";
	ui_label = "Intensity";
	ui_min = 0.0;
	ui_max = 2.0;
> = 1.0;

float4 lv_tinysharpen(float4 hpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float4 center = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0));

#if __RENDERER__ >= 0xb000 //DX11+
	float2 gather_texcoord = texcoord + 0.5 * rcp(float2(BUFFER_WIDTH, BUFFER_HEIGHT));

	float2 gather0 = tex2DgatherG(ReShade::BackBuffer, gather_texcoord).xz;
	float2 gather1 = tex2DgatherG(ReShade::BackBuffer, gather_texcoord, int2(-1, -1)).xz;
#else
	float2 gather0 = center.yy;
	gather0.x = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0), int2(0, 1)).y;
	gather0.y = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0), int2(1, 0)).y;
	
	float2 gather1;
	gather1.x = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0), int2(0, -1)).y;
	gather1.y = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0), int2(-1, 0)).y;
#endif

	float4 t = float4(gather0.xy, gather1.xy);
	float laplacian = center.y * 4.0 - dot(t, 1.0);

	laplacian *= rcp(1.0 + 30.0 * abs(laplacian));
	laplacian *= sqrt(dot(t, t) + 1e-6); //scale it down, to prevent oversharpening in shadows

	center.xyz *= (TINYSHARP_INT * laplacian + center.y) / (center.y + 1e-6);
	return center;
}

technique TinySharpen
<
	ui_label = "LVutner: TinySharpen";
	ui_tooltip =
	"========================   \n"
	"      TinySharpen 			\n"
	"  Size doesn't matter.     \n"
	"========================   \n";
>
{
	pass
	{
		PixelShader = lv_tinysharpen;
		VertexShader = PostProcessVS;
	}
}
