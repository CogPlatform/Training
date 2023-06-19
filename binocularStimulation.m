function binocularStimulation()

sf = 1;
tf = 0;
size = 50;
mask = false;

KbName('UnifyKeyNames')
stopkey				= KbName('q');
upKey				= KbName('uparrow');
downKey				= KbName('downarrow');
leftKey				= KbName('leftarrow');
rightKey			= KbName('rightarrow');
oldr=RestrictKeysForKbCheck([stopkey upKey downKey leftKey rightKey]);
			
s = screenManager();
s.stereoMode = 8;
s.backgroundColour = [0 0 0];
s.anaglyphLeft = [0.9 0 0];
s.anaglyphRight = [0 0.3 1];
s.disableSyncTests = true;

stims = metaStimulus();

stims{1} = checkerboardStimulus;
stims{1}.sf = sf;
stims{1}.tf = tf;
stims{1}.mask=mask;
stims{1}.size = size;
stims{1}.xPosition = 0;
stims{1}.colour = [1 1 1];
stims{1}.colour2 = [0 0 0];

stims{2} = checkerboardStimulus;
stims{2}.sf = sf*2;
stims{2}.tf = tf;
stims{2}.mask=mask;
stims{2}.size = size;
stims{2}.xPosition = 0;
stims{2}.colour = [0 0 0];
stims{2}.colour2 = [1 1 1];

stims{3} = polarGratingStimulus;
stims{3}.sigma = 0.1;
stims{3}.type='radial';
stims{3}.sf = sf;
stims{3}.tf = tf;
stims{3}.mask = true;
stims{3}.size = size;
stims{3}.xPosition = 0;
stims{3}.colour = [1 1 1];
stims{3}.colour2 = [0 0 0];

stims{4} = polarGratingStimulus;
stims{4}.sigma = 0.1;
stims{4}.type='radial';
stims{4}.sf = sf;
stims{4}.tf = tf;
stims{4}.mask = true;
stims{4}.size = size;
stims{4}.xPosition = 0;
stims{4}.colour = [0 0 0];
stims{4}.colour2 = [1 1 1];

open(s);
setup(stims,s);

Priority(MaxPriority(s.win));

hide(stims);
endExperiment = false;
nStim = 1;
show(stims, nStim);
eye = 0; %0 = left 1 = right
ListenChar(-1);

while ~endExperiment

	if eye
		switchChannel(s,0);
		draw(stims)
	else
		switchChannel(s,1);
		draw(stims)
	end
	
	finishDrawing(s);
	animate(stims);

	[keyDown, ~, keyCode] = optickaCore.getKeys();
	if keyDown
		if keyCode(stopkey); endExperiment = true; break;
		elseif keyCode(upKey);   nStim = nStim + 1; if nStim > stims.n; nStim = 1; end;hide(stims); show(stims,nStim);
		elseif keyCode(downKey); nStim = nStim - 1; if nStim < 1; nStim = stims.n; end;hide(stims); show(stims,nStim);
		elseif keyCode(leftKey); eye = ~eye;
		end
	end

	flip(s);

end

RestrictKeysForKbCheck(oldr);ListenChar(0);Priority(0);
reset(stims);
close(s);

end