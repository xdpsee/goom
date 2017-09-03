/*
 * Waveform.hpp
 *
 *  Created on: Jun 25, 2008
 *      Author: pete
 */

#include <OPENGLES/ES1/gl.h>
//#include <OpenGL/glu.h>


#include "Waveform.hpp"
#include <algorithm>

Waveform::Waveform(int samples)
: RenderItem(),samples(samples), points(samples), pointContext(samples)
{

	spectrum = false; /* spectrum data or pcm data */
	dots = false; /* draw wave as dots or lines */
	thick = false; /* draw thicker lines */
	additive = false; /* add color values together */

	scaling= 1; /* scale factor of waveform */
	smoothing = 0; /* smooth factor of waveform */
	sep = 0;

}
void Waveform::Draw(RenderContext &context)
   {

		//if (samples > 2048) samples = 2048;


			if (additive)  glBlendFunc(GL_SRC_ALPHA, GL_ONE);
			else glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

			if (thick)
			{
			  glLineWidth(context.texsize <= 512 ? 2.0f : (float)(2 * context.texsize/512));
			  glPointSize(context.texsize <= 512 ? 2.0f : (float)(2 * context.texsize/512));

			}
			else glPointSize(context.texsize <= 512 ? 1.0f : (float)(context.texsize/512));


			float* value1 = (float*)malloc(sizeof(float) * samples);
			float* value2 = (float*)malloc(sizeof(float) * samples);
			context.beatDetect->pcm->getPCM( value1, samples, 0, spectrum, smoothing, 0);
			context.beatDetect->pcm->getPCM( value2, samples, 1, spectrum, smoothing, 0);
			// printf("%f\n",pcmL[0]);


			float mult= scaling*( spectrum ? 0.015f :1.0f);


				std::transform(&value1[0],&value1[samples],&value1[0],std::bind2nd(std::multiplies<float>(),mult));
				std::transform(&value2[0],&value2[samples],&value2[0],std::bind2nd(std::multiplies<float>(),mult));

			WaveformContext waveContext(samples, context.beatDetect);

			for(int x=0;x< samples;x++)
			{
				waveContext.sample = x/(float)(samples - 1);
				waveContext.sample_int = x;
				waveContext.left = value1[x];
				waveContext.right = value2[x];

				points[x] = PerPoint(points[x],waveContext);
			}

			float* colors = (float*)malloc(sizeof(float) *samples * 4);
			float* p = (float*)malloc(sizeof(float) * samples *2);

			for(int x=0;x< samples;x++)
			{
			  *(colors+ 4*x) = points[x].r;
			  *(colors+ 4*x + 1) = points[x].g;
			  *(colors+ 4*x + 2) = points[x].b;
			  *(colors+ 4*x + 3) = points[x].a * masterAlpha;

			  *(p + 2*x) = points[x].x;
			  *(p + 2*x +1) = -(points[x].y-1);

			}

			glEnableClientState(GL_VERTEX_ARRAY);
			glEnableClientState(GL_COLOR_ARRAY);
			glDisableClientState(GL_TEXTURE_COORD_ARRAY);

			glVertexPointer(2,GL_FLOAT,0,p);
			glColorPointer(4,GL_FLOAT,0,colors);

			free(p);
			free(colors);

			if (dots)	glDrawArrays(GL_POINTS,0,samples);
			else  	glDrawArrays(GL_LINE_STRIP,0,samples);

			glPointSize(context.texsize < 512 ? 1.0f : (float)(context.texsize/512));
			glLineWidth(context.texsize < 512 ? 1.0f : (float)(context.texsize/512));
#ifdef __ST_OS_WINDOWS__
			glDisable(GL_LINE_STIPPLE);
#endif
			glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
			//  glPopMatrix();

   }



