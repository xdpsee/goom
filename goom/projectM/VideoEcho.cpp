/*
 * VideoEcho.cpp
 *
 *  Created on: Jun 29, 2008
 *      Author: pete
 */

//#include "STOSConfig.h"

#include <OPENGLES/ES1/gl.h>
//#include <OpenGL/glu.h>

#include "VideoEcho.hpp"

VideoEcho::VideoEcho(): a(0), zoom(1), orientation(Normal)
{
	// TODO Auto-generated constructor stub

}

VideoEcho::~VideoEcho()
{
	// TODO Auto-generated destructor stub
}

void VideoEcho::Draw(RenderContext &context)
{


		glEnable(GL_TEXTURE_2D);


		float tex[4][2] = {{0, 1},
				   {0, 0},
				   {1, 0},
				   {1, 1}};

		float points[4][2] = {{-0.5, -0.5},
				      {-0.5,  0.5},
				      { 0.5,  0.5},
				      { 0.5,  -0.5}};

		glEnableClientState(GL_VERTEX_ARRAY);
		glDisableClientState(GL_COLOR_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);

		glVertexPointer(2,GL_FLOAT,0,points);
		glTexCoordPointer(2,GL_FLOAT,0,tex);

		//Now Blend the Video Echo
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

		glMatrixMode(GL_TEXTURE);

		//draw video echo
		glColor4f(1.0, 1.0, 1.0, a);
		glTranslatef(.5, .5, 0);
		glScalef((GLfloat)(1.0/zoom), (GLfloat)(1.0/zoom), 1);
		glTranslatef(-.5, -.5, 0);

		int flipx=1, flipy=1;
		switch (orientation)
		{
			case Normal: flipx=1;flipy=1;break;
			case FlipX: flipx=-1;flipy=1;break;
			case FlipY: flipx=1;flipy=-1;break;
			case FlipXY: flipx=-1;flipy=-1;break;
			default: flipx=1;flipy=1; break;
		}

		float pointsFlip[4][2] = {{-0.5f * flipx, -0.5f * flipy},
					  {-0.5f * flipx,  0.5f * flipy},
					  { 0.5f * flipx,  0.5f * flipy},
					  { 0.5f * flipx, -0.5f * flipy}};

		glVertexPointer(2,GL_FLOAT,0,pointsFlip);
		glDrawArrays(GL_TRIANGLE_FAN,0,4);

		glDisable(GL_TEXTURE_2D);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

		glDisableClientState(GL_TEXTURE_COORD_ARRAY);

}
