function [ EEG_out, excl_chans, i ] = ch_iterative_reref ( EEG_in, config )
%% About support function

% Name:		ch_iterative_reref
% Version:	1.11

% Christoffer Hatlestad-Hall


% Date created:			24 Nov 2019
% Date last modified:	09 Apr 2020

% ------------------------------------------------------------------------------------------------------------------------------------------------ %

% SUMMARY:

% This function performs a iterative rereferencing procedure. The method produces a moderately robust average reference by iteratively evaluating
% channels, and excluding low-quality signals from the reference signal. The evaluation is based on channel amplitude standard deviations.


% INPUT:

% EEG			|		struct		|		EEG structure in the EEGLAB format. Note: Data must be continuous ( i.e. not epoched ).
% config		|		struct		|		Configuration structure. Must contain the following fields:
%											.channels		|	Channel indices of EEG channels (EOG and similar should not be included).
%											.max_itr		|	The maximum number of iterations to run.
%											.max_sd			|	The upper limit of SD range to include in the reference signal.
%											.min_sd			|	The lower limit of SD range to include in the reference signal.
%											.hp_filter		|	Temporary high-pass filter cutoff (0 to disable).
%											.lp_filter		|	Temporary low-pass filter cutoff (0 to disable).


% OUTPUT:

% EEG			|		struct		|		The rereferences EEG struct.
% excl_chans	|		array		|		Array of channel indices excluded from the final reference signal.
% i				|		number		|		The final number of iterations run.

% ------------------------------------------------------------------------------------------------------------------------------------------------ %

%% Verify input configuration struct

if exist ( 'config', 'var' )
	config_fn = fieldnames ( config );
	if ~ismember ( config_fn, 'channels' ),		error ( 'ch_iterative_reref: Error. Configuration field ''channels'' is missing.' ); end
	if ~ismember ( config_fn, 'max_itr' ),		error ( 'ch_iterative_reref: Error. Configuration field ''max_itr'' is missing.' ); end
	if ~ismember ( config_fn, 'max_sd' ),		error ( 'ch_iterative_reref: Error. Configuration field ''max_sd'' is missing.' ); end
	if ~ismember ( config_fn, 'min_sd' ),		error ( 'ch_iterative_reref: Error. Configuration field ''min_sd'' is missing.' ); end
	if ~ismember ( config_fn, 'hp_filter' ),	error ( 'ch_iterative_reref: Error. Configuration field ''hp_filter'' is missing.' ); end
	if ~ismember ( config_fn, 'lp_filter' ),	error ( 'ch_iterative_reref: Error. Configuration field ''lp_filter'' is missing.' ); end
	
else
	error ( 'ch_iterative_reref: Error. Configuration struct ''config'' input missing.' )

end

%% Function proper

% Retain only the specified evaluation channels.
EEG = pop_select ( EEG_in, 'channel', config.channels );

% Do initial rereference to average of the specified evaluation channels.
EEG = pop_reref ( EEG, config.channels, 'keepref', 'on' );

% Apply temporary band-pass filter.
if config.hp_filter ~= 0, hp = config.hp_filter; else, hp = [ ]; end
if config.lp_filter ~= 0, lp = config.lp_filter; else, lp = [ ]; end
EEG = pop_eegfiltnew ( EEG, hp, lp );

% Start the first iteration, and loop until max iteration is reached, or min/max SD criteria have been met.
excl_chans = zeros ( 1, length( config.channels ) );
incl_chans = ones ( 1, length( config.channels ) );
for i = 1 : config.max_itr
	
	% Print iteration initialisation.
	fprintf ( '\n\n\n   Iterative rereferencing: Iteration %d ...\n', i );
	
	% Extract the EEG data matrix.
	data = EEG.data;
	
	% Compute the channels' SD.
	sd_chans = std ( data( :, : ), 0, 2 );
	
	% Remove the indices of previously identified bad channels.
	if i > 1
		sd_chans( find( excl_chans ) ) = NaN; %#ok<FNDSB>
	end
	
	% Evaluate SD values against min/max criteria.
	min_sd = find ( sd_chans < config.min_sd );
	max_sd = find ( sd_chans > config.max_sd );
	
	% If all channels are within the set SD criteria, exit the loop to finalize the procedure.
	if isempty ( min_sd ) && isempty ( max_sd ), break; end
	
	% Identify and interpolate all the channels with SD below minimum criterion (probably "flatlined" channels).
	if ~isempty ( min_sd )
		fprintf ( '\n\n      %d channel(s) below SD threshold detected. Removing from reference signal...\n', length( min_sd ) );
		incl_chans( min_sd ) = 0;
		excl_chans( min_sd ) = 1;
	end
	
	% Identify and remove the channel with the highest SD value from the next iteration reference.
	if ~isempty ( max_sd )
		[ ~, top_sd ] = max( sd_chans );
		fprintf ( '\n\n      Removing channel %d from reference signal. SD = %.2f.\n', top_sd, round( sd_chans( top_sd ), 2 ) );
		incl_chans( top_sd ) = 0;
		excl_chans( top_sd ) = 1;
	end
	
	% Rereference for next iteration.
	fprintf ( '\n\n      Rereferencing for next iteration...\n' );
	fprintf ( '      ' );
	EEG = pop_reref ( EEG, find( incl_chans ), 'keepref', 'on' );
end

% Print success statement.
fprintf ( '\n\n\n   Iterative rereferencing done. Excluded %d channels from the reference signal.\n\n', length( find( excl_chans ) ) );

% Finalize the output.
excl_chans = find ( excl_chans );
fprintf ( '   Final rereferencing: ' );
if ~isempty ( excl_chans )
	EEG_out = pop_reref ( EEG_in, find( incl_chans ), 'keepref', 'on' );
else
	EEG_out = pop_reref ( EEG_in, config.channels, 'keepref', 'on' );
end

end