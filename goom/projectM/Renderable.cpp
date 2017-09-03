
//#include "STOSConfig.h"

#include "Renderable.hpp"
#include <math.h>

#include <OPENGLES/ES1/gl.h>

void glRectd (GLfloat x1, GLfloat y1, GLfloat x2, GLfloat y2)
{
	GLfloat texture[] =
	{
		0, 0,
		0, 1,
		1, 0,
		1, 1
	};

	GLfloat model[] =
	{
		x1, y1, // lower left
		x1, y2, // upper left
		x2, y1, // lower right
		x2, y2  // upper right
	};

	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);

	glVertexPointer(2, GL_FLOAT, 0, model);
	glTexCoordPointer(2, GL_FLOAT, 0, texture);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}



RenderContext::RenderContext()
	: time(0),texsize(512), aspectRatio(1), aspectCorrect(false){};

RenderItem::RenderItem():masterAlpha(1){}

DarkenCenter::DarkenCenter():RenderItem(){}
MotionVectors::MotionVectors():RenderItem(){}
Border::Border():RenderItem(){}

void DarkenCenter::Draw(RenderContext &context)
{
	//float unit=0.05f;

	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	float colors[6][4] = {{0, 0, 0, (3.0f/32.0f) * masterAlpha},
	{0, 0, 0, 0},
	{0, 0, 0, 0},
	{0, 0, 0, 0},
	{0, 0, 0, 0},
	{0, 0, 0, 0}};

	float points[6][2] = {{ 0.5f,  0.5f},
	{ 0.45f, 0.5f},
	{ 0.5f,  0.45f},
	{ 0.55f, 0.5f},
	{ 0.5f,  0.55f},
	{ 0.45f, 0.5f}};

	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_COLOR_ARRAY);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);

	glVertexPointer(2,GL_FLOAT,0,points);
	glColorPointer(4,GL_FLOAT,0,colors);

	glDrawArrays(GL_TRIANGLE_FAN,0,6);

}

Shape::Shape():RenderItem()
{
	std::string imageUrl = "";
	sides = 4;
	thickOutline = false;
	enabled = true;
	additive = false;
	textured = false;

	tex_zoom = 1.0;
	tex_ang = 0.0;

	x = 0.5;
	y = 0.5;
	radius = 1.0;
	ang = 0.0;

	r = 0.0; /* red color value */
	g = 0.0; /* green color value */
	b = 0.0; /* blue color value */
	a = 0.0; /* alpha color value */

	r2 = 0.0; /* red color value */
	g2 = 0.0; /* green color value */
	b2 = 0.0; /* blue color value */
	a2 = 0.0; /* alpha color value */

	border_r = 0.0; /* red color value */
	border_g = 0.0; /* green color value */
	border_b = 0.0; /* blue color value */
	border_a = 0.0; /* alpha color value */


}

void Shape::Draw(RenderContext &context)
{

	float xval, yval;
	float t;

	// printf("drawing shape %f\n", ang);

	float temp_radius= (float)(radius*(.707*.707*.707*1.04));
	//Additive Drawing or Overwrite
	if ( additive==0)  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	else    glBlendFunc(GL_SRC_ALPHA, GL_ONE);

	xval= x;
	yval= -(y-1);

	if ( textured)
	{
		if (imageUrl !="")
		{
			GLuint tex= context.textureManager->getTexture(imageUrl);
			if (tex != 0)
			{
				glBindTexture(GL_TEXTURE_2D, tex);
				context.aspectRatio=1.0;
			}
		}

		glMatrixMode(GL_TEXTURE);
		glPushMatrix();
		glLoadIdentity();

		glEnable(GL_TEXTURE_2D);

		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_COLOR_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);
#ifdef __ST_OS_WINDOWS__
		float* colors = (float*)malloc(sizeof(float) * (sides + 2) * 4);
		float* tex = (float*)malloc(sizeof(float) * (sides + 2) * 2);
		float* points = (float *)malloc(sizeof(float*)*(sides + 2) * 2);

		//Define the center point of the shape
		colors[0] = r;
		colors[1] = g;
		colors[2] = b;
		colors[3] = a * masterAlpha;
		tex[0] = 0.5;
		tex[1] = 0.5;
		points[0] = xval;
		points[1] = yval;


		for ( int i=1;i< sides+2;i++)
		{
			*(colors + 4*i)= r2;
			*(colors + 4*i + 1)=g2;
			*(colors + 4*i + 2)=b2;
			*(colors + 4*i + 3)=a2 * masterAlpha;

			t = (i-1)/(float) sides;
			*(tex + 2 * i) =0.5f + 0.5f*cosf(t*3.1415927f*2 +  tex_ang + 3.1415927f*0.25f)*(context.aspectCorrect ? context.aspectRatio : 1.0f)/ tex_zoom;
			*(tex + 2 * i + 1) =  0.5f + 0.5f*sinf(t*3.1415927f*2 +  tex_ang + 3.1415927f*0.25f)/ tex_zoom;
			*(points + 2*i)=temp_radius*cosf(t*3.1415927f*2 +  ang + 3.1415927f*0.25f)*(context.aspectCorrect ? context.aspectRatio : 1.0f)+xval;
			*(points + 2*i + 1)=temp_radius*sinf(t*3.1415927f*2 +  ang + 3.1415927f*0.25f)+yval;
		}

		glVertexPointer(2,GL_FLOAT,0,points);
		glColorPointer(4,GL_FLOAT,0,colors);
		glTexCoordPointer(2,GL_FLOAT,0,tex);

		free(points);
		free(colors);
		free(tex);
#else
		float colors[sides+2][4];
		float tex[sides+2][2];
		float points[sides+2][2];
		//Define the center point of the shape
		colors[0][0] = r;
		colors[0][1] = g;
		colors[0][2] = b;
		colors[0][3] = a * masterAlpha;
		tex[0][0] = 0.5;
		tex[0][1] = 0.5;
		points[0][0] = xval;
		points[0][1] = yval;


		for ( int i=1;i< sides+2;i++)
		{
			colors[i][0]= r2;
			colors[i][1]=g2;
			colors[i][2]=b2;
			colors[i][3]=a2 * masterAlpha;

			t = (i-1)/(float) sides;
			tex[i][0]=0.5f + 0.5f*cosf(t*3.1415927f*2 +  tex_ang + 3.1415927f*0.25f)*(context.aspectCorrect ? context.aspectRatio : 1.0f)/ tex_zoom;
			tex[i][1] =  0.5f + 0.5f*sinf(t*3.1415927f*2 +  tex_ang + 3.1415927f*0.25f)/ tex_zoom;
			points[i][0]=temp_radius*cosf(t*3.1415927f*2 +  ang + 3.1415927f*0.25f)*(context.aspectCorrect ? context.aspectRatio : 1.0f)+xval;
			points[i][1]=temp_radius*sinf(t*3.1415927f*2 +  ang + 3.1415927f*0.25f)+yval;
		}

		glVertexPointer(2,GL_FLOAT,0,points);
		glColorPointer(4,GL_FLOAT,0,colors);
		glTexCoordPointer(2,GL_FLOAT,0,tex);
#endif

		glDrawArrays(GL_TRIANGLE_FAN,0,sides+2);

		glDisable(GL_TEXTURE_2D);
		glPopMatrix();
		glMatrixMode(GL_MODELVIEW);

		//Reset Texture state since we might have changed it
		/*
		if(this->renderTarget->useFBO)
		{
		glBindTexture( GL_TEXTURE_2D, renderTarget->textureID[1] );
		}
		else
		{
		glBindTexture( GL_TEXTURE_2D, renderTarget->textureID[0] );
		}
		*/

	}
	else
	{//Untextured (use color values)


		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_COLOR_ARRAY);
		glDisableClientState(GL_TEXTURE_COORD_ARRAY);


#ifdef __ST_OS_WINDOWS__
		float* colors = (float*)malloc(sizeof(float) * (sides + 2) * 4);
		float* points = (float *)malloc(sizeof(float) * (sides + 2) * 2);

		colors[0]=r;
		colors[1]=g;
		colors[2]=b;
		colors[3]=a * masterAlpha;
		points[0]=xval;
		points[1]=yval;

		for ( int i=1;i< sides+2;i++)
		{
			*(colors + i * 4)=r2;
			*(colors + i * 4 + 1)=g2;
			*(colors + i * 4 + 2)=b2;
			*(colors + i * 4 + 3)=a2 * masterAlpha;

			t = (i-1)/(float) sides;
			*(points + 2 * i)=temp_radius*cosf(t*3.1415927f*2 +  ang + 3.1415927f*0.25f)*(context.aspectCorrect ? context.aspectRatio : 1.0f)+xval;
			*(points + 2 * i + 1)=temp_radius*sinf(t*3.1415927f*2 +  ang + 3.1415927f*0.25f)+yval;
		}

		glVertexPointer(2,GL_FLOAT,0,points);
		glColorPointer(4,GL_FLOAT,0,colors);

		free(points);
		free(colors);
#else
		float colors[sides+2][4];
		float points[sides+2][2];

		colors[0][0]=r;
		colors[0][1]=g;
		colors[0][2]=b;
		colors[0][3]=a * masterAlpha;
		points[0][0]=xval;
		points[0][1]=yval;

		for ( int i=1;i< sides+2;i++)
		{
			colors[i][0]=r2;
			colors[i][1]=g2;
			colors[i][2]=b2;
			colors[i][3]=a2 * masterAlpha;

			t = (i-1)/(float) sides;
			points[i][0]=temp_radius*cosf(t*3.1415927f*2 +  ang + 3.1415927f*0.25f)*(context.aspectCorrect ? context.aspectRatio : 1.0f)+xval;
			points[i][1]=temp_radius*sinf(t*3.1415927f*2 +  ang + 3.1415927f*0.25f)+yval;
		}

		glVertexPointer(2,GL_FLOAT,0,points);
		glColorPointer(4,GL_FLOAT,0,colors);
#endif
		glDrawArrays(GL_TRIANGLE_FAN,0,sides+2);
		//draw first n-1 triangular pieces

	}
	if (thickOutline==1)  glLineWidth(context.texsize < 512 ? 1.0f : (float)(2 * context.texsize/512));

	glEnableClientState(GL_VERTEX_ARRAY);
	glDisableClientState(GL_COLOR_ARRAY);

#ifdef __ST_OS_WINDOWS__
	float*  points = (float*)malloc(sizeof(float) *(sides+1) * 2);

	glColor4f( border_r, border_g, border_b, border_a * masterAlpha);

	for ( int i=0;i< sides;i++)
	{
		t = (i-1)/(float) sides;
		*(points + 2 * i) = temp_radius*cosf(t*3.1415927f*2 +  ang + 3.1415927f*0.25f)*(context.aspectCorrect ? context.aspectRatio : 1.0f)+xval;
		*(points + 2 * i + 1)=  temp_radius*sinf(t*3.1415927f*2 +  ang + 3.1415927f*0.25f)+yval;

	}

	glVertexPointer(2,GL_FLOAT,0,points);
	glDrawArrays(GL_LINE_LOOP,0,sides);

	free(points);
#else

	float  points[sides+1][2];

	glColor4f( border_r, border_g, border_b, border_a * masterAlpha);

	for ( int i=0;i< sides;i++)
	{
		t = (i-1)/(float) sides;
		points[i][0] = temp_radius*cosf(t*3.1415927f*2 +  ang + 3.1415927f*0.25f)*(context.aspectCorrect ? context.aspectRatio : 1.0f)+xval;
		points[i][1]=  temp_radius*sinf(t*3.1415927f*2 +  ang + 3.1415927f*0.25f)+yval;

	}

	glVertexPointer(2,GL_FLOAT,0,points);
	glDrawArrays(GL_LINE_LOOP,0,sides);
#endif

	if (thickOutline==1)  glLineWidth(context.texsize < 512 ? 1.0f : (float)(context.texsize/512));
}

void MotionVectors::Draw(RenderContext &context)
{
	glEnableClientState(GL_VERTEX_ARRAY);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	glDisableClientState(GL_COLOR_ARRAY);

	float  intervalx=(float)1.0/x_num;
	float  intervaly=(float)1.0/y_num;

	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	glPointSize(length < 0.000001f ? 0.000001f : length);
	glColor4f(r, g, b, a * masterAlpha);

	if (x_num + y_num < 600)
	{
		int size = (int)(x_num * y_num);

#ifdef __ST_OS_WINDOWS__
		float* points = (float*)malloc(sizeof(float) * size * 2);
		for (int x=0;x<(int)x_num;x++)
		{
			for(int y=0;y<(int)y_num;y++)
			{
				float lx = 0.0;
				float ly = 0.0;
				lx = x_offset+x*intervalx;
				ly = y_offset+y*intervaly;

				*(points + ((x * (int)y_num) + y) * 2) = lx;
				*(points + ((x * (int)y_num) + y) * 2 + 1) = ly;
			}
		}

		glVertexPointer(2,GL_FLOAT,0,points);
		glDrawArrays(GL_POINTS,0,size);
		free(points);
#else
		float points[size][2];
		for (int x=0;x<(int)x_num;x++)
		{
			for(int y=0;y<(int)y_num;y++)
			{
				float lx = 0.0;
				float ly = 0.0;
				lx = x_offset+x*intervalx;
				ly = y_offset+y*intervaly;

				points[(x * (int)y_num) + y][0] = lx;
				points[(x * (int)y_num) + y][1] = ly;
			}
		}

		glVertexPointer(2,GL_FLOAT,0,points);
		glDrawArrays(GL_POINTS,0,size);
#endif
		
	}
}

void Border::Draw(RenderContext &context)
{
	glEnableClientState(GL_VERTEX_ARRAY);
	glDisableClientState(GL_COLOR_ARRAY);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	//Draw Borders
	float of=outer_size * ((float)(0.5));
	float iff=inner_size * ((float)0.5);
	float texof= (float)1.0-of;

	//no additive drawing for borders
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glColor4f(outer_r, outer_g, outer_b, outer_a * masterAlpha);

	float pointsA[4][2] = {{0,0},{0,1},{of,0},{of,1}};
	glVertexPointer(2,GL_FLOAT,0,pointsA);
	glDrawArrays(GL_TRIANGLE_STRIP,0,4);

	float pointsB[4][2] = {{of,0},{of,of},{texof,0},{texof,of}};
	glVertexPointer(2,GL_FLOAT,0,pointsB);
	glDrawArrays(GL_TRIANGLE_STRIP,0,4);

	float pointsC[4][2] = {{texof,0},{texof,1},{1,0},{1,1}};
	glVertexPointer(2,GL_FLOAT,0,pointsC);
	glDrawArrays(GL_TRIANGLE_STRIP,0,4);

	float pointsD[4][2] = {{of,1},{of,texof},{texof,1},{texof,texof}};
	glVertexPointer(2,GL_FLOAT,0,pointsD);
	glDrawArrays(GL_TRIANGLE_STRIP,0,4);

	glColor4f(inner_r, inner_g, inner_b, inner_a * masterAlpha);

	glRectd(of, of, of+iff, texof);
	glRectd(of+iff, of, texof-iff, of+iff);
	glRectd(texof-iff, of, texof, texof);
	glRectd(of+iff, texof, texof-iff, texof-iff);



	float pointsE[4][2] = {{of,of},{of,texof},{of+iff,of},{of+iff,texof}};
	glVertexPointer(2,GL_FLOAT,0,pointsE);
	glDrawArrays(GL_TRIANGLE_STRIP,0,4);

	float pointsF[4][2] = {{of+iff,of},{of+iff,of+iff},{texof-iff,of},{texof-iff,of+iff}};
	glVertexPointer(2,GL_FLOAT,0,pointsF);
	glDrawArrays(GL_TRIANGLE_STRIP,0,4);

	float pointsG[4][2] = {{texof-iff,of},{texof-iff,texof},{texof,of},{texof,texof}};
	glVertexPointer(2,GL_FLOAT,0,pointsG);
	glDrawArrays(GL_TRIANGLE_STRIP,0,4);

	float pointsH[4][2] = {{of+iff,texof},{of+iff,texof-iff},{texof-iff,texof},{texof-iff,texof-iff}};
	glVertexPointer(2,GL_FLOAT,0,pointsH);
	glDrawArrays(GL_TRIANGLE_STRIP,0,4);

}
