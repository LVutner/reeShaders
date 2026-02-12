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

uniform int TINYCA_INT <
	ui_type = "combo";
    ui_label = "Intensity";
	ui_items = "Subtle\0Medium\0Annoying\0";
> = 1;

static const float2 mag_coeffs[3] = 
{
	float2(0.9966, 0.9980),
	float2(0.9922, 0.9953),
	float2(0.9868, 0.9921)
};

float4 lv_tinyca(float4 hpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float4 center = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0));

    float2 from_center = texcoord - 0.5;
    float4 rg_shift = from_center.xyxy * mag_coeffs[TINYCA_INT].xxyy + 0.5;

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
