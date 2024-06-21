function IntuitivePhysics()
%==============================================Screen
try 
	s = screenManager;
	s.backgroundColour = [0 0 0];
	s.windowed = [0 0 1400 800];
	s.specialFlags = kPsychGUIWindow;
	sv = open(s);
	
	%==============================================Audio Manager
	if ~exist('aM','var') || isempty(aM) || ~isa(aM,'audioManager')
		aM=audioManager;
	end
	aM.silentMode = false;
	if ~aM.isSetup;	aM.setup; end
	
	%==============================================STIMULUS
	ball = imageStimulus;
	ball.filePath = 'ball3.png';
	ball.xPosition = -8;
	ball.yPosition = 0;
	ball.angle = -45;
	ball.speed = 25;
	ball.size = 4;
	radius = ball.size/2;
	startx = ball.xPosition;
	starty = ball.yPosition;
	
	%===============================================ANIMMANAGER
	anim = animationManager;
	anim.rigidParams.radius = radius;
	anim.rigidParams.mass = 5;
	anim.rigidParams.airResistanceCoeff = 0.5;
	anim.rigidParams.elasticityCoeff = 0.7;
	anim.timeDelta = sv.ifi;
	
	%===============================================TOUCH
	tM = touchManager('isDummy',true);
	tM.verbose = false;
	tM.window.radius = radius;
	tM.window.X = startx;
	tM.window.Y = starty;
			
	%===============================================
	% this modifies the touch movement > velocity
	% higher values means bigger impact
	touchSensitivity = 1;
	
	%setup some other parameters
	nTrials = 10;
	moveWallAfterNCorrectTrials = 3;
	nCorrect = 0;
	RestrictKeysForKbCheck(KbName('ESCAPE'));

	dateStamp = initialiseSaveFile(s);
	fileName = [s.paths.savedData filesep 'DragTraining-' dateStamp '-.mat'];

	% set up the walls
	floorThickness = 2;
	wallThickness = 1;
	targetWallPosition = 15;
	% left,top,right,bottom
	floorrect = [sv.leftInDegrees sv.bottomInDegrees-floorThickness sv.rightInDegrees sv.bottomInDegrees];
	wall1 = [sv.leftInDegrees sv.topInDegrees sv.leftInDegrees+wallThickness sv.bottomInDegrees];
	wall2 = [targetWallPosition sv.topInDegrees sv.rightInDegrees sv.bottomInDegrees];
	% assign wall positions to anim-manager
	anim.rigidParams.leftwall = wall1(3);
	anim.rigidParams.rightwall = wall2(1);
	anim.rigidParams.floor = sv.bottomInDegrees-floorThickness;
	anim.rigidParams.ceiling = sv.topInDegrees;

	% bump our priority
	Priority(1);

	% setup the objects
	setup(ball, s);
	setup(tM, s);
	setup(anim, ball);
	createQueue(tM);
	start(tM);

	% our results structure
	anidata = struct('N',NaN,'t',[],'x',[],'y',[],'dx',[],'dy',[],...
		'ke',[],'pe',[]);
	results = struct('N',[],'correct',[],'wallPos',[],...
		'RT',[],'date',dateStamp,'name',fileName,...
		'anidata',anidata);
	
	for j = 1:nTrials

		results.anidata(j).N = j;
		fprintf('--->>> Trial: %i - Wall: %.1f\n', j,targetWallPosition);
		ball.xPositionOut = startx;
		ball.yPositionOut = starty;
		ball.update;
		
		% the animator needs to be reset to the ball on each trial
		anim.rigidParams.rightwall = wall2(1);
		anim.rigidParams.airResistanceCoeff = 0.5;
		reset(anim);
		setup(anim, ball);
		
		tx = []; ty = []; iv = round(sv.fps/6);
		correct = false;
		countDown = 10;
		inTouch = false;
		drawBackground(s, s.backgroundColour)
		vbl = flip(s); tStart = vbl;

		while ~correct && vbl < tStart + 5
			if KbCheck; break; end
			if tM.eventAvail % check we have touch event[s]
				tM.window.X = ball.xFinalD;
				tM.window.Y = ball.yFinalD;
				tch = checkTouchWindows(tM); % check we are in touch window
				if tch; inTouch = true; end
				e = tM.event;
				if e.Type == 4 % this is a RELEASE event
					%fprintf('RELEASE X: %.1f %.1f Y: %.1f %.1f\n',e.X,a.x,e.Y,a.y);
					tx = []; ty = []; inTouch = false;
				end
				if inTouch && ~isempty(e) && e.Type > 1 && e.Type < 4
					if tM.y+radius > (floorrect(2)) % make sure we don't move below the floor
						ball.updateXY(e.MappedX, toPixels(s,floorrect(2)-radius,'y'), false);
					else
						ball.updateXY(e.MappedX, e.MappedY, false);
					end
					tx = [tx tM.x];
					ty = [ty tM.y];
					if length(tx) >= iv %collect enough samples
						xy = [tx(end-(iv-1):end)' ty(end-(iv-1):end)'];
						vx = mean(diff(xy(:,1))) * iv * touchSensitivity;
						vy = mean(diff(xy(:,2))) * iv * touchSensitivity;
						x = mean([anim.x xy(end,1)]);
						y = mean([anim.y xy(end,2)]);
						%fprintf('UPDATE X: s%.1f e%.1f a%.1f n%.1f v%.1f Y: s%.1f e%.1f a%.1f n%.1f v%.1f\n', ...
						%       i.xFinal,e.MappedX,a.x,x,vx,i.yFinal,e.MappedY,a.y,y,vy);
						anim.editBody(x,y,vx,vy);
					else
						anim.editBody(tM.x,tM.y);
					end
				else
					animate(anim);
					ball.updateXY(anim.x, anim.y, true);
					ball.angleOut = -rad2deg(anim.angle);
				end
			else
				animate(anim);
				ball.updateXY(anim.x, anim.y, true);
				ball.angleOut = -rad2deg(anim.angle);
			end
			if anim.hitLeftWall
				anim.rigidParams.airResistanceCoeff = 5;
				countDown = countDown - 1;
				if countDown == 0
					break;
				end
			elseif anim.hitRightWall
				anim.rigidParams.airResistanceCoeff = 5;
				countDown = countDown - 1;
				if countDown == 0
					correct = true;
				end
			end
			draw(ball);
			if anim.hitLeftWall
				drawRect(s,wall1,[0.6 0.3 0.3]);
			else
				drawRect(s,wall1,[0.3 0.3 0.3]);
			end
			if anim.hitRightWall
				drawRect(s,wall2,[0.3 0.6 0.3]);
			else
				drawRect(s,wall2,[0.3 0.3 0.3]);
			end
			drawRect(s,floorrect,[0.3 0.3 0.3]);
			vbl = flip(s, vbl + sv.halfifi);
			% save all animation data for each trial, we can use this to "play
			% back" the action performed by the monkey
			results.anidata(j).t =  [results.anidata(j).t, anim.timeStep];
			results.anidata(j).x =  [results.anidata(j).x, anim.x];
			results.anidata(j).y =  [results.anidata(j).y, anim.y];
			results.anidata(j).dx = [results.anidata(j).dx, anim.dX];
			results.anidata(j).dy = [results.anidata(j).dy, anim.dY];
			results.anidata(j).ke = [results.anidata(j).ke, anim.kineticEnergy];
			results.anidata(j).pe = [results.anidata(j).pe, anim.potentialEnergy];
		end

		if KbCheck; break; end

		results.N = [results.N j];
		results.correct = [results.correct correct];
		results.wallPos = [results.wallPos targetWallPosition];
		results.RT = [results.RT (tStart - GetSecs)];

		if correct
			nCorrect = nCorrect + 1;
			drawBackground(s, [0.3 0.6 0.3]);
			flip(s);
			beep(aM, 3000,0.1,0.1);
			disp('--->>> CORRECT');
			WaitSecs(2);
			if nCorrect >= moveWallAfterNCorrectTrials
				nCorrect = 0;
				if targetWallPosition < sv.rightInDegrees - 1
					disp('Wall moved...');
					targetWallPosition = targetWallPosition + 1;
				end
				wall2 = [targetWallPosition sv.topInDegrees sv.rightInDegrees sv.bottomInDegrees];
			end
		else
			disp('--->>> FAIL');
			beep(aM, 300,0.5,0.5);
			drawBackground(s, [0.6 0.3 0.3]);
			flip(s);
			WaitSecs(3);
		end
	end

	Priority(0);
	RestrictKeysForKbCheck([]);
	disp(['--->>> DATA saved to ' fileName]);
	save(fileName,"results");
	tM.close;
	ball.reset;
	s.close;

	figure;
	tiledlayout(3,1);
	for jj = 1:length(results.anidata)
		nexttile(1);
		hold on
		plot(results.anidata(jj).x,results.anidata(jj).y);
		nexttile(2);
		hold on;
		plot(results.anidata(jj).t,results.anidata(jj).ke);
		nexttile(2);
		hold on;
		plot(results.anidata(jj).t,results.anidata(jj).pe);
	end
	title(fileName)
	nexttile(1);
	xlabel('X Position');
	ylabel('Y Position');
	axis equal
	box on; grid on;
	nexttile(2);
	xlabel('Time');
	ylabel('Kinetic Energy');
	box on; grid on;
	nexttile(3);
	xlabel('Time');
	ylabel('Potential Energy');
	box on; grid on;

catch ERR
	getReport(ERR);
	Priority(0);
	RestrictKeysForKbCheck([]);
	try tM.close; end
	try ball.reset; end
	try s.close; end
	try sca; end
	rethrow(ERR);
end

function array = push(array, value)
	array = [array value];
end

end