#define XBR_SCALE 2.0
#define XBR_Y_WEIGHT 48.0
#define XBR_EQ_THRESHOLD 15.0
#define XBR_LV2_COEFFICIENT 2.0
// END PARAMETERS //

/* COMPATIBILITY 
   - HLSL compilers
*/

/*
   Hyllian's xBR-lv2 Shader
   Port to HLSL, for Dungeon And Fighter Project.
   
   Copyright (C) 2011-2015 Hyllian - sergiogdb@gmail.com
   Copyright (C) 2015-2016, NEOPLE Corporation. Morph - morph@neople.co.kr

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
   THE SOFTWARE.

   Incorporates some of the ideas from SABR shader. Thanks to Joshua Street.
*/

// Uncomment just one of the three params below to choose the corner detection
//#define CORNER_A
//#define CORNER_B
#define CORNER_C
//#define CORNER_D

#ifndef CORNER_A
  #define SMOOTH_TIPS
#endif

const static float4 Ao = float4( 1.0, -1.0, -1.0, 1.0 );
const static float4 Bo = float4( 1.0,  1.0, -1.0,-1.0 );
const static float4 Co = float4( 1.5,  0.5, -0.5, 0.5 );
const static float4 Ax = float4( 1.0, -1.0, -1.0, 1.0 );
const static float4 Bx = float4( 0.5,  2.0, -0.5,-2.0 );
const static float4 Cx = float4( 1.0,  1.0, -0.5, 0.0 );
const static float4 Ay = float4( 1.0, -1.0, -1.0, 1.0 );
const static float4 By = float4( 2.0,  0.5, -2.0,-0.5 );
const static float4 Cy = float4( 2.0,  0.0, -1.0, 0.5 );
const static float4 Ci = float4(0.25, 0.25, 0.25, 0.25);

const static float3x3 yuv          = float3x3(0.299, 0.587, 0.114, -0.169, -0.331, 0.499, 0.499, -0.418, -0.0813);
const static float4   epsilon = float4(1e-12, 0.0, 0.0, 0.0);   

float4 df(float4 A, float4 B)
{
	return float4(abs(A-B));
}

float c_df(float3 c1, float3 c2)
{
	float3 df = abs(c1 - c2);
	return df.r + df.g + df.b;
}

bool4 eq(float4 A, float4 B)
{
	return (df(A, B) < float4(XBR_EQ_THRESHOLD, 0.0, 50.0, 1.0));
}

float4 weighted_distance(float4 a, float4 b, float4 c, float4 d, float4 e, float4 f, float4 g, float4 h)
{
	return (df(a,b) + df(a,c) + df(d,e) + df(d,f) + 4.0*df(g,h));
}

float2 texture_size;
struct out_vertex
{
	float4 position : POSITION;
	float4 color    : COLOR;
	float2 texCoord1 : TEXCOORD0;
	float4 t1       : TEXCOORD1;
	float4 t2       : TEXCOORD2;
	float4 t3       : TEXCOORD3;
	float4 t4       : TEXCOORD4;
	float4 t5       : TEXCOORD5;
	float4 t6       : TEXCOORD6;
	float4 t7       : TEXCOORD7;
};

struct VS_INPUT
{
	float4 mPosition: POSITION;
	float4 mColor	: COLOR;
	float2 mUV		: TEXCOORD0;
};

/*    VERTEX_SHADER    */
out_vertex main_vertex(VS_INPUT Input)
{
	out_vertex OUT = (out_vertex)0;

	OUT.position = Input.mPosition;
	OUT.color = Input.mColor;

	float2 ps = float2(1.0/texture_size.x, 1.0/texture_size.y);
	float dx = ps.x;
	float dy = ps.y;

	//    A1 B1 C1
	// A0  A  B  C C4
	// D0  D  E  F F4
	// G0  G  H  I I4
	//    G5 H5 I5

	// This line fix a bug in ATI cards.
	float2 texCoord = Input.mUV + float2(0.0000001, 0.0000001);

	OUT.texCoord1 = texCoord;
	OUT.t1 = texCoord.xxxy + float4( -dx, 0, dx,-2.0*dy); // A1 B1 C1
	OUT.t2 = texCoord.xxxy + float4( -dx, 0, dx,    -dy); //  A  B  C
	OUT.t3 = texCoord.xxxy + float4( -dx, 0, dx,      0); //  D  E  F
	OUT.t4 = texCoord.xxxy + float4( -dx, 0, dx,     dy); //  G  H  I
	OUT.t5 = texCoord.xxxy + float4( -dx, 0, dx, 2.0*dy); // G5 H5 I5
	OUT.t6 = texCoord.xyyy + float4(-2.0*dx,-dy, 0,  dy); // A0 D0 G0
	OUT.t7 = texCoord.xyyy + float4( 2.0*dx,-dy, 0,  dy); // C4 F4 I4

	return OUT;
}

texture SceneTexture_Tex;
sampler2D decal = sampler_state
{
	Texture	  = (SceneTexture_Tex);
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = NONE;
	AddressU  = Border;
	AddressV  = Border;
	AddressW  = Border;
};

struct PS_INPUT
{
	float4 position : POSITION;
	float4 color    : COLOR;
	float2 texCoord1 : TEXCOORD0;
	float4 t1       : TEXCOORD1;
	float4 t2       : TEXCOORD2;
	float4 t3       : TEXCOORD3;
	float4 t4       : TEXCOORD4;
	float4 t5       : TEXCOORD5;
	float4 t6       : TEXCOORD6;
	float4 t7       : TEXCOORD7;
};

/*    FRAGMENT SHADER    */
float4 main_fragment(PS_INPUT VAR) : COLOR
{
	bool4 edri, edr, edr_left, edr_up, px; // px = pixel, edr = edge detection rule
	bool4 interp_restriction_lv0, interp_restriction_lv1, interp_restriction_lv2_left, interp_restriction_lv2_up;
	float4 fx, fx_left, fx_up; // inequations of straight lines.

	float4 delta         = float4(1.0/XBR_SCALE, 1.0/XBR_SCALE, 1.0/XBR_SCALE, 1.0/XBR_SCALE);
	float4 deltaL        = float4(0.5/XBR_SCALE, 1.0/XBR_SCALE, 0.5/XBR_SCALE, 1.0/XBR_SCALE);
	float4 deltaU        = deltaL.yxwz;

	float2 fp = frac(VAR.texCoord1*texture_size);

	float3 A1 = tex2D(decal, VAR.t1.xw).rgb;
	float3 B1 = tex2D(decal, VAR.t1.yw).rgb;
	float3 C1 = tex2D(decal, VAR.t1.zw).rgb;

	float3 A  = tex2D(decal, VAR.t2.xw).rgb;
	float3 B  = tex2D(decal, VAR.t2.yw).rgb;
	float3 C  = tex2D(decal, VAR.t2.zw).rgb;

	float3 D  = tex2D(decal, VAR.t3.xw).rgb;
	float3 E  = tex2D(decal, VAR.t3.yw).rgb;
	float3 F  = tex2D(decal, VAR.t3.zw).rgb;

	float3 G  = tex2D(decal, VAR.t4.xw).rgb;
	float3 H  = tex2D(decal, VAR.t4.yw).rgb;
	float3 I  = tex2D(decal, VAR.t4.zw).rgb;

	float3 G5 = tex2D(decal, VAR.t5.xw).rgb;
	float3 H5 = tex2D(decal, VAR.t5.yw).rgb;
	float3 I5 = tex2D(decal, VAR.t5.zw).rgb;

	float3 A0 = tex2D(decal, VAR.t6.xy).rgb;
	float3 D0 = tex2D(decal, VAR.t6.xz).rgb;
	float3 G0 = tex2D(decal, VAR.t6.xw).rgb;

	float3 C4 = tex2D(decal, VAR.t7.xy).rgb;
	float3 F4 = tex2D(decal, VAR.t7.xz).rgb;
	float3 I4 = tex2D(decal, VAR.t7.xw).rgb;

	float4 b = mul( float4x3(B, D, H, F), XBR_Y_WEIGHT*yuv[0] );
	float4 c = mul( float4x3(C, A, G, I), XBR_Y_WEIGHT*yuv[0] );
	float4 e = mul( float4x3(E, E, E, E), XBR_Y_WEIGHT*yuv[0] );
	float4 d = b.yzwx;
	float4 f = b.wxyz;
	float4 g = c.zwxy;
	float4 h = b.zwxy;
	float4 i = c.wxyz;

	float4 i4 = mul( float4x3(I4, C1, A0, G5), XBR_Y_WEIGHT*yuv[0] );
	float4 i5 = mul( float4x3(I5, C4, A1, G0), XBR_Y_WEIGHT*yuv[0] );
	float4 h5 = mul( float4x3(H5, F4, B1, D0), XBR_Y_WEIGHT*yuv[0] );
	float4 f4 = h5.yzwx;

	// These inequations define the line below which interpolation occurs.
	fx      = (Ao*fp.y+Bo*fp.x); 
	fx_left = (Ax*fp.y+Bx*fp.x);
	fx_up   = (Ay*fp.y+By*fp.x);

    interp_restriction_lv1		= interp_restriction_lv0 = ((e!=f) && (e!=h));

#ifdef CORNER_B
	interp_restriction_lv1		= (interp_restriction_lv0  &&  ( !eq(f,b) && !eq(h,d) || eq(e,i) && !eq(f,i4) && !eq(h,i5) || eq(e,g) || eq(e,c) ) );
#endif
#ifdef CORNER_D
	float4 c1 = i4.yzwx;
	float4 g0 = i5.wxyz;
	interp_restriction_lv1		= (interp_restriction_lv0  &&  ( !eq(f,b) && !eq(h,d) || eq(e,i) && !eq(f,i4) && !eq(h,i5) || eq(e,g) || eq(e,c) ) && (f!=f4 && f!=i || h!=h5 && h!=i || h!=g || f!=c || eq(b,c1) && eq(d,g0)));
#endif
#ifdef CORNER_C
	interp_restriction_lv1		= (interp_restriction_lv0  && ( !eq(f,b) && !eq(f,c) || !eq(h,d) && !eq(h,g) || eq(e,i) && (!eq(f,f4) && !eq(f,i4) || !eq(h,h5) && !eq(h,i5)) || eq(e,g) || eq(e,c)) );
#endif

	interp_restriction_lv2_left = ((e!=g) && (d!=g));
	interp_restriction_lv2_up   = ((e!=c) && (b!=c));

	float4 fx45i = saturate((fx      + delta  -Co - Ci)/(2*delta ));
	float4 fx45  = saturate((fx      + delta  -Co     )/(2*delta ));
	float4 fx30  = saturate((fx_left + deltaL -Cx     )/(2*deltaL));
	float4 fx60  = saturate((fx_up   + deltaU -Cy     )/(2*deltaU));

    edri     = (weighted_distance( e, c, g, i, h5, f4, h, f) < weighted_distance( h, d, i5, f, i4, b, e, i));
	edr      =  edri && interp_restriction_lv1;
	edr_left = ((XBR_LV2_COEFFICIENT*df(f,g)) <= df(h,c)) && interp_restriction_lv2_left && edr;
	edr_up   = (df(f,g) >= (XBR_LV2_COEFFICIENT*df(h,c))) && interp_restriction_lv2_up && edr;

	fx45i = (edri && interp_restriction_lv0)*fx45i;
	fx45 = edr*fx45;
	fx30 = edr_left*fx30;
	fx60 = edr_up*fx60;

	px = (df(e,f) <= df(e,h));

#ifdef SMOOTH_TIPS
	float4 maximos = max(max(fx30, fx60), max(fx45, fx45i)) + epsilon;
#else
	float4 maximos = max(max(fx30, fx60), fx45) + epsilon;
#endif

	float top = max(max(maximos.x, maximos.y), max(maximos.z, maximos.w));

	float4 color_picker = step(top, maximos);

    float4x3 colors = float4x3(lerp(H, F, px.x),
                                lerp(F, B, px.y),
                                lerp(B, D, px.z),
                                lerp(D, H, px.w));

    float3 res = lerp(E, mul(color_picker, colors), top - epsilon.x);

	return float4(res, 1.0);
}

//--------------------------------------------------------------//
// Technique Section
//--------------------------------------------------------------//
technique xBR_LV2
{
	pass p0
	{		
		AlphaBlendEnable = FALSE;
		ZEnable = FALSE;
		CULLMODE = CCW;

		VertexShader = compile vs_3_0 main_vertex();
		PixelShader = compile ps_3_0 main_fragment();
	}
}

