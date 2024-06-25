function dyntest()

%% Screen
PsychDefaultSetup(2);
s=screenManager;
s.distance = 57.3;
%s.windowed = [0 0 1200 800];
s.movieSettings.record = false;
s.movieSettings.type = 1;
s.movieSettings.size = [];
s.movieSettings.codec = [];
sv = s.open;
ifi = sv.ifi;
ifi = ifi *1.5;

%% DEF
floorpos = 12;
wall1pos = sv.leftInDegrees+1;
wall2pos = sv.rightInDegrees-1;
wallwidth = 0.1;
boxx = 11.5;
boxy = floorpos-2.4;
radius = 2;
v = [8 9];
gravity = [0 -9.6];

b=imageStimulus('filePath','moon.png','size',radius*2);
b.xPosition = -10;
b.yPosition = -10;

x1 = imageStimulus('filePath','boxbottom.png','size',10);
x1.alpha = 1;
x1.xPosition = boxx;
x1.yPosition = boxy;

x2 = imageStimulus('filePath','boxtop.png','size',10);
x2.alpha = 1;
x2.xPosition = boxx;
x2.yPosition = boxy;

ms = metaStimulus;
ms.stimuli{1} = x2;
ms.stimuli{2} = b;
ms.stimuli{3} = x1;
ms.setup(s);

%% add dyn4j physics engine
javaaddpath([s.paths.whereami '/stimuli/lib/dyn4j-5.0.2.jar']);
MassType.Normal = javaMethod('valueOf', 'org.dyn4j.geometry.MassType', 'NORMAL');
MassType.INFINITE = javaMethod('valueOf', 'org.dyn4j.geometry.MassType', 'INFINITE');


%% Create world
world = javaObject('org.dyn4j.world.World');
world.setGravity(gravity(1),gravity(2));
bnds = javaObject('org.dyn4j.collision.AxisAlignedBounds', 200, 200);
world.setBounds(bnds);
settings = world.getSettings();
settings.setAtRestDetectionEnabled(true);
settings.setStepFrequency(ifi);
settings.setMaximumAtRestLinearVelocity(0.75);
settings.setMaximumAtRestAngularVelocity(1);
settings.setMinimumAtRestTime(0.2); %def = 0.5

%% add some body
body = javaObject('org.dyn4j.dynamics.Body');
circleShape = javaObject('org.dyn4j.geometry.Circle', radius);
fx = body.addFixture(circleShape); %https://www.javadoc.io/doc/org.dyn4j/dyn4j/latest/org.dyn4j/org/dyn4j/dynamics/BodyFixture.html
fx.setDensity(1);
fx.setRestitution(0.8); % set coefficient of restitution
fx.setFriction(100);
body.translate(b.xPosition, -b.yPosition);
body.setMass(MassType.Normal);
initialVelocity = javaObject('org.dyn4j.geometry.Vector2', v(1), v(2));
body.setLinearVelocity(initialVelocity);
body.setAngularVelocity(initialVelocity.x/2);
body.setLinearDamping(0.05);
body.setAngularDamping(0.1);
world.addBody(body);

%% floor
floor = javaObject('org.dyn4j.dynamics.Body');
floorRect = javaObject('org.dyn4j.geometry.Rectangle', 100, wallwidth);
fx = floor.addFixture(floorRect);
fx.setRestitution(0.7); % set coefficient of restitution
fx.setFriction(100);
floor.setMass(MassType.INFINITE);
floor.translate(0.0, -floorpos-wallwidth);
world.addBody(floor);

%% wall1
wall1 = javaObject('org.dyn4j.dynamics.Body');
wall1Rect = javaObject('org.dyn4j.geometry.Rectangle', wallwidth, 100);
fx = wall1.addFixture(wall1Rect);
fx.setRestitution(0.7); % set coefficient of restitution
fx.setFriction(100);
wall1.setMass(MassType.INFINITE);
wall1.translate(wall1pos-wallwidth, 0);
world.addBody(wall1);

%% wall2
wall2 = javaObject('org.dyn4j.dynamics.Body');
wall2Rect = javaObject('org.dyn4j.geometry.Rectangle', wallwidth, 100);
fx = wall2.addFixture(wall2Rect);
fx.setRestitution(0.7); % set coefficient of restitution
fx.setFriction(100);
wall2.setMass(MassType.INFINITE);
wall2.translate(wall2pos+wallwidth, 0);
world.addBody(wall2);

wa=javaObject('org.dyn4j.geometry.Vector2', boxx-3, -boxy-1.5);
wb=javaObject('org.dyn4j.geometry.Vector2', boxx-3, -boxy+1.5);
wall3 = javaObject('org.dyn4j.dynamics.Body');
wall3Rect = javaObject('org.dyn4j.geometry.Segment', wa, wb);
wall3.addFixture(wall3Rect);
wall3.setMass(MassType.INFINITE);
world.addBody(wall3);

wa=javaObject('org.dyn4j.geometry.Vector2', boxx+3.5, -boxy-1.5);
wb=javaObject('org.dyn4j.geometry.Vector2', boxx+3.5, -boxy+1.5);
wall4 = javaObject('org.dyn4j.dynamics.Body');
wall4Rect = javaObject('org.dyn4j.geometry.Segment', wa, wb);
wall4.addFixture(wall4Rect);
wall4.setMass(MassType.INFINITE);
world.addBody(wall4);

% guide
bx = javaObject('org.dyn4j.dynamics.Body');
bxRect = javaObject('org.dyn4j.geometry.Rectangle', 3.5, 8);
fx = bx.addFixture(bxRect);
fx.setSensor(true);
fx.setRestitution(0); % set coefficient of restitution
fx.setFriction(100);
bx.setMass(MassType.INFINITE);
bx.translate(boxx, -(boxy));
world.addBody(bx);

% dampner
dx = javaObject('org.dyn4j.dynamics.Body');
bxRect = javaObject('org.dyn4j.geometry.Rectangle', 3.5, 0.3);
fx = dx.addFixture(bxRect);
fx.setRestitution(0.2); % set coefficient of restitution
fx.setFriction(1000);
dx.setMass(MassType.INFINITE);
dx.translate(boxx, -(floorpos-0.2));
world.addBody(dx);

RestrictKeysForKbCheck([KbName('LeftArrow') KbName('RightArrow') KbName('UpArrow') KbName('DownArrow') ...
	KbName('1!') KbName('2@') KbName('3#') KbName('space') KbName('ESCAPE')]);

Priority(1);
fx = body.getFixture(0);
commandwindow

%% update world
while true
	world.step(1);
	pos = body.getWorldCenter();
	v = body.getLinearVelocity();
	a = body.getAngularVelocity();
	pos.y = -pos.y;
	b.updateXY(pos.x,pos.y,true);
	if v.x > 0; a = abs(a); else; a = -abs(a); end
	b.angleOut = b.angleOut + rad2deg(a)*ifi;

	inBox = bx.contains(pos);

	if inBox
		if v.x < 0
			vx = v.x + 0.0075;
		elseif v.x > 0
			vx = v.x - 0.0075;
		end
		%if vx < -0.001 || vx > 0.001; vx = 0; end
		body.setLinearVelocity(vx, v.y);
		if a < 0
			na = a + 0.005;
		else
			na = a - 0.005;
		end
		body.setAngularVelocity(na);
		fx.setRestitution(0.1);
		body.updateMass();
	end

	ms.draw;
	% left,top,right,bottom
	s.drawRect([wall1pos floorpos-(wallwidth/2) wall2pos floorpos+(wallwidth/2)],[0.6 0.6 0.3]);
	s.drawRect([wall1pos-(wallwidth/2) -20 wall1pos+(wallwidth/2) 20],[0.6 0.3 0.3]);
	s.drawRect([wall2pos-(wallwidth/2) -20 wall2pos+(wallwidth/2) 20],[0.6 0.3 0.6]);
	s.drawRect([boxx-3.1 boxy-1.5 boxx-2.9 boxy+1.5],[1 1 0 0.2]);
	s.drawRect([boxx+3.4 boxy-1.5 boxx+3.6 boxy+1.5],[1 0 1 0.2]);
	rect = CenterRectOnPointd([0 0 3.5 8],boxx,boxy-6);
	%s.drawRect(rect,[0.5 1 1 0.1]);

	s.drawGrid;
	s.drawScreenCenter;
	s.drawText(sprintf('FULL PHYSICS ENGINE SUPPORT:\nX: %.3f  Y: %.3f VX: %.3f VY: %.3f A: %.3f INBOX: %i R: %.2f',pos.x,pos.y,v.x,v.y, a, inBox,fx.getRestitution))
	s.flip;

	[isKey,~,keyCode] = KbCheck(-1);
	if isKey
		if strcmpi(KbName(keyCode),'escape')
			break;
		elseif strcmpi(KbName(keyCode),'LeftArrow')
			body.setAtRest(false);
			body.setLinearVelocity(v.x - 0.5, v.y);
		elseif strcmpi(KbName(keyCode),'RightArrow')
			body.setAtRest(false);
			body.setLinearVelocity(v.x + 0.5, v.y);
		elseif strcmpi(KbName(keyCode),'UpArrow')
			body.setAtRest(false);
			body.setLinearVelocity(v.x,v.y + 0.5);
		elseif strcmpi(KbName(keyCode),'DownArrow')
			body.setAtRest(false);
			body.setLinearVelocity(v.x, v.y - 0.5);
		elseif strcmpi(KbName(keyCode),'1!')
			body.setAtRest(false);
			body.translateToOrigin();
		elseif strcmpi(KbName(keyCode),'2@')
			body.setAtRest(false);
			if a > 0
				body.setAngularVelocity(a+1);
			else
				body.setAngularVelocity(a-1);
			end
		else
			body.setAtRest(false);
			f = javaObject('org.dyn4j.geometry.Vector2', 15, 0);
			body.applyImpulse(f);
		end
	end
end
s.flip;
WaitSecs(1);
Priority(0);
s.close;
b.reset;
RestrictKeysForKbCheck([]);
end
