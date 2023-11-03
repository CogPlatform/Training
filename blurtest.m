function blurtest()

ch = 1;
dontautomip = true;
if dontautomip; sf = 8; else; sf = 0; end

bc = [0 0 0];
s = screenManager;
s.backgroundColour = bc;
s.stereoMode = 8;
s.anaglyphLeft = [0.8 0 0];
s.anaglyphRight = [0 0.3 1];
s.blend = true;
open(s);
win = s.win;
winRect = s.screenVals.winRect;

d = imageStimulus('size', 2, 'colour', [1 1 1],...
	'fileName',[s.paths.root '/stimuli/star.png']);
setup(d,s);

e = discStimulus;
e.colour = [0.5 0.5 0.5];
e.size = 30;
e.sigma = 450;
e.xPosition = 15;
e.yPosition = 0;
setup(e,s);

c = checkerboardStimulus;
c.colour = [1 1 1];
c.colour2 = [0 0 0];
c.mask = false;
c.angle = 0;
c.size = 40;
c.tf = 1;
c.sf = 0.5;
c.contrast = 1;

c.specialFlags = sf;

sfs = ( (cos(pi:0.01:15*pi) + 1 ) / 2 ) * 0.4 + c.sf;

setup(c,s);
c.sfOut = sfs(1);

% offscreen window, specialFlags == 1 means GL_TEXTURE_2D
[owin, ~]=Screen('OpenOffscreenWindow', win, bc, [], [], mor(1, sf));

gazeRadius = 75;


try
	% Load & Create a GLSL shader for adaptive mipmap lookup:
	ops = [optickaRoot 'stimuli' filesep];
	shader = LoadGLSLProgramFromFiles({[ops 'blur.frag'] [ops 'blur.vert']}, 1);
	%shader = LoadGLSLProgramFromFiles([PsychtoolboxRoot 'PsychDemos' filesep 'BlurredMipmapDemoShader'], 1);

	% Bind texture unit 0 to shader as input source for the mip-mapped video image:
	glUseProgram(shader);
	glUniform1i(glGetUniformLocation(shader, 'Image'), 0);
	glUseProgram(0);

	% Load & Create a GLSL shader for downsampling during MipMap pyramid
    % creation. This specific example shader uses a 3-by-3 gaussian filter
    % kernel with a standard deviation of 1.0:
    mipmapshader = LoadGLSLProgramFromFiles([ops 'MipMapSampler.frag'], 1);
	%mipmapshader = LoadGLSLProgramFromFiles([PsychtoolboxRoot 'PsychDemos' filesep 'MipMapDownsamplingShader.frag.txt'], 1);

	vbl=GetSecs;
	startT = vbl;
	phase = 0;
	a = 1;
	tick = 0;
	
	% Repeat until keypress or timeout of 10 minutes:
	while ((vbl - startT) < 600) && ~KbCheck
	   tick = tick + 1;
		% Yes. Get current "center of gaze" as simulated by the current
		% mouse cursor position:
		[gazeX, gazeY] = GetMouse(win);
		% Flip y-axis direction -- Shader has origin bottom-left, not
		% top-left as GetMouse():
		gazeY = winRect(4) - gazeY;
			
		if ch == 1
			switchChannel(s,0);
			draw(c, owin);
			if dontautomip; CreateResolutionPyramid(owin, mipmapshader, 0); end
			Screen('DrawTexture', win, owin, [], [], [], 3, [], [], shader, [], [gazeX, gazeY, gazeRadius, 0]);
			draw(e); draw(d);
		elseif ch == 2
			switchChannel(s,1);
			draw(c, owin);
			if dontautomip; CreateResolutionPyramid(owin, mipmapshader, 0); end
			Screen('DrawTexture', win, owin, [], [], [], 3, [], [], shader, [], [gazeX, gazeY, gazeRadius, 0]);
			draw(e); draw(d);
		elseif ch == 3
			switchChannel(s,0);
			draw(c, owin);
			if dontautomip; CreateResolutionPyramid(owin, mipmapshader, 0); end
			Screen('DrawTexture', win, owin, [], [], [], 3, [], [], shader, [], [gazeX, gazeY, gazeRadius, 0]);
			draw(e); draw(d);
			switchChannel(s,1);
			draw(c, owin);
			if dontautomip; CreateResolutionPyramid(owin, mipmapshader, 0); end
			Screen('DrawTexture', win, owin, [], [], [], 3, [], [], shader, [], [gazeX, gazeY, gazeRadius, 0]);
			draw(e); draw(d);
		end
			
		c.angleOut = c.angleOut + 0.1;
		a = a + 1; if a > length(sfs); a = 1; end
		c.sfOut = sfs(a);

		% Show it at next video refresh:
		vbl = Screen('Flip', win);

	end
	

	close(s);
	% Close down everything else:
	sca;
	
catch %#ok<*CTCH>
	% Error handling, emergency shutdown:
	sca;
	psychrethrow(psychlasterror);
end