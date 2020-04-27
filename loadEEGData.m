ft_defaults;
clear data_eeg data_events events triggers
fileName = '13-run3.edf';

% which channels are the TTL signals
bitchannels = 3:10;
% any trigger <= 15ms after previous is considered artifact and removed
minNextTriggerTime = 0.015; 

cfg				= [];
cfg.dataset 	= fileName;
cfg.header		= ft_read_header(cfg.dataset);
labels			= cfg.header.label(bitchannels);
data_events		= ft_read_event(cfg.dataset,'header',cfg.header,...
				'detectflank','up','chanindx',bitchannels,'threshold','6*nanmedian');
events = [];
if ~exist('data_eeg','var')
	cfg.continuous	= 'yes';
	cfg.channel 	= 'all';
	data_eeg		= ft_preprocessing(cfg);
end

%parse our events, removing any events < minNextTriggerTime
for i = 1:length(labels)
	lidx = cellfun(@(x)strcmpi(x,labels{i}),{data_events.type});
	events(i).label		= labels{i};
	events(i).idx		= find(lidx==1);
	events(i).evnt		= data_events(events(i).idx);
	events(i).samples	= [events(i).evnt.sample];
	events(i).times		= data_eeg.time{1}(events(i).samples);
	rmTimes = diff(events(i).times);
	rmIdx = find(rmTimes <= minNextTriggerTime);
	if ~isempty(rmIdx)
		rmIdx = rmIdx + 1;
		events(i).idx(rmIdx) = [];
		events(i).evnt(rmIdx) = [];
		events(i).samples(rmIdx) = [];
		events(i).times(rmIdx) = [];
		events(i).rmIdx = rmIdx;
	end
end

% make strobed words from individual events
triggers = [];
times = [];
bidx = 1;
for i = 1:length(events)
	for j = 1:length(events(i).idx)
		fixit = zeros(1,length(events));
		if ~any(times == events(i).times(j)) % check our time list of previously measured events
			triggers(bidx).time = events(i).times(j);
			triggers(bidx).sample = events(i).samples(j);
			triggers(bidx).bword = '00000000';
			triggers(bidx).bword(i) = '1';
			fixit(i) = j;
			% for each event, now we check all other channels for events
			% within 4ms
			for k =  1 : length(events) %check all other channels
				if k == i; continue; end
				[idx,val,delta] = findNearest(events(k).times,triggers(bidx).time);
				if delta < 0.004
					triggers(bidx).bword(k) = '1';
					triggers(bidx).time = min([val,triggers(bidx).time]);
					triggers(bidx).sample = min([events(i).samples(j),events(k).samples(idx)]);
					fixit(k) = idx;
				end
			end
			% make sure all other channels use the same time and sample so
			% we don't double count events
			for l = 1:length(fixit)
				if fixit(l) > 0
					events(l).times(fixit(l)) = triggers(bidx).time;
					events(l).samples(fixit(l)) = triggers(bidx).sample;
				end
			end
			times(end+1) = triggers(bidx).time;
			triggers(bidx).bword = fliplr(triggers(bidx).bword);
			triggers(bidx).value = bin2dec(triggers(bidx).bword);
			triggers(bidx).map = [i j];
			triggers(bidx).fixit = fixit;
			bidx = bidx + 1;
		end
	end
end
[~,sidx] = sort([triggers.time]); %sort by times
triggers = triggers(sidx);
purgeIdx = find(diff([triggers.time]) == 0)+1; %make sure any events with identical times are removed
if ~isempty(purgeIdx)
	warning('Duplicate events! removing...')
	triggers(purgeIdx) = [];
end

nchan = length(data_eeg.label);
offset = 0;

h = figure('Name',fileName,'Units','normalized','Position',[0.1 0.1 0.8 0.8]);
tl = tiledlayout(h,nchan,1,'TileSpacing','compact','Padding','none');

tm = data_eeg.time{1};
xl = [triggers(1).time-1 triggers(1).time+9];
for i = 1:nchan
	ch{i} = data_eeg.trial{1}(i+offset,:);
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
		if ~isempty(9);plot(events(ii).times,0.75,'r.','MarkerSize',12);end
	end
	if i == 1
		ypos = 0.25;
		for jj = 1:length(triggers)
			text(triggers(jj).time,ypos,['\leftarrow' num2str(triggers(jj).value)]);
			ypos = ypos+0.125;
			if ypos > 1.0; ypos = 0.3;end
		end
	end
	title(data_eeg.label{i});
	set(gca,'ButtonDownFcn',@myCallback);
	xlim(xl);
	ylim([-0.05 1.05]);
end

hz = zoom;
hz.ActionPostCallback = @myCallbackScroll;
hp = pan;
hp.enable = 'on';
hp.Motion = 'horizontal';
hp.ActionPostCallback = @myCallbackScroll;
tl.XLabel.String = 'Time (s)';
tl.YLabel.String = 'Normalised Amplitude';


function myCallback(src,event) 
	xl = event.XLim;
	for i = 1:length(src.Parent.Children)
		src.Parent.Children(i).YLim = [-0.05 1.05];
		if ~all(xl == src.Parent.Children(i).XLim)
			src.Parent.Children(i).XLim = xl;
		end
	end
end

function myCallbackScroll(src,event)
	src = event.Axes;
	xl = src.XLim;
	for i = 1:length(src.Parent.Children)
		src.Parent.Children(i).YLim = [-0.05 1.05];
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
