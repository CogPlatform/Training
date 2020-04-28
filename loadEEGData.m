function [data_eeg_raw,data_eeg,triggers,dd] = loadEEGData();

ft_defaults;
clear data_eeg data_events events triggers
fileName = '13-run3.edf';
matData = 'basicTrain_VEP_13-run3_2020_4_24_14_53_52.mat';
dd = load(matData);
vars = dd.seq.nVar.values;

% which channels are the data channels
dataChannels = 1:2;
% which channels are the TTL signals
bitChannels = 3:10;
% any trigger <= 4 samples after previous is considered artifact and removed
minNextTrigger = 3; 

cfgRaw			= [];
cfgRaw.dataset 	= fileName;
cfgRaw.header	= ft_read_header(cfgRaw.dataset);
labels			= cfgRaw.header.label(bitChannels);
if ~exist('data_eeg','var')
	cfgRaw.continuous	= 'yes';
	cfgRaw.channel		= 'all';
	data_eeg_raw		= ft_preprocessing(cfgRaw);
end
[trl, events, triggers] = loadCOGEEG(cfgRaw);
plotRawChannels(); drawnow;

cfg					= [];
cfg.header			= cfgRaw.header;
cfg.dataset			= fileName;
cfg.trialfun		= 'loadCOGEEG';
cfg					= ft_definetrial(cfg);
cfg.continuous		= 'yes';
cfg.dftfilter		= 'no';
cfg.demean			= 'no';
cfg.baselineWindow	= [-0.1 0.1];
cfg.channel			= dataChannels;
data_eeg			= ft_preprocessing(cfg);

varmap = unique(data_eeg.trialinfo);
for j = 1:length(varmap)
	cfgt			= [];
	cfgt.trials		= find(data_eeg.trialinfo==varmap(j));
	timelock{j}		= ft_timelockanalysis(cfgt,data_eeg);
	cfgt.channel	= 1;
	cfgt.method 	= 'mtmconvol';
	cfgt.taper		= 'hanning';
	cfgt.foi		= 2:2:30;                         % analysis 2 to 30 Hz in steps of 2 Hz
	cfgt.t_ftimwin  = ones(length(cfgt.foi),1).*0.3;   % length of time window = 0.5 sec
	cfgt.toi        = -0.6:0.05:1.6;                  % time window "slides" from -0.5 to 1.5 sec in steps of 0.05 sec (50 ms)
	freq{j}			= ft_freqanalysis(cfgt,data_eeg);
end
plotTimeLock();
plotFrequency();


function plotTimeLock()
	h = figure('Name',['TL Processed Data: ' cfg.dataset],'Units','normalized',...
		'Position',[0.05 0.1 0.2 0.9]);
	tl = tiledlayout(h,length(timelock),1,'TileSpacing','compact');
	for jj = 1:length(timelock)
		nexttile(tl,jj)
		plot(timelock{jj}.time,timelock{jj}.avg);
		box on;grid on; axis tight
		title(['Var: ' num2str(jj) ' = ' num2str(vars(jj))])
	end
	tl.XLabel.String = 'Time (s)';
	tl.YLabel.String = 'Amplitude';
	tl.Title.String = 'Time Lock analysis';
end

function plotFrequency()
	h = figure('Name',['TF Processed Data: ' cfg.dataset],'Units','normalized',...
		'Position',[0 0.1 0.2 0.9]);
	tl = tiledlayout(h,'flow');
	for jj = 1:length(timelock)
		nexttile(tl)
		imagesc(freq{jj}.time,freq{jj}.freq,squeeze(freq{jj}.powspctrm(1,:,:)))
		colorbar;
		xlabel('Time (s)');
		ylabel('Frequency (Hz)');
		box on;grid on; axis tight
		title(['Var: ' num2str(jj) ' = ' num2str(vars(jj))])
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
	tm = data_eeg_raw.time{1};
	xl = [triggers(1).time-1 triggers(1).time+9];
	for i = 1:nchan
		ch{i} = data_eeg_raw.trial{1}(i+offset,:);
		baseline = median(ch{i}(1:100));
		ch{i} = (ch{i} - baseline);
		ch{i} = ch{i} / max(ch{i});
		nexttile(tl,i)
		plot(tm,ch{i},'k-'); hold on
		if i < 3
			for ii = 1:length(events)
				y = repmat(ii/10, [1 length(events(ii).times)]);
				plot(events(ii).times,y,'.','MarkerSize',12);
			end
		else
			ii = i - 2;
			if ~isempty(events(ii).times);plot(events(ii).times,0.75,'r.','MarkerSize',12);end
			ylim([-0.05 1.05]);
		end
		if i == 1
			ypos = 0.2;
			for jj = 1:size(trl,1) 
				line([tm(trl(jj,1)) tm(trl(jj,2))],[ypos ypos]);
				plot([tm(trl(jj,1)) tm(trl(jj,1)-trl(jj,3)) tm(trl(jj,2))],ypos,'ko','MarkerSize',8);
				text(tm(trl(jj,1)-trl(jj,3)),ypos,['\leftarrow' num2str(trl(jj,4))]);
				ypos = ypos+0.125;
				if ypos > 1.0; ypos = 0.3;end
			end
		end
		title(data_eeg_raw.label{i});
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

function myCallbackScroll(src,event)
	src = event.Axes;
	xl = src.XLim;
	for i = 1:length(src.Parent.Children)
		if i < 9
			src.Parent.Children(i).YLim = [-0.05 1.05];
		else
			ylim(src.Parent.Children(i),'auto');
		end
		if ~all(xl == src.Parent.Children(i).XLim)
			src.Parent.Children(i).XLim = xl;
		end
	end
end

function [idx,val,delta]=findNearest(in,value)
	%find nearest value in a vector, if more than 1 index return the first	
	[~,idx] = min(abs(in - value));
	val = in(idx);
	delta = abs(value - val);
end

end
