%==========================================================================
%===========================================================response values
YESBLANK = 1; YESTARGET = 2; UNSURE = 4; BREAKINIT = -100; BREAKBLANK = -10;
BREAKTARGET = -1; BREAKEXCL = -5; UNDEFINED = 0;

% parametric standard error?
parametric = NaN;

%do we include the break exclude trials?
useExclusion = false;

%Here is our data
%load('/home/cog5/MatlabFiles/SavedData/BAMOC_07run2_2021_7_6_13_31_15.mat')
load('/home/cog5/MatlabFiles/SavedData/BAMOC_17run5_2021_7_7_13_47_47.mat');

%file = uigetfile;
%if file == 0; return; end
%load(file);

contrasts = task.nVar(1).values;

trials = ana.task([ana.task.showGrating]==true);
trialscorrect = trials([trials.response]==YESTARGET);
trialswrong = trials([trials.response]==BREAKTARGET);
trialswrongall = trials([trials.response]==BREAKTARGET | [trials.response]==BREAKEXCL);

fprintf('Trial number: %i -- Correct: %i -- BREAK: %i -- BREAKALL: %i\n',...
	length(trials),length(trialscorrect),length(trialswrong),length(trialswrongall));


if useExclusion
	trialswrong = trialswrongall;
end

contrastTotal = [];
contrastCorrect = [];

for i = 1 : length(contrasts)
	tr = trialscorrect([trialscorrect.contrast] == contrasts(i));
	contrastCorrect(i) = length(tr);
	tr = trialswrong([trialswrong.contrast] == contrasts(i));
	contrastWrong(i) = length(tr);
	contrastTotal(i) = contrastWrong(i) + contrastCorrect(i);
end

contrasts(contrasts==0) = 1e-6;
%contrasts = contrasts;

total = contrastTotal;
correct = contrastCorrect;

%Here are our model parameters
search.alpha = linspace(min(contrasts),max(contrasts),200);
search.beta = logspace(0,1,200);
search.gamma = 0;
%search.gamma = linspace(0,0.5,50);
%search.lambda = 0.02;
search.lambda = linspace(0,0.2,50);
freeParameters = [1 1 0 1];
PF = @PAL_Gumbel;

%Here we run the model
[params,b,c] = PAL_PFML_Fit(contrasts,correct,total,search,freeParameters,PF);

if params(2) == Inf
	warning('Had to change the INF slope parameter!!')
	params(2) = max(search.beta);
end
xrange = [0:0.0005:max(contrasts)];
fit = PF(params,xrange);

%And plot our result
figure
hold on
plot(contrasts,(correct./total),'ko');
plot(xrange,fit,'k-','LineWidth', 2);
title(['PF Fitted data values: ' num2str(params,'%.4f ')]);
grid on; grid minor; box on;
drawnow;

if islogical(parametric)
	B=400;
	if parametric == 1
		[SD paramsSim LLSim converged] = PAL_PFML_BootstrapParametric(...
			contrasts, total, params, freeParameters, B, PF, ...
			'searchGrid', search);
	else
		[SD paramsSim LLSim converged] = PAL_PFML_BootstrapNonParametric(...
			contrasts, correct, total, [], freeParameters, B, PF,...
			'searchGrid',search);
	end

	disp('done:');
	message = sprintf('Standard error of Threshold: %6.4f',SD(1));
	disp(message);
	message = sprintf('Standard error of Slope: %6.4f\r',SD(2));
	disp(message);
end
