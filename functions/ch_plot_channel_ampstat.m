%% About function
%
% Name:		ch_plot_channel_ampstat
% Version:	1.1
%
% Christoffer Hatlestad-Hall
%
%
% Date created:			01 Apr 2020
% Date last modified:	02 Apr 2020
%
% ------------------------------------------------------------------------------------------------------------------------------------------------ %
%
% SUMMARY:
%
% This function computes the amplitude SD or RMS of channels within non-overlapping windows, and plots these values in a scaled colour image plot.
% The x-axis represents the time windows, and the y-axis the channels.
%
%
% INPUT:
%
% EEG			|	struct			|		EEGLAB format EEG struct. Must be continuous data.
% cfg			|	struct			|		Configuration struct. Must contain the following fields:
%												.stat		|	Type of statistic to compute; 'sd' (default) or 'rms'.
%												.interval	|	The length of each interval/window (seconds) (default: 10).
%												.x_tick		|	Ticks of the x axis (e.g. [ 10 : 10 : 150 ]; default: empty for auto).
%												.c_limit	|	The color range (default: [ 1, 100 ]).
%												.visible	|	Toggle figure visibility; 'on' (default) or 'off'.
%												.boundaries |	How to handle data boundaries; 'exclude' (default) or 'ignore'.
%
%
% OUTPUT:
%
% sd_fig		|	figure handle	|		Figure handle to the plot.
% amp_stat		|	matrix			|		Channel amplitude SD or RMS matrix ( channels x windows ).
%
% ------------------------------------------------------------------------------------------------------------------------------------------------ %
function [ amp_fig, amp_stat ] = ch_plot_channel_ampstat ( EEG, cfg )

% Evaluate input configuration struct; set missing values to default.
if ~isfield ( cfg, 'stat' )			|| isempty ( cfg.stat ),		cfg.stat		= 'sd';			end
if ~isfield ( cfg, 'interval' )		|| isempty ( cfg.interval ),	cfg.interval	= 10;			end
if ~isfield ( cfg, 'x_tick' )		|| isempty ( cfg.x_tick ),		cfg.x_tick		= [ ];			end
if ~isfield ( cfg, 'c_limit' )		|| isempty ( cfg.c_limit ),		cfg.c_limit		= [ 1, 100 ];	end
if ~isfield ( cfg, 'visible' )		|| isempty ( cfg.visible ),		cfg.visible		= 'on';			end
if ~isfield ( cfg, 'boundaries' )	|| isempty ( cfg.boundaries ),	cfg.boundaries	= 'exclude';	end

% Compute the intervals in which correlation will be computed.
interval_pnts = floor ( cfg.interval * EEG.srate );
nb_segments = floor ( size( EEG.data, 2 ) / interval_pnts );
intervals = cell ( 1, nb_segments );
for i = 1 : nb_segments
	if i == 1
		intervals{ 1, i } = [ 1, interval_pnts ];
	elseif i == nb_segments
		intervals{ 1, i } = [ intervals{ 1, i - 1 }( 2 ) + 1, length( EEG.times ) ];
	else
		intervals{ 1, i } = [ intervals{ 1, i - 1 }( 2 ) + 1, intervals{ 1, i - 1 }( 2 ) + interval_pnts ];
	end
end

% Compute amplitude SD in each segment in each channel.
amp_stat = zeros ( size ( EEG.data, 1 ), nb_segments );
ev_lat = [ EEG.event.latency ];
ev_lab = { EEG.event.type };
for i = 1 : nb_segments
	
	% If enabled, check if the interval contains a boundary event.
	if strcmpi ( cfg.boundaries, 'exclude' )
		ev_indx = ev_lat >= intervals{ i }( 1 ) & ev_lat <= intervals{ i }( 2 );
		if any ( strcmp( ev_lab( ev_indx ), 'boundary' ) )
			amp_stat( :, i ) = NaN;
			continue
		end
	end
	
	switch lower ( cfg.stat )
		case 'sd'	% Compute the channels' SD.
			amp_stat( :, i ) = std ( EEG.data( :, intervals{ i }( 1 ) : intervals{ i }( 2 ) ), 0, 2 );
			
		case 'rms'	% Compute the channels' RMS.
			amp_stat( :, i ) = rms ( EEG.data( :, intervals{ i }( 1 ) : intervals{ i }( 2 ) ), 2 );
	end
end

% If boundary events are to be excluded, remove NaN columns in matrix.
if strcmpi ( cfg.boundaries, 'exclude' )
	amp_stat = amp_stat( :, all( ~isnan( amp_stat ) ) );
end

% Plot the figure.
amp_fig = figure ( 'units', 'normalized', 'outerposition', [ 0.05, 0.05, 0.90, 0.90 ], 'name', EEG.setname, 'visible', cfg.visible );
imagesc ( amp_stat );

% Adjust the axes.
set ( gca, 'YTick', 1 : EEG.nbchan, 'YTickLabel', { EEG.chanlocs.labels }, 'CLim', cfg.c_limit );
if ~isempty ( cfg.x_tick ), set ( gca, 'XTick', cfg.x_tick ); end

% Add a colourbar.
colorbar ( gca );

% Add figure title.
if strcmp ( cfg.boundaries, 'ignore' ), bnd_str = 'boundary windows included'; else, bnd_str = 'boundary windows excluded'; end
if strcmp ( cfg.stat, 'sd' ), stat_str = 'SD'; else, stat_str = 'RMS'; end
title ( sprintf( 'Channel amplitude %s (%0.f sec intervals) (%s)   |   %s', stat_str, cfg.interval, bnd_str, EEG.setname ), 'Interpreter', 'none' );

end