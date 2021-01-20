function TestStereo(stereoMode)

inverted = 0;

% Default to stereoMode 8 -- Red-Green stereo:
if nargin < 1
    stereoMode = 4;
end

reduceCrossTalkGain = [];

% Check that Psychtoolbox is properly installed, switch to unified KbName's
% across operating systems, and switch color range to normalized 0 - 1 range:
PsychDefaultSetup(2);

% Define response key mappings:
space = KbName('space');
escape = KbName('ESCAPE');

%try
% Get the list of Screens and choose the one with the highest screen number.
% Screen 0 is, by definition, the display with the menu bar. Often when
% two monitors are connected the one without the menu bar is used as
% the stimulus display.  Chosing the display with the highest dislay number is
% a best guess about where you want the stimulus displayed.
scrnNum = max(Screen('Screens'));

% Open double-buffered onscreen window with the requested stereo mode,
% setup imaging pipeline for additional on-the-fly processing:

% Prepare pipeline for configuration. This marks the start of a list of
% requirements/tasks to be met/executed in the pipeline:
PsychImaging('PrepareConfiguration');

% Experimental stereo crosstalk reduction requested?
if ~isempty(reduceCrossTalkGain)
    % Yes setup reduction for both view channels, using reduceCrossTalk as 1st parameter
    % itself. Second parameter sets the background luminance level.
    PsychImaging('AddTask', 'LeftView', 'StereoCrosstalkReduction', 'SubtractOther', reduceCrossTalkGain);
    PsychImaging('AddTask', 'RightView', 'StereoCrosstalkReduction', 'SubtractOther', reduceCrossTalkGain);
    bgColor = GrayIndex(scrnNum);
else
    bgColor = BlackIndex(scrnNum);
end

% Consolidate the list of requirements (error checking etc.), open a
% suitable onscreen window and configure the imaging pipeline for that
% window according to our specs. The syntax is the same as for
% Screen('OpenWindow'):
[windowPtr, windowRect] = PsychImaging('OpenWindow', scrnNum, 0.5, [], [], [], stereoMode);
ifi = Screen('GetFlipInterval', windowPtr);
if ismember(stereoMode, [4, 5])
    % This uncommented bit of code would allow to exercise the
    % SetStereoSideBySideParameters() function, which allows to change
    % presentation parameters for dual-display / side-by-side stereo modes 4
    % and 5:
    SetStereoSideBySideParameters(windowPtr, [0.25, 0.25], [0.75, 0.5], [1, 0.25], [0.75, 0.5]);
    % Restore defaults: SetStereoSideBySideParameters(windowPtr, [0, 0], [1, 1], [1, 0], [1, 1]);
end

% Set up alpha-blending for smooth (anti-aliased) drawing of dots:
%Screen('BlendFunction', windowPtr, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

internalRotation = 0;
rotateMode = kPsychUseTextureMatrixForRotation;
gratingsize = 700;
res = [gratingsize gratingsize];
freq = 5/360;
cyclespersecond = 1;
angle = 0;
amplitude = 1.0;
AssertGLSL;
% Phase is the phase shift in degrees (0-360 etc.)applied to the sine grating:
phase = 0;
% Compute increment of phase shift per redraw:
phaseincrement = (cyclespersecond * 360) * ifi;

% Build a procedural sine grating texture for a grating with a support of
% res(1) x res(2) pixels and a RGB color offset of 0.5 -- a 50% gray.
gratingtex = CreateProceduralSineGrating(windowPtr, res(1), res(2), [0.5 0.5 0.5 0.0]);

Screen('Flip', windowPtr);

% Preallocate timing array for speed:
nmax = 10000
t = zeros(1, nmax);
count = 1;

% Perform a flip to sync us to vbl and take start-timestamp in t:
t(count) = Screen('Flip', windowPtr);
buttons = 0;

% Run until a key is pressed or nmax iterations have been done:
while (count < nmax) && ~any(buttons) 
    % Select left-eye image buffer for drawing:
    Screen('SelectStereoDrawBuffer', windowPtr, 0);
    
    % Draw left stim:
    Screen('DrawTexture', windowPtr, gratingtex, [], [], angle, [], [], [], [], rotateMode, [phase, freq, amplitude, 0]);
	Screen('FrameRect', windowPtr, [1 0 0], [], 5);
    % Select right-eye image buffer for drawing:
    Screen('SelectStereoDrawBuffer', windowPtr, 1);
    
    % Draw right stim:
    Screen('DrawTexture', windowPtr, gratingtex, [], [], angle+90, [], [], [], [], rotateMode, [phase, freq, amplitude, 0]);
	Screen('FrameRect', windowPtr, [0 1 0], [], 5);
    % Tell PTB drawing is finished for this frame:
    Screen('DrawingFinished', windowPtr);
	
	phase = phase + 1;
	
	% Keyboard queries and key handling:
    [pressed dummy keycode] = KbCheck; %#ok<ASGLU>
    if pressed
        % ESCape key exits the demo:
        if keycode(escape)
            break;
        end
	end
	[~, ~, buttons] = GetMouse();
    
    % Flip stim to display and take timestamp of stimulus-onset after
    % displaying the new stimulus and record it in vector t:
    onset = Screen('Flip', windowPtr);
    
    % Log timestamp:
    count = count + 1;
    t(count) = onset;
end

% Last Flip:
Screen('Flip', windowPtr);

% Done. Close the onscreen window:
Screen('CloseAll')

% We're done.
return;

