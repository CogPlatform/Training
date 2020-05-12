/*
 * File: colorgrating.frag
 * Shader for drawing of color gratings.
 *
 * Copyright 2014, Ian Andolina <http://github.com/iandol>, licenced under the MIT Licence
 *
 */

uniform vec2    center;
uniform vec4    color1;
uniform vec4    color2;
uniform float   radius;
uniform float   normalise;

varying vec3    baseColor;
varying float   alpha;
varying float   phase;
varying float   frequency;
varying float   sigma;
varying float   contrast;

void main() {
    //current position
    vec2 pos = gl_TexCoord[0].xy;

    /* find our distance from center, if distance to center (aka radius of pixel) > Radius, discard this pixel: */
    if (distance(pos, center) > radius) discard


    vec3 colorA = color1.rgb;
    vec3 colorB = color2.rgb;
    //blend our colours from the base colour if contrast < 1
    if ( contrast < 1.0 ) { 
        colorA = mix( baseColor, color1.rgb, contrast );
        colorB = mix( baseColor, color2.rgb, contrast );
    }

    // and then mix the two colors using sv (our position in the grating)
    vec3 colorOut = mix(colorA, colorB, sv);
    
    // off to the display, byebye little pixel!
    gl_FragColor = vec4( colorOut, alpha );
}