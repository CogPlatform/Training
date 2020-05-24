function invertest()

bgColour = 0.5;
screen = max(Screen('Screens'));
screenSize = [0 0 1000 1000];

ptb = mySetup(screen,bgColour,screenSize);

alpha = 1;
rmat=rand(500,500);
tmat = repmat(rmat,1,1,3); 
tmat(:,:,4) = alpha;

texture = Screen('MakeTexture', ptb.win, tmat, 1, [], 2);

shader = LoadGLSLProgramFromFiles(which('Invert.frag'), 1);
glUseProgram(shader);
glUniform1i(glGetUniformLocation(shader, 'Image'), 0);
glUseProgram(0);

vbl(1)=Screen('Flip', ptb.win);
while vbl(end) < vbl(1) + 4
	%Screen('DrawTexture', windowPointer, texturePointer [,sourceRect] [,destinationRect] 
	%[,rotationAngle] [, filterMode] [,globalAlpha] [, modulateColor] [, textureShader] 
	%[, specialFlags] [, auxParameters])
	if length(vbl)<=ptb.fps
		Screen('DrawTexture',ptb.win, texture,[],[],...
		0, [], [], [],[]);
	else
		Screen('DrawTexture',ptb.win, texture,[],[],...
		0, [], [], [],shader);
		Screen('gluDisk', ptb.win, [1 1 0], ptb.w/2, ptb.h/2, 5);
	end
	vbl(end+1) = Screen('Flip', ptb.win, vbl(end) + ptb.ifi/2);
end

Screen('Flip', ptb.win);


end

%----------------------
function ptb = mySetup(screen, bgColour, ws)

ptb.cleanup = onCleanup(@myCleanup);
PsychDefaultSetup(2);
Screen('Preference', 'SkipSyncTests', 2);
if isempty(screen); screen = max(Screen('Screens')); end
ptb.ScreenID = screen;
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
PsychImaging('AddTask', 'General', 'UseFastOffscreenWindows');
[ptb.win, ptb.winRect] = PsychImaging('OpenWindow', ptb.ScreenID, bgColour, ws, [], [], [], 1);

[ptb.w, ptb.h] = RectSize(ptb.winRect);
screenWidth = 405; % mm
viewDistance = 573; % mm
ptb.ppd = ptb.w/2/atand(screenWidth/2/viewDistance);
ptb.ifi = Screen('GetFlipInterval', ptb.win);
ptb.fps = 1 / ptb.ifi;
Screen('BlendFunction', ptb.win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

end

%----------------------
function myCleanup()

disp('Clearing up...')
sca

end