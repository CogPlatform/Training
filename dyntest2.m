function dyntest2()

%% Screen
s = screenManager;
if max(Screen('Screens')) == 0; s.windowed = [0 0 1200 800]; end
s.movieSettings.record = false;
s.movieSettings.type = 1;
s.movieSettings.size = [];
s.movieSettings.codec = [];
sv = open(s);
ifi = sv.ifi;

%% DEF
floorpos = sv.bottomInDegrees-2;
wall1pos = sv.leftInDegrees+1;
wall2pos = sv.rightInDegrees-1;
wallwidth = 0.25;
boxx = 11.5;
boxy = floorpos-2.4;
radius = 2;
gw = 3.5;
gh = 8;
v = [8 9];
gravity = [0 -9.6];

moon=imageStimulus('name','moon','filePath','moon.png','size',radius*2);
moon.xPosition = -10;
moon.yPosition = -10;
moon.angle = 85;
moon.speed = 20;

boxt = imageStimulus('filePath','boxbottom.png','size',10);
boxt.alpha = 1;
boxt.xPosition = boxx;
boxt.yPosition = boxy;

boxb = imageStimulus('filePath','boxtop.png','size',10);
boxb.alpha = 1;
boxb.xPosition = boxx;
boxb.yPosition = boxy;

floor = barStimulus('name','floor','alpha',0.2,'barWidth',sv.widthInDegrees,...
	'barHeight',wallwidth,'yPosition',floorpos);

ceiling = floor.clone;
ceiling.name = 'ceiling';
ceiling.yPosition = sv.topInDegrees;

wall1 = barStimulus('name','wall1','alpha',0.2,'barWidth',wallwidth,'barHeight',...
	sv.heightInDegrees,'xPosition',wall1pos);

wall2 = barStimulus('name','wall2','alpha',0.2,'barWidth',wallwidth,'barHeight',...
	sv.heightInDegrees,'xPosition',wall2pos);

sensor = barStimulus('name','sensor','alpha',0.2,'barWidth',3,...
	'barHeight',8,'xPosition',boxx,'yPosition',boxy-5);
edge1 = barStimulus('name','bxleft','alpha',0.2,'barWidth',0.1,...
	'barHeight',4,'xPosition',boxx-3,'yPosition',boxy);
edge2 = barStimulus('name','bxright','alpha',0.2,'barWidth',0.1,...
	'barHeight',4,'xPosition',boxx+3,'yPosition',boxy);

all = metaStimulus('stimuli',{floor,ceiling,wall1,wall2,boxb,moon,boxt,sensor,edge1,edge2});
all.setup(s);

% setup animationManager
anmtr = animationManager('timeDelta', sv.ifi, 'verbose', true);
anmtr.rigidParams.gravity = gravity;
anmtr.addBody(floor,'Rectangle','infinite');
anmtr.addBody(ceiling,'Rectangle','infinite');
anmtr.addBody(wall1,'Rectangle','infinite');
anmtr.addBody(wall2,'Rectangle','infinite');
anmtr.addBody(sensor,'Rectangle','sensor');
anmtr.addBody(edge1,'Segment','infinite');
anmtr.addBody(edge2,'Segment','infinite');
anmtr.addBody(moon, 'Circle', 'normal', 10, 0.2, 0.8, moon.speed);

setup(anmtr);

RestrictKeysForKbCheck([KbName('LeftArrow') KbName('RightArrow') KbName('UpArrow') KbName('DownArrow') ...
	KbName('1!') KbName('2@') KbName('3#') KbName('space') KbName('ESCAPE')]);

Priority(1); commandwindow;
moonb = getBody(anmtr,'moon');
sensorb = getBody(anmtr,'sensor');

while true
	step(anmtr);
	pos = moonb.getWorldCenter();
	v = moonb.getLinearVelocity();
	av = moonb.getAngularVelocity();
	moon.updateXY(pos.x,-pos.y,true);
	if v.x > 0; av = abs(av); else; av = -abs(av); end
	moon.angleOut = moon.angleOut + rad2deg(av)*ifi;

	inBox = sensorb.contains(pos);

	if inBox
		if v.x < 0
			vx = v.x + 0.015;
		elseif v.x > 0
			vx = v.x - 0.015;
		end
		%if vx < -0.001 || vx > 0.001; vx = 0; end
		body.setLinearVelocity(vx, v.y);
		if av < 0
			av = av + 0.005;
		else
			av = av - 0.005;
		end
		moonb.setAngularVelocity(av);
		moonb.setRestitution(0.1);
	end

	draw(all);
	drawGrid(s);
	drawScreenCenter(s);
	drawText(s,sprintf('FULL PHYSICS ENGINE SUPPORT:\n X: %.3f  Y: %.3f VX: %.3f VY: %.3f A: %.3f INBOX: %i R: %.2f',pos.x,pos.y,v.x,v.y, av, inBox,moonb.getRestitution))
	flip(s);
	
	[isKey,~,keyCode] = KbCheck(-1);
	if isKey
		if strcmpi(KbName(keyCode),'escape')
			break;
		elseif strcmpi(KbName(keyCode),'LeftArrow')
			body.setAtRest(false);
			f = javaObject('org.dyn4j.geometry.Vector2', -20, 0);
			body.applyImpulse(f);
		elseif strcmpi(KbName(keyCode),'RightArrow')
			body.setAtRest(false);
			f = javaObject('org.dyn4j.geometry.Vector2', 20, 0);
			body.applyImpulse(f);
		elseif strcmpi(KbName(keyCode),'UpArrow')
			body.setAtRest(false);
			f = javaObject('org.dyn4j.geometry.Vector2', 0, 20);
			body.applyImpulse(f);
		elseif strcmpi(KbName(keyCode),'DownArrow')
			body.setAtRest(false);
			f = javaObject('org.dyn4j.geometry.Vector2', 0, -20);
			body.applyImpulse(f);
		elseif strcmpi(KbName(keyCode),'1!')
			body.setAtRest(false);
			body.translateToOrigin();
		elseif strcmpi(KbName(keyCode),'2@')
			body.setAtRest(false);
			if av > 0; av = -av; end
			body.setAngularVelocity(av-1);
		else
			body.setAtRest(false);
			if av < 0; av = -av; end
			body.setAngularVelocity(av+1);
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
