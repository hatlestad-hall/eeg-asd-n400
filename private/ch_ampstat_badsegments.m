%% About function
%
% Name:		ch_ampstat_badsegments
% Version:	1.12
%
% Christoffer Hatlestad-Hall
%
%
% Date created:			06 Apr 2020
% Date last modified:	08 Apr 2020
%
% ------------------------------------------------------------------------------------------------------------------------------------------------ %
%
% SUMMARY:
%
% This function computes the amplitude SD or RMS of channels within non-overlapping windows.
%
%
% INPUT:
%
% EEG			|	struct			|		EEGLAB format EEG struct. Must be continuous data.
% cfg			|	struct			|		Configuration struct. Must contain the following fields:
%												.hp_filter	|	High-pass filter cutoff (0 to disable) (default: 0).
%												.lp_filter	|	Low-pass filter cutoff (0 to disable) (default: 0).
%												.z_score	|	Evaluate standardised data; 'on' or 'off' (default). Affects 'threshold'.
%												.stat		|	Type of statistic to compute; 'sd' (default) or 'rms'.
%												.interval	|	The length of each interval/window (seconds) (default: 10).
%												.threshold	|	Amplitude statistic segment rejection threshold (default: 'sd' = 25 / 'rms' = 50).
%												.fraction	|	Above/below statistic threshold channel fraction threshold (default: 0.25).
%												.rej_buffer |	Number of intervals to reject on each side of the bad (default: 1);
%												.chan_frac	|	The fraction of bad intervals for a channel to be bad (default: 0.1);
%												.x_tick		|	Ticks of the x axis (e.g. [ 10 : 10 : 150 ]; default: empty for auto).
%												.visible	|	Toggle figure visibility; 'on' (default) or 'off'.
%
%
% OUTPUT:
%
% amp_fig		|	figure handle	|		Figure handle to the plot.
% rej_segs_time |	matrix			|		Matrix containing the bad segments limits, in seconds.
% rej_segs_pnts	|	matrix			|		Matrix containing the bad segments limits, in samples.
% bad_chans		|	array			|		Array of bad channels according to fraction threshold.
% amp_stat		|	matrix			|		Channel amplitude SD or RMS matrix ( channels x windows ).
% thresh_matrix |	matrix			|		The SD or RMS threshold matrix (matrix plotted in 'amp_fig').
%
% ------------------------------------------------------------------------------------------------------------------------------------------------ %
function [ amp_fig, rej_segs_time, rej_segs_pnts, bad_chans, amp_stat, thresh_matrix ] = ch_ampstat_badsegments ( EEG, cfg )

if nargin < 2, cfg = [ ]; end

% Evaluate input configuration struct; set missing values to default.
if ~isfield ( cfg, 'hp_filter' )	|| isempty ( cfg.hp_filter ),	cfg.hp_filter	= 0;			end
if ~isfield ( cfg, 'lp_filter' )	|| isempty ( cfg.lp_filter ),	cfg.lp_filter	= 0;			end
if ~isfield ( cfg, 'stat' )			|| isempty ( cfg.stat ),		cfg.stat		= 'sd';			end
if ~isfield ( cfg, 'interval' )		|| isempty ( cfg.interval ),	cfg.interval	= 10;			end
if ~isfield ( cfg, 'threshold' )	|| isempty ( cfg.threshold )
	if strcmpi ( cfg.stat, 'sd' )
		if strcmpi ( cfg.z_score, 'off' ),							cfg.threshold	= 25;			end
		if strcmpi ( cfg.z_score, 'on' ),							cfg.threshold	= 3;			end
	end
	if strcmpi ( cfg.stat, 'rms' )
		if strcmpi ( cfg.z_score, 'off' ),							cfg.threshold	= 50;			end
		if strcmpi ( cfg.z_score, 'on' ),							cfg.threshold	= 3;			end
	end
end
if ~isfield ( cfg, 'fraction' )		|| isempty ( cfg.fraction ),	cfg.fraction	= 0.25;			end
if ~isfield ( cfg, 'rej_buffer' )	|| isempty ( cfg.rej_buffer ),	cfg.rej_buffer	= 2;			end
if ~isfield ( cfg, 'chan_frac' )	|| isempty ( cfg.chan_frac ),	cfg.chan_frac	= 0.05;			end
if ~isfield ( cfg, 'x_tick' )		|| isempty ( cfg.x_tick ),		cfg.x_tick		= [ ];			end
if ~isfield ( cfg, 'visible' )		|| isempty ( cfg.visible ),		cfg.visible		= 'on';			end

% Apply the temporary filters.
if cfg.hp_filter ~= 0 || cfg.lp_filter ~= 0
	ch_verbose ( 'Filtering the data...', 2, 1, 5 );
	if cfg.hp_filter == 0, hp = [ ]; else, hp = cfg.hp_filter; end
	if cfg.lp_filter == 0, lp = [ ]; else, lp = cfg.lp_filter; end
	[ EEG, nb_filt_segs ] = ch_padded_filter ( EEG, hp, lp );
	ch_verbose ( sprintf( '%d segment(s) was/were filtered separately before data evaluation.', nb_filt_segs ), 0, 2, 5 );
end

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
boundary_intervals = [ ];
if strcmpi ( cfg.z_score, 'on' )
	data = zscore ( EEG.data );
else
	data = EEG.data;
end
for i = 1 : nb_segments
	
	% Check if the interval contains a boundary event.
	ev_indx = ev_lat >= intervals{ i }( 1 ) & ev_lat <= intervals{ i }( 2 );
	if any ( strcmp( ev_lab( ev_indx ), 'boundary' ) ) == true
		amp_stat( :, i ) = NaN;
		boundary_intervals = [ boundary_intervals, i ]; %#ok<AGROW>
		continue
	end
	
	switch lower ( cfg.stat )
		case 'sd'	% Compute the channels' SD.
			amp_stat( :, i ) = std ( data( :, intervals{ i }( 1 ) : intervals{ i }( 2 ) ), 0, 2 );
			
		case 'rms'	% Compute the channels' RMS.
			amp_stat( :, i ) = rms ( data( :, intervals{ i }( 1 ) : intervals{ i }( 2 ) ), 2 );
	end
end

% Remove NaN columns in matrix (intervals with boundary events).
amp_stat = amp_stat( :, all( ~isnan( amp_stat ) ) );

% Evaluate the intervals in regards to rejection.
thresh_matrix = zeros ( size( amp_stat ) );
above_thresh = amp_stat >= cfg.threshold;
thresh_matrix ( above_thresh ) = 1;

% Identify bad channels (above threshold).
bad_chans = find ( sum( thresh_matrix, 2 ) / size( thresh_matrix, 2 ) >= cfg.chan_frac )';
ch_verbose ( sprintf( 'Number of bad channels found:    %d', length( bad_chans ) ), 1, 1, 5 );

% Identify bad segments (above threshold).
bad_segs = sum ( thresh_matrix, 1 ) / size ( thresh_matrix, 1 ) >= cfg.fraction;

% If there were any boundary events, add these intervals (columns) back to the matrix.
if ~isempty ( boundary_intervals )
	for k = 1 : length ( boundary_intervals )
		thresh_matrix = insertrows ( thresh_matrix', zeros( size( thresh_matrix, 1 ), 1 )', boundary_intervals( k ) - 1 )';
	end
end

% Expand each rejected interval by the buffer.
if cfg.rej_buffer ~= 0
	bad_segs_exp =  false( 1, length( bad_segs ) );
	for i = 1 : length ( bad_segs )
		if bad_segs( i ) == 1
			bad_segs_exp( i ) = 1;
			for k = 1 : cfg.rej_buffer
				if i - k > 0
					bad_segs_exp( i - k ) = 1;
				end
				if i + k <= length ( bad_segs )
					bad_segs_exp( i + k ) = 1;
				end
			end
		end
	end
	bad_segs = bad_segs_exp;
end

% Update the threshold matrix with the rejected intervals.
thresh_matrix ( :, bad_segs ) = thresh_matrix ( :, bad_segs ) + 1;

% Get the number of rejected segments and their time windows.
if any ( bad_segs ) == true
	rej_ints = reshape ( find( diff( [ false, bad_segs, false ] ) ), 2, [ ] )';
	ch_verbose ( sprintf( 'Number of bad segment(s) found:  %d', size( rej_ints, 1 ) ), 1, 2, 5 );
	rej_segs_pnts = zeros ( size( rej_ints ) );
	for m = 1 : size ( rej_ints, 1 )
		
		% Find rejected segment start.
		rej_segs_pnts( m, 1 ) = intervals{ rej_ints( m, 1 ) }( 1 );
		
		% Find rejected segment end.
		rej_segs_pnts( m, 2 ) = intervals{ rej_ints( m, 2 ) - 1 }( 2 );
	end
	
	% Convert the rejected segments limits to seconds.
	rej_segs_time = rej_segs_pnts ./ EEG.srate;
	
	% Compute the total number of bad seconds, and the total fraction of bad data to okay data.
	secs_rm = sum ( rej_segs_time( :, 2 ) - rej_segs_time( :, 1 ) );
	ch_verbose ( sprintf( 'Total length of bad segments:    %d seconds', round( secs_rm ) ), 1, 1, 5 );
	secs_rm_p = secs_rm / EEG.xmax * 100;
	ch_verbose ( sprintf( 'Percentage of total data:        %.1f %%%%', round( secs_rm_p, 1 ) ), 0, 2, 5 );
else
	rej_segs_pnts	= [ ];
	rej_segs_time	= [ ];
	secs_rm			= 0;
	secs_rm_p		= 0;
	ch_verbose ( 'No bad segments were found.', 1, 2, 5 );
end

% Plot the figure.
amp_fig = figure ( 'units', 'normalized', 'outerposition', [ 0.025, 0.025, 0.95, 0.95 ], 'name', EEG.setname, 'visible', cfg.visible );
imagesc ( thresh_matrix, [ 0, 2 ] );

% Adjust the axes.
set ( gca, 'YTick', 1 : EEG.nbchan, 'YTickLabel', { EEG.chanlocs.labels } );
if ~isempty ( cfg.x_tick ), set ( gca, 'XTick', cfg.x_tick ); end

% Add 'BAD' tag to the bad channels, if any.
if ~isempty ( bad_chans )
	amp_axes = gca;
	for v = 1 : length ( bad_chans )
		text ( gca, 'String', 'BAD', 'Color', 'red', 'Position', [ amp_axes.XLim( 2 ) * -0.045, bad_chans( v ) ] );
	end
end

% Add a colourbar.
colorbar ( gca, 'Ticks', [ 0, 1, 2 ], 'TickLabels', ...
	{ 'Okay', 'Bad channel / rejected segment', 'Bad and rejected' }, 'FontSize', 14, 'Location', 'southoutside' );

% Add annotations stating the extent of the bad data and the number of bad channels.
box_str = sprintf ( 'Total length of bad segments:  \\bf%d\\rm seconds\nPercentage of total data:          \\bf%.1f %%\\rm', ...
	round( secs_rm ), round( secs_rm_p, 1 ) );
chan_str = sprintf ( 'Total number of bad channels:  \\bf%d\\rm\nPercentage of total channels:    \\bf%.1f %%\\rm', ...
	length( bad_chans ), round( length( bad_chans ) / size( thresh_matrix, 1 ) * 100, 1 ) );
annotation ( amp_fig, 'textbox', [ 0.75, 0.93, 0.16, 0.05 ], 'String', box_str, 'FitBoxToText', 'on' );
annotation ( amp_fig, 'textbox', [ 0.13, 0.93, 0.16, 0.05 ], 'String', chan_str, 'FitBoxToText', 'on' );

% Add annotations describing the core parameters.
chan_frac_str = sprintf ( 'Channel fraction threshold: \\bf %.1f %%\\rm', cfg.chan_frac * 100 );
segm_frac_str = sprintf ( 'Segment fraction threshold: \\bf %.1f %%\\rm', cfg.fraction * 100 );
threshold_str = sprintf ( 'Amplitude statistic threshold: \\bf %.1f\\rm', cfg.threshold );
annotation ( amp_fig, 'textbox', [ 0.13, 0.05, 0.35, 0.03 ], ...
	'String', sprintf( '\\bfCore parameters:\\rm  %s       |       %s       |       %s', chan_frac_str, threshold_str, segm_frac_str ), ...
	'FitBoxToText', 'on', 'Interpreter', 'tex' );

% Add figure title.
if strcmp ( cfg.stat, 'sd' ), stat_str = 'SD'; else, stat_str = 'RMS'; end
title ( sprintf( 'Channel amplitude %s (%0.f sec intervals)   |   %s', stat_str, cfg.interval, EEG.setname ), ...
	'Interpreter', 'none', 'FontSize', 20 );
end