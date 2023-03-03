Screen('Preference', 'VisualDebugLevel', 3)

s = screenManager();
s.blend = true;
s.disableSyncTests = true;
s.distance = 57.3;
s.pixelsPerCm = 32;

RestrictKeysForKbCheck([27 48:57]);

try 
	open(s);
	
	f = fixationCrossStimulus();
	f.size = 2;
	hide(f);
	
	setup(f,s);
	
	du = dataConnection();
	dt = dataConnection('rPort','35001');
	
	open(dt);
	
	pos = [-15 -15; -15 0; -15 15; 0 -15; 0 0; 0 15; 15 -15; 15 0; 15 15];
	f.xPositionOut = pos(1,1);
	f.yPositionOut = pos(1,2);
	update(f);
	loop = true;
	thisPos = 0;
	
	while loop
	
		[pressed,~,keys] = KbCheck(-1);
		if pressed
			k = lower(KbName(keys));
			if matches(k,'escape'); loop = false; end
			if length(k) == 2; k = k(1); end
			k = str2double(k);
			if k == 0
				hide(f);
			elseif k > 0 && k < 10
				show(f);
				f.xPositionOut = pos(k,1);
				f.yPositionOut = pos(k,2);
				update(f);
				disp('Change Calibration Position...');
			end
		end
		drawGrid(s);
		draw(f);
		flip(s);
	
	end
	
	ri = randi([1 9]);
	f.xPositionOut = pos(ri,1);
	f.yPositionOut = pos(ri,2);
	show(f);
	update(f);
	
	WaitSecs(1);
	disp('Start irec Online')
	dt.write(int8('start'));

	loop = true;
	tStart = GetSecs;
	
	while loop
		
		tNow = GetSecs;
	
		if tNow > tStart + 2
			ri = randi([1 9]);
			f.xPositionOut = pos(ri,1);
			f.yPositionOut = pos(ri,2);
			update(f);
			tStart = tNow;
			disp('Change Test Position...');
		end
	
		drawGrid(s);
		draw(f);
	
		dt.flushOld;
		x = dt.readline();
		if ~isempty(x)
			x = strsplit(x,',');
			drawSpot(s,0.5,[1 1 0], str2double(x{2}), -str2double(x{3}));
		end
	
		flip(s);
		
		[pressed,~,keys] = KbCheck(-1);
		if pressed
			k = lower(KbName(keys));
			if matches(k,'escape'); break; end
		end
	end
	
	disp('Finishing...')
	dt.write(int8('stop')); 
	dt.close();
	
	reset(f);
	
	close(s);

	RestrictKeysForKbCheck();

catch ME
	try dt.write(int8('stop')); end %#ok<*TRYNC> 
	try dt.close; end
	try reset(f); end
	try close(s); end
	rethrow(ME);
end

