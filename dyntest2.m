function dyntest2()

%% Screen
s = screenManager;
if max(Screen('Screens')) == 0; s.windowed = [0 0 1200 800]; end
s.movieSettings.record = false;
s.movieSettings.type = 1;
s.movieSettings.size = [];
s.movieSettings.codec = [];
sv = open(s);
ifi = sv.ifi*1.5;

%% DEFAULTS
floorpos = sv.bottomInDegrees-2;
wall1pos = sv.leftInDegrees+1;
wall2pos = sv.rightInDegrees-1;
wallwidth = 0.25;
boxx = 11.5;
boxy = floorpos-2.4;
box2offset = 9;
radius = 2;
gw = 3.5;
gh = 8;
v = [8 9];
gravity = [0 -9.6];

% STIMULI
moon=imageStimulus('name','moon','filePath','ball1.png','size',radius*2);
moon.xPosition = -10;
moon.yPosition = -10;
moon.angle = 45;
moon.speed = 30;

moon2 = moon.clone;
moon2.name = 'moon2';
moon2.xPosition = -14;
moon2.speed = 18;

boxt = imageStimulus('filePath','boxbottom.png','size',10);
boxt.alpha = 1;
boxt.xPosition = boxx;
boxt.yPosition = boxy;

boxb = imageStimulus('filePath','boxtop.png','size',10);
boxb.alpha = 1;
boxb.xPosition = boxx;
boxb.yPosition = boxy;

boxtt = clone(boxt);
boxtt.xPosition = boxx - box2offset;

boxbb = clone(boxb);
boxbb.xPosition = boxx - box2offset;

floor = barStimulus('name','floor','colour',[0.8 0.4 0.4 0.2],'barWidth',sv.widthInDegrees,...
	'barHeight',wallwidth,'yPosition',floorpos);

ceiling = floor.clone;
ceiling.name = 'ceiling';
ceiling.yPosition = sv.topInDegrees;

wall1 = barStimulus('name','wall1','colour',[0.4 0.8 0.4 0.2],'barWidth',wallwidth,'barHeight',...
	sv.heightInDegrees,'xPosition',wall1pos);

wall2 = clone(wall1);
wall2.name = 'wall2';
wall2.xPosition = wall2pos;

wall2 = barStimulus('name','wall2','alpha',0.2,'barWidth',wallwidth,'barHeight',...
	sv.heightInDegrees,'xPosition',wall2pos);

sensor = barStimulus('name','sensor','alpha',0.1,'barWidth',6,...
	'barHeight',14,'xPosition',boxx,'yPosition',boxy-5);
edge1 = barStimulus('name','bxleft','alpha',0.1,'barWidth',0.1,...
	'barHeight',4,'xPosition',boxx-3.2,'yPosition',floorpos-2.2);
edge2 = barStimulus('name','bxright','alpha',0.1,'barWidth',0.1,...
	'barHeight',4,'xPosition',boxx+3.7,'yPosition',floorpos-2.2);
edge3 = clone(edge1);
edge3.name = 'bxleft2';
edge3.xPosition = edge3.xPosition-box2offset;
edge4 = clone(edge2);
edge4.name = 'bxright2';
edge4.xPosition = edge4.xPosition-box2offset;

all = metaStimulus('stimuli',{floor,ceiling,wall1,wall2,boxb,boxbb,moon,moon2,boxt,boxtt});
all.setup(s);

% SETUP animationManager
anmtr = animationManager('timeDelta', sv.ifi, 'verbose', true);
anmtr.rigidParams.gravity = gravity;
anmtr.addBody(floor,'Rectangle','infinite');
anmtr.addBody(ceiling,'Rectangle','infinite');
anmtr.addBody(wall1,'Rectangle','infinite');
anmtr.addBody(wall2,'Rectangle','infinite');
anmtr.addBody(sensor,'Rectangle','sensor');
anmtr.addBody(edge1,'Segment','infinite');
anmtr.addBody(edge2,'Segment','infinite');
anmtr.addBody(edge3,'Segment','infinite');
anmtr.addBody(edge4,'Segment','infinite');
anmtr.addBody(moon, 'Circle', 'normal', 10, 0.8, 0.8, moon.speed/2);
anmtr.addBody(moon2, 'Circle', 'normal', 10, 0.8, 0.8, moon2.speed/2);
setup(anmtr);

% PREPARE FOR DRAWING LOOP
RestrictKeysForKbCheck([KbName('LeftArrow') KbName('RightArrow') KbName('UpArrow') KbName('DownArrow') ...
	KbName('1!') KbName('2@') KbName('3#') KbName('4$') KbName('space') KbName('ESCAPE')]);

Priority(1); commandwindow;
[moonb, moonidx] = getBody(anmtr,'moon');
[moonb2, moon2idx] = getBody(anmtr,'moon2');
moonfx = getFixture(anmtr, 'moon');
floorfx = getFixture(anmtr, 'floor');
sensorb = getBody(anmtr,'sensor');

while true
	step(anmtr,1,true);
	pos = moonb.getWorldCenter();
	lv = anmtr.linearVelocity(moonidx,:);
	av = anmtr.angularVelocity(moonidx);
	inBox = sensorb.contains(pos);

	if inBox
		if lv(1) < 0
			lv(1) = lv(1) + 0.015;
		elseif lv(1) > 0
			lv(1) = lv(1) - 0.015;
		end
		%if vx < -0.001 || vx > 0.001; vx = 0; end
		moonb.setLinearVelocity(lv(1), lv(2));
		if av < 0
			av = av + 0.01;
		else
			av = av - 0.01;
		end
		moonb.setAngularVelocity(av);
		moonfx.setRestitution(0.1);
		floorfx.setRestitution(0.1);
	else
		moonfx.setRestitution(0.7);
		floorfx.setRestitution(0.7);
	end

	draw(all);
	drawGrid(s);
	drawScreenCenter(s);
	drawText(s,sprintf('RIGIDBODY PHYSICS ENGINE:\n X: %+0.2f  Y: %+0.2f VX: %+0.2f VY: %+0.2f A: %+0.2f INBOX: %i R: %-.2f',...
		pos.x, pos.y, lv(1), lv(2), av, inBox, moonfx.getRestitution))
	flip(s);
	
	[isKey,~,keyCode] = KbCheck(-1);
	if isKey
		if strcmpi(KbName(keyCode),'escape')
			break;
		elseif strcmpi(KbName(keyCode),'LeftArrow')
			moonb.setAtRest(false);
			f = javaObject('org.dyn4j.geometry.Vector2', -40, 0);
			moonb.applyImpulse(f);
			moonb2.applyImpulse(f);
		elseif strcmpi(KbName(keyCode),'RightArrow')
			moonb.setAtRest(false);
			f = javaObject('org.dyn4j.geometry.Vector2', 40, 0);
			moonb.applyImpulse(f);
			moonb2.applyImpulse(f);
		elseif strcmpi(KbName(keyCode),'UpArrow')
			moonb.setAtRest(false);
			f = javaObject('org.dyn4j.geometry.Vector2', 0, 30);
			moonb.applyImpulse(f);
			moonb2.applyImpulse(f);
		elseif strcmpi(KbName(keyCode),'DownArrow')
			moonb.setAtRest(false);
			f = javaObject('org.dyn4j.geometry.Vector2', 0, -30);
			moonb.applyImpulse(f);
			moonb2.applyImpulse(f);
		elseif strcmpi(KbName(keyCode),'1!')
			moonb.setAtRest(false);
			moonb.translateToOrigin();
		elseif strcmpi(KbName(keyCode),'2@')
			moonb.setAtRest(false);
			if av > 0; av = -av; end
			moonb.setAngularVelocity(av-1);
		elseif strcmpi(KbName(keyCode),'3#')
			moonb.setAtRest(false);
			if av < 0; av = -av; end
			moonb.setAngularVelocity(av+1);
		elseif strcmpi(KbName(keyCode),'4$')
			moonb.setAtRest(false);
			anmtr.world.update(0);
		end
	end
end
flip(s);
WaitSecs(1);
Priority(0);
reset(all);
close(s);
RestrictKeysForKbCheck([]);
end
