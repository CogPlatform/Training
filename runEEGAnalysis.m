function runEEGAnalysis(ana)
ts=tic;
ana.table.Data =[]; drawnow;
ft_defaults;

info = load(ana.MATFile);
info.seq.showLog();drawnow;
vars = getVariables;

data_raw = []; trl=[]; triggers=[]; events=[]; timelock = []; freq = [];
if ana.plotTriggers
	cfgRaw				= [];
	cfgRaw.dataset		= ana.EDFFile;
	cfgRaw.header		= ft_read_header(cfgRaw.dataset);
	cfgRaw.continuous	= 'yes';
	cfgRaw.channel		= 'all';
	cfgRaw.demean		= 'yes';
	cfgRaw.detrend		= 'yes';
	cfgRaw.polyremoval  = 'yes';
	cfgRaw.chanindx     = ana.bitChannels;
	cfgRaw.threshold	= ana.threshold;
	cfgRaw.jitter		= ana.jitter;
	cfgRaw.minTrigger	= ana.minTrigger;
	cfgRaw.preTime		= ana.preTime;
	cfgRaw.correctID	= ana.correctID;
	data_raw			= ft_preprocessing(cfgRaw);
	[trl, events, triggers] = loadCOGEEG(cfgRaw);
	if isempty(trl)
		fprintf('--->>> NO Trials loaded\n');
	else
		fprintf('--->>> %i Trials loaded, plotting...\n',size(trl,1));
	end
	plotRawChannels(); drawnow;
	if ~isempty(trl) && size(trl,2) == 4
		plotTable(info.seq.outIndex,trl(:,4));
	end
	info.data_raw		= data_raw;
	info.events			= events;
	info.triggers		= triggers;
	info.trl			= trl;
	assignin('base','info',info);
	return;
end

%---------------------------LOAD DATA AS TRIALS
cfg					= [];
cfg.dataset			= ana.EDFFile;
cfg.header			= ft_read_header(cfg.dataset);
cfg.continuous		= 'yes';
cfg.trialfun		= 'loadCOGEEG';
cfg.chanindx		= ana.bitChannels;
cfg.threshold		= ana.threshold;
cfg.jitter			= ana.jitter;
cfg.minTrigger		= ana.minTrigger;
cfg.correctID		= ana.correctID;
cfg.preTime			= ana.preTime;
cfg					= ft_definetrial(cfg);
cfg.dftfilter		= ana.dftfilter;
cfg.demean			= ana.demean;
if strcmpi(ana.demean,'yes') 
	cfg.baselinewindow	= ana.baseline;
end
cfg.detrend			= ana.detrend;
cfg.polyremoval		= ana.polyremoval;
cfg.channel			= ana.dataChannels;
if ana.rereference > 0 && any(ana.dataChannels == ana.rereference)
	cfg.reref		= 'yes';
	cfg.refchannel	= cfg.header.label{ana.rereference};
end
data_eeg			= ft_preprocessing(cfg);
info.data_cfg		= cfg;

if ana.rejectvisual
	cfg				= [];
	cfg.box			= 'yes';
	cfg.latency		= 'all';
	cfg.method		= ana.rejecttype;
	data_eeg		= ft_rejectvisual(cfg,data_eeg);
end

%------------------------------RUN TIMELOCK
varmap				= unique(data_eeg.trialinfo);
timelock			= cell(length(varmap),1);
if ana.doTimelock
	for j = 1:length(varmap)
		cfg				= [];
		cfg.trials		= find(data_eeg.trialinfo==varmap(j));
		cfg.covariance	= ana.tlcovariance;
		cfg.keeptrials	= ana.tlkeeptrials;
		cfg.removemean	= ana.tlremovemean;
		if ~isempty(ana.plotRange);	cfg.latency = ana.plotRange; end
		timelock{j}		= ft_timelockanalysis(cfg,data_eeg);
	end
	plotTimeLock();
	%makeSurrogate();
	plotFreqPower();
end

%------------------------------RUN TIMEFREQ

freq				= cell(length(varmap),1);
if ana.doTimeFreq
	for j = 1:length(varmap)
		cfg				= [];
		cfg.trials		= find(data_eeg.trialinfo==varmap(j));
		cfg.channel		= 1;
		cfg.method		= 'mtmconvol';
		cfg.taper		= ana.freqtaper;
		cfg.pad			= 'nextpow2';
		cfg.foi			= ana.freqrange;                  % analysis 2 to 30 Hz in steps of 2 Hz
		cfg.t_ftimwin	= ones(length(cfg.foi),1).*0.2;   % length of time window = 0.5 sec
		if ~isempty(ana.plotRange) && isnumeric(ana.plotRange)
			cfg.toi		= ana.plotRange(1):0.05:ana.plotRange(2);% time window "slides" from -0.5 to 1.5 sec in steps of 0.05 sec (50 ms)
		else
			cfg.toi		= min(data_eeg.time{1}):0.05:max(data_eeg.time{1});
		end
		freq{j}			= ft_freqanalysis(cfg,data_eeg);
	end
	plotFrequency();
end

info.timelock		= timelock;
info.freq			= freq;
info.data_raw		= data_raw;
info.data_eeg		= data_eeg;
info.triggers		= triggers;
assignin('base','info',info);

plotTable(info.seq.outIndex, info.data_eeg.trialinfo);
fprintf('===>>> Analysis took %.2f seconds\n', toc(ts));

%==========================================SUB FUNCTIONS

function vars = getVariables()
	if isprop(info.seq,'varLabels')
		vars = info.seq.varLabels;
	else
		vars = cell(1,info.seq.minBlocks);
	end
end

function plotTable(intrig,outtrig)
	col1 = intrig;if size(col1,1)<size(col1,2); col1=col1';end
	col2 = outtrig;if size(col2,1)<size(col2,2); col2=col2';end
	col3 = vars; if size(col3,1)<size(col3,2); col3=col3';end
	col4 = 1:length(col3); if size(col4,1)<size(col4,2); col4=col4';end
	
	if length(col1) ~= length(col2)
		warning('Input and output triggers are different!')
		ana.warning.Color = [ 0.8 0.3 0.3 ];
	else
		ana.warning.Color = [ 0.5 0.5 0.5 ];
	end

	maxn = max([length(col1) length(col2) length(col3) length(col4)]);
	if length(col1) < maxn; col1(end+1:maxn) = NaN; end
	if length(col2) < maxn; col2(end+1:maxn) = NaN; end
	if length(col3) < maxn
		col3 = [col3;repmat({''},maxn-length(col3),1)];
	end
	if length(col4) < maxn; col4(end+1:maxn) = NaN; end
	tdata = table(col1,col2,col3,col4,'VariableNames',{'Triggers Sent','Data Triggers','Stimulus Value','Index'});
	ana.table.Data = tdata;
	
end

function plotTimeLock()
	h = figure('Name',['TL Data: ' ana.EDFFile],'Units','normalized',...
		'Position',[0 0.1 0.3 0.9]);
	if length(timelock) > 8
		tl = tiledlayout(h,'flow','TileSpacing','compact');
	else
		tl = tiledlayout(h,length(timelock),1,'TileSpacing','compact');
	end
	mn = inf; mx = -inf;
	c={[0.3 0.3 0.3],[0.7 0.3 0.3],[0.8 0.8 0.8],[0.7 0.9 0.7],[0.9 0.9 0.7],[0.7 0.7 0.9]};
	for jj = 1:length(timelock)
		nexttile(tl,jj)
		ft_singleplotER(struct('channel',[1 2]),timelock{jj});
		if isfield(timelock{jj},'avg')
			hold on
			for i = 1:length(timelock{jj}.label)
				areabar(timelock{jj}.time,timelock{jj}.avg(i,:),timelock{jj}.var(i,:),c{i});
			end
		else
			hold on
			for i = 1:length(timelock{jj}.label)
				dt = squeeze(timelock{jj}.trial(:,i,:))';
				plot(timelock{jj}.time',dt,'k-','Color',c{i});
			end
		end
		if isnumeric(ana.plotRange);xlim([ana.plotRange(1) ana.plotRange(2)]);end
		box on;grid on; grid minor; axis tight;
		legend(timelock{1}.label)
		if min(ylim)<mn;mn=min(ylim);end
		if max(ylim)>mx;mx=max(ylim);end
		line([0 0],ylim,'LineWidth',1,'Color','k');
		title(['Var: ' num2str(jj) ' = ' vars{jj}]);
		hz = zoom;hz.enable = 'on';hz.ActionPostCallback = @myCallbackZoom;
		hp = pan;hp.ActionPostCallback = @myCallbackZoom;
	end
	for j = 1:length(timelock);nexttile(tl,j);ylim([mn mx]);end
	t = sprintf('TL: dft=%s demean=%s (%.2f %.2f) detrend=%s poly=%s',ana.dftfilter,ana.demean,ana.baseline(1),ana.baseline(2),ana.detrend,ana.polyremoval);
	tl.XLabel.String = 'Time (s)';
	tl.YLabel.String = 'Amplitude';
	tl.Title.String = t;
end

function plotFreqPower()
	h = figure('Name',['TL Data: ' ana.EDFFile],'Units','normalized',...
		'Position',[0.3 0.1 0.3 0.9]);
	if length(timelock) > 8
		tl = tiledlayout(h,'flow','TileSpacing','compact');
	else
		tl = tiledlayout(h,length(timelock),1,'TileSpacing','compact');
	end
	mn = inf; mx = -inf;
	mint = ana.analRange(1);
	maxt = ana.analRange(2);
	for j = 1:length(timelock)
		minidx = findNearest(timelock{j}.time,mint);
		maxidx = findNearest(timelock{j}.time,maxt);
		nexttile(tl,j)
		hold on
		for iif = 1:length(timelock{j}.label)
			if isfield(timelock{j},'avg')
				[P,f,~,p1,p0,p2] = doFFT(timelock{j}.avg(iif,minidx:maxidx));
			else
				dt = mean(squeeze(timelock{j}.trial(:,iif,:)));
				dt = dt(minidx:maxidx);
				[P,f,~,p1,p0,p2] = doFFT(dt);
			end
			plot(f,P);
			if iif == 1;powf1(j) = p1;powf0(j) = p0;powf2(j) = p2;end
			if min(ylim)<mn;mn=min(ylim);end
			if max(ylim)>mx;mx=max(ylim);end
		end
		legend(timelock{1}.label)
		box on;grid on; grid minor;
		title(['Var: ' num2str(j) ' = ' vars{j}]);
		hz = zoom;hz.enable = 'on';hz.ActionPostCallback = @myCallbackZoom;
		hp = pan;hp.ActionPostCallback = @myCallbackZoom;
	end
	for j = 1:length(timelock);nexttile(tl,j);ylim([mn mx]);xlim([-1 31]);end
	t = sprintf('TL: dft=%s demean=%s (%.2f %.2f) detrend=%s poly=%s',ana.dftfilter,ana.demean,ana.baseline(1),ana.baseline(2),ana.detrend,ana.polyremoval);
	tl.XLabel.String = 'Frequency (Hz)';
	tl.YLabel.String = 'Power';
	tl.Title.String = t;
	figure
	plot(powf0);hold on;plot(powf1);plot(powf2);legend({'Fundamental','First','Second'});
	title('Power at Flicker')
end

function plotFrequency()
	h = figure('Name',['TF Data: ' ana.EDFFile],'Units','normalized',...
		'Position',[0.6 0.1 0.3 0.9]);
	if length(freq) > 8
		tl = tiledlayout(h,'flow','TileSpacing','compact');
	else
		tl = tiledlayout(h,length(freq),1,'TileSpacing','compact');
	end
	
	for jj = 1:length(freq)
		nexttile(tl);
		cfg = [];
		if ~contains(ana.freqbaseline,'none');
			cfg.baseline = ana.freqbaselinevalue;
			cfg.baselinetype = ana.freqbaseline;
		end
		ft_singleplotTFR(cfg,freq{jj});
		line([0 0],[min(ana.freqrange) max(ana.freqrange)],'LineWidth',2);
		xlabel('Time (s)');
		ylabel('Frequency (Hz)');
		box on;grid on; axis tight
		title(['Var: ' num2str(jj) ' = ' vars{jj}]);
	end
	tl.Title.String = 'Time Frequency Analysis';	
end

function plotRawChannels()
	% plotting code to visualise the raw data triggers
	offset = 0;
	nchan = length(cfgRaw.header.label);
	h = figure('Name',['RAW Data: ' cfgRaw.dataset],'Units','normalized',...
		'Position',[0.05 0.05 0.4 0.9]);
	tl = tiledlayout(h,nchan,1,'TileSpacing','compact','Padding','none');
	tm = data_raw.time{1};
    if ~isempty(trl)
        xl = [tm(trl(1,1))-1 tm(trl(1,1))+9];
    else
        xl = [10 20];
    end
	for i = 1:nchan
		ch{i} = data_raw.trial{1}(i+offset,:);
		baseline = nanmedian(ch{i});
		ch{i} = (ch{i} - baseline);
		ch{i} = ch{i} / max(ch{i});
		nexttile(tl,i)
		p = plot(tm,ch{i},'k-'); 
		dtt = p.DataTipTemplate;
		dtt.DataTipRows(1).Format = '%.3f';
		line([min(tm) max(tm)], [0 0],'LineStyle',':','Color',[0.4 0.4 0.4]);
		hold on
		if ~any(ana.bitChannels == i) && (i == 1 || i == ana.pDiode)
			for ii = 1:length(events)
				if ~isempty(events(ii).times)
					y = repmat(ii/10, [1 length(events(ii).times)]);
					plot(events(ii).times,y,'.','MarkerSize',12);
				end
			end
			ylim([-inf inf]);
		elseif any(ana.bitChannels == i)
			ii = i - (ana.bitChannels(1)-1);
			if ~isempty(events(ii).times)
				p=plot(events(ii).times,0.75,'r.','MarkerSize',12);
				dtt = p.DataTipTemplate;
				dtt.DataTipRows(1).Format = '%.3f';
			end
			ylim([-0.05 1.05]);
		end
		if any([ana.dataChannels ana.pDiode] == i) && i == 1 && ~isempty(trl) && size(trl,1) > 1
			ypos = 0.2;
			for jj = 1:size(trl,1) 
				line([tm(trl(jj,1)) tm(trl(jj,2))],[ypos ypos]);
				plot([tm(trl(jj,1)) tm(trl(jj,1)-trl(jj,3)) tm(trl(jj,2)+trl(jj,3))],ypos,'ko','MarkerSize',8);
				text(tm(trl(jj,1)-trl(jj,3)),ypos,['\leftarrow' num2str(trl(jj,4))]);
				text(tm(trl(jj,2)+trl(jj,3)),ypos,'\leftarrow255');
				ypos = ypos+0.125;
				if ypos > 1.0; ypos = 0.3;end
			end
			trgVals = num2cell([triggers.value]);
			trgVals = cellfun(@num2str,trgVals,'UniformOutput',false);
			trgTime = [triggers.time];
			trgY = ones(1,length(trgTime));
			text(trgTime,trgY,trgVals);
		end
		title(data_raw.label{i});
		xlim(xl);
	end
	hz = zoom;
	hz.ActionPostCallback = @myCallbackScroll;
	hp = pan;
	hp.enable = 'on';
	hp.Motion = 'horizontal';
	hp.ActionPostCallback = @myCallbackScroll;
	tl.XLabel.String = 'Time (s)';
	tl.YLabel.String = 'Normalised Amplitude';
end

function myCallbackScroll(~,event)
	src = event.Axes;
	xl = src.XLim;
	for i = 1:length(src.Parent.Children)
		if i < length(src.Parent.Children)-2
			src.Parent.Children(i).YLim = [-0.05 1.05];
		else
			ylim(src.Parent.Children(i),'auto');
		end
		if ~all(xl == src.Parent.Children(i).XLim)
			src.Parent.Children(i).XLim = xl;
		end
	end
end

function myCallbackZoom(~,event)
	src = event.Axes;
	xl = src.XLim;
	xy = src.YLim;
	for i = 1:length(src.Parent.Children)
		if isa(src.Parent.Children(i),'matlab.graphics.axis.Axes')
			if ~all(xl == src.Parent.Children(i).XLim)
				src.Parent.Children(i).XLim = xl;
			end
			if ~all(xy == src.Parent.Children(i).YLim)
				src.Parent.Children(i).YLim = xy;
			end
		end
	end
end

function [idx,val,delta]=findNearest(in,value)
	%find nearest value in a vector, if more than 1 index return the first	
	[~,idx] = min(abs(in - value));
	val = in(idx);
	delta = abs(value - val);
end

function [P, f, A, p1, p0, p2] = doFFT(p)	
	useX = true;
	useHanning = true;
	L = length(p);
	
	fs = data_eeg.fsample;
	ff = (1/info.ana.VEP.Flicker);
	
	if useHanning
		win = hanning(L, 'periodic');
		Pi = fft(p.*win'); 
	else
		Pi = fft(p);
	end

	if useX
		P = abs(Pi/L);
		P=P(1:floor(L/2)+1);
		P(2:end-1) = 2*P(2:end-1);
		f = fs * (0:(L/2))/L;
	else
		NumUniquePts = ceil((L+1)/2);
		P = abs(Pi(1:NumUniquePts));
		f = (0:NumUniquePts-1)*fs/L;
	end

	idx = analysisCore.findNearest(f, ff);
	p1 = P(idx);
	A = angle(Pi(idx));
	idx = analysisCore.findNearest(f, 0);
	p0 = P(idx);
	idx = analysisCore.findNearest(f, ff*2);
	p2 = P(idx);

end

function makeSurrogate()
	f = data_eeg.fsample; %f is the frequency, normally 1000 for LFPs
	mydata = timelock{end};
	tmult = (length(mydata.time)-1) / f; 

	randPhaseRange			= 2*pi; %how much to randomise phase?
	rphase					= 0; %default phase
	basef					= 1; % base frequency
	onsetf					= 5; %an onset at 0 frequency
	onsetLength				= 3; %length of onset signal
	onsetDivisor			= 1.5; %scale the onset frequency
	burstf					= 30; %small burst frequency
	burstOnset				= 1.0; %time of onset of burst freq
	burstLength				= 0.5; %length of burst
	powerDivisor			= 1; %how much to attenuate the secondary frequencies
	group2Divisor			= 1; %do we use a diff divisor for group 2?
	noiseDivisor			= 0.4; %scale noise to signal
	piMult					= basef * 2; %resultant pi multiplier
	burstMult				= burstf * 2; %resultant pi multiplier
	onsetMult				= onsetf * 2; %onset multiplier
	
	time=mydata.time;
	maxtime = max(time);
	if onsetLength > maxtime; onsetLength = maxTime - 0.1; end
	if burstLength > maxtime; burstLength = maxTime - 0.1; end
	
	for k = 1:size(mydata.avg,1)
		mx = max(mydata.avg(k,:));
		mn = min(mydata.avg(k,:));
		rn = mx - mn;
		y = makeSurrogate();
		y = y * rn; % scale to the voltage range of the original trial
		y = y + mn;
		mydata.avg(k,:) = y;
	end
	
	function y = makeSurrogate()
		rphase = rand * randPhaseRange;
		%base frequency
		y = sin((0 : (pi*piMult)/f : (pi*piMult) * tmult)+rphase)';
		y = y(1:length(time));
		%burst frequency with different power in group 2 if present
		rphase = rand * randPhaseRange;
		yy = sin((0 : (pi*burstMult)/f : (pi*burstMult) * burstLength)+rphase)';
		if 1
			yy = yy ./ group2Divisor;
		else
			yy = yy ./ powerDivisor;
		end
		%intermediate onset frequency
		rphase = rand * randPhaseRange;
		yyy = sin((0 : (pi*onsetMult)/f : (pi*onsetMult) * onsetLength)+rphase)';
		yyy = yyy ./ onsetDivisor;
		%find our times to inject yy burst frequency
		st = findNearest(time,burstOnset);
		en = st + length(yy)-1;
		y(st:en) = y(st:en) + yy;
		%add our fixed 0.4s intermediate onset freq
		st = findNearest(time,0);
		en = st + length(yyy)-1;
		y(st:en) = y(st:en) + yyy;
		%add our noise
		y = y + ((rand(size(y))-0.5)./noiseDivisor);
		%normalise our surrogate to be 0-1 range
		y = y - min(y); y = y / max(y); % 0 - 1 range;
		%make sure we are a column vector
		if size(y,2) < size(y,1); y = y'; end
	end
end

end
