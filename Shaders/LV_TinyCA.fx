/*
	Copyright (c) 2026 LVutner

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.


	[TinyCA]
	Yet another chromatic abberation shader.

	Author: LVutner
	Site: github.com/LVutner/reeShaders
*/

#include "ReShade.fxh"

uniform float TINYCA_INT <
	ui_type = "slider";
	ui_min = 0.0; 
	ui_max = 1.0;
	ui_tooltip = "Intensity";
> = 0.125;

float4 lv_tinyca(float4 hpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float4 center = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0));

	const float2 magnification_coeff = 1.0 + float2(-0.0132, -0.0079) * TINYCA_INT;

    float2 from_center = texcoord - 0.5;
    float4 rg_shift = from_center.xyxy * magnification_coeff.xxyy + 0.5;

    center.x = tex2Dlod(ReShade::BackBuffer, float4(rg_shift.xy, 0.0, 0.0)).x;
    center.y = tex2Dlod(ReShade::BackBuffer, float4(rg_shift.zw, 0.0, 0.0)).y;

	return center;
}

technique TinyCA
<
	ui_label = "LVutner: TinyCA";
	ui_tooltip =
	"========================   \n"
	"        TinyCA 			\n"
	"     So cinematic!!!       \n"
	"========================   \n";
>
{
	pass
	{
		PixelShader = lv_tinyca;
		VertexShader = PostProcessVS;
	}
}
