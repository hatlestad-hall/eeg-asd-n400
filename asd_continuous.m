%% Configuration

% Debug mode.
debug_mode	= false;

% Channel extraction and position information.
cfg.channels	= 1 : 64;
cfg.pos_file	= 'BioSemi_SRM_template_64_locs.xyz';			% ( file must be on the MATLAB path )
cfg.montage		= '64';

% Event marker labels.
cfg.label_fnc	= 'label_events_asd';							% ( function file must be on the MATLAB path )

% Resampling frequency.
cfg.resample	= 512;											% ( [ ] to disable )

% Assembling of data segments.
cfg.assemble.event_limits	= { 'Im B1*', 'Wo B2*' };
cfg.assemble.min_max		= [ 0, 1 ];
cfg.assemble.shift			= [ -1.5, 1.5 ];
cfg.assemble.labels			= { 'Main' };
cfg.assemble.plot_segs		= true;

% Iterative moderately robust re-referencing.
cfg.itr_reref.channels	= 1 : 64;
cfg.itr_reref.max_itr	= 32;
cfg.itr_reref.max_sd	= 25;
cfg.itr_reref.min_sd	= 1;
cfg.itr_reref.hp_filter	= 1;
cfg.itr_reref.lp_filter	= 0;

% High-pass filtering.
cfg.hp_filter	= 1;

% Low-pass filtering.
cfg.lp_filter	= 40;

% Channels' amplitude amplitude stats scaled colour image.
cfg.stat_image.stat			= 'sd';
cfg.stat_image.interval		= 5;
cfg.stat_image.x_tick		= [ ];
cfg.stat_image.c_limit		= [ 1, 75 ];
cfg.stat_image.visible		= 'off';
cfg.stat_image.boundaries	= 'exclude';

% Channels' RMS amplitude pre- and post-IC removal.
cfg.ic_image.stat			= 'rms';
cfg.ic_image.interval		= 5;
cfg.ic_image.x_tick			= [ ];
cfg.ic_image.c_limit		= [ 1, 30 ];
cfg.ic_image.visible		= 'off';
cfg.ic_image.boundaries		= 'exclude';

% Removal of segments with extensive noise in multiple channels (1) and channels with very low SNR (2).
cfg.ampstat( 1 ).hp_filter	= 0;			cfg.ampstat( 2 ).hp_filter	= 0;
cfg.ampstat( 1 ).lp_filter	= 0;			cfg.ampstat( 2 ).lp_filter	= 0;
cfg.ampstat( 1 ).z_score	= 'off';		cfg.ampstat( 2 ).z_score	= 'on';
cfg.ampstat( 1 ).stat		= 'sd';			cfg.ampstat( 2 ).stat		= 'rms';
cfg.ampstat( 1 ).interval	= 5;			cfg.ampstat( 2 ).interval	= 5;
cfg.ampstat( 1 ).threshold	= 40;			cfg.ampstat( 2 ).threshold	= 3;
cfg.ampstat( 1 ).fraction	= 0.50;			cfg.ampstat( 2 ).fraction	= 1;
cfg.ampstat( 1 ).rej_buffer	= 2;			cfg.ampstat( 2 ).rej_buffer	= 2;
cfg.ampstat( 1 ).chan_frac	= 1;			cfg.ampstat( 2 ).chan_frac	= 0.10;
cfg.ampstat( 1 ).x_tick		= [ ];			cfg.ampstat( 2 ).x_tick		= [ ];
cfg.ampstat( 1 ).visible	= 'off';		cfg.ampstat( 2 ).visible	= 'off';

% Independent component removal.
cfg.ic_rem.auto_comp_sub	= true;
cfg.ic_rem.label_threshold	= 0.80;
cfg.ic_rem.remove_types		= { 'eye', 'muscle' };

%% Preparation

% Make sure EEGLAB (base directory), NoiseTools and support functions are added to the MATLAB path.
AddPath ( 'reset' );
AddPath ( 'eeglab' );
AddPath ( 'noisetools' );
AddPath ( 'support' );

% Select files.
ch_verbose ( 'Select input file(s)...', 2, 2 );
files = ch_selectfiles ( 'bdf', 'on' );

% Select the output directory.
ch_verbose ( 'Select output directory...', 2, 2 );
output_dir	= [ uigetdir( sprintf( '%s/../', files( 1 ).folder ), 'Select output directory' ) '/' ];
if numel ( output_dir ) < 3, return; end

% If it doesn't exist, create output directory for command window output text file(s).
if ~exist ( sprintf( '%s%s', output_dir, 'CW output files' ), 'dir' )
	mkdir ( sprintf( '%s%s', output_dir, 'CW output files' ) );
end

% Run EEGLAB, and close the GUI.
eeglab;
close;

% Make sure EEGLAB uses double precision, not single.
pop_editoptions ( 'option_single', false );

% If debug mode is enabled, configure to pause on error.
if debug_mode
	dbstop if error
else
	dbclear all
end

% Start timer.
start_time = tic;

%% Processing loop
for file = 1 : numel ( files )
	try
		
		% Clear the log struct in preparation for the upcoming file.
		log = [ ];
		
		% Get the setname for the upcoming file.
		[ ~, setname ] = fileparts ( sprintf( '%s/%s', files( file ).folder, files( file ).name ) );
		log.setname = setname;
		
		% Define the text file to which command window output will be written; initiate logging of command window output.
		cw_file = sprintf( '%s%s/CW_%s.txt', output_dir, 'CW output files', setname );
		diary ( cw_file );
		
		% Print loop iteration number.
		ch_output_separator;
		ch_verbose ( sprintf( 'Starting preprocessing of file %d of %d:', file, numel( files ) ), 2, 2 );
		
		% Load file (if pop_fileio crashes, pop_readbdf is used instead).
		ch_output_separator;
		ch_verbose ( sprintf( 'Importing file: %s...', files( file ).name ), 2, 2 );
		try
			EEG = pop_fileio ( sprintf( '%s/%s', files( file ).folder, files( file ).name ) );
		catch
			ch_verbose ( 'WARNING! pop_fileio crashed. Trying pop_biosig. Referencing to first channel.', 2, 2 );
			
			EEG = pop_biosig ( sprintf( '%s/%s', files( file ).folder, files( file ).name ), 'ref', 1, 'refoptions', { 'keepref', 'on' } );
		end
		
		% Select channels and add channels position information.
		ch_output_separator;
		ch_verbose ( 'Extracting channels for further preprocessing, and adding channel position information...', 2, 2 );
		EEG = pop_select ( EEG, 'channel', cfg.channels );
		try
			EEG = pop_chanedit ( EEG, 'lookup', which( 'BioSemi_SRM_template_64_locs.xyz' ) );
		catch
			
			% If unable to find the specified file, allow manual selection.
			ch_verbose ( 'Unable to find channel position information file on the MATLAB path.', 2, 2 );
			pos_ans	= questdlg ( sprintf( 'Unable to find channel position information file on the MATLAB path.\nSelect it manually?' ), ...
				'Channel position information file', 'Yes', 'No', 'Yes' );
			
			switch lower ( pos_ans )
				case 'yes'
					[ pos_file, pos_dir ] = uigetfile ( { '*.xyz; *.elc' }, 'Select channel position information file' );
					
				otherwise
					error ( 'Error. Channel position information file not found.' );
			end
			
			% Add the selected file's directory to the MATLAB path.
			addpath ( pos_dir );
			
			% Add the channel position information to the EEG.
			EEG = pop_chanedit ( EEG, 'lookup', which( pos_file ) );
			
			% Edit the configuration struct to include the selected file.
			cfg.pos_file = pos_file;
		end
		
		% Get the function for renaming of relevant event markers.
		ch_output_separator;
		ch_verbose ( 'Adding labels to relevant event markers...', 2, 2 );
		try
			label_fnc = str2func ( cfg.label_fnc );
		catch
			
			% If unable to find the specified file, allow manual selection.
			ch_verbose ( 'Unable to find specified label function file on the MATLAB path.', 2, 2 );
			lab_ans	= questdlg ( sprintf( 'Unable to find label function file on the MATLAB path.\nSelect it manually?' ), ...
				'Label function file', 'Yes', 'No', 'Yes' );
			
			switch lower ( lab_ans )
				case 'yes'
					[ lab_file, lab_dir ] = uigetfile ( { '*.xyz; *.elc' }, 'Select label function file' );
					
				otherwise
					error ( 'Error. Event marker label function file not found.' );
			end
			
			% Add the selected file's directory to the MATLAB path.
			addpath ( lab_dir );
			
			% Use the selected file to generate the function string.
			[ ~, label_fnc_name ] = fileparts ( lab_file );
			label_fnc = str2func ( label_fnc_name );
			
			% Edit the configuration struct to include the selected function.
			cfg.label_fnc = label_fnc;
		end
		
		% Store the original 'chanlocs' and 'chaninfo' structures.
		EEG.etc.orig_chanlocs = EEG.chanlocs;
		EEG.etc.orig_chaninfo = EEG.chaninfo;
		
		% Run the label function.
		label_events = label_fnc ( );
		EEG	= ch_label_events ( EEG, label_events, false, false );
		
		% Resample data.
		if ~isempty ( cfg.resample )
			ch_verbose ( 'Resampling data...', 2, 2 );
			EEG	= pop_resample ( EEG, cfg.resample );
			EEG.setname = setname;
		end
		
		% Assemble data segments.
		ch_output_separator;
		ch_verbose ( 'Assembling data segments...', 2, 2 );
		[ log.segments, seg_fig ] = ch_assembledata ( EEG, cfg.assemble );
		
		% Save and close the figure from ch_assembledata.
		% If the save directory doesn't exist, create it; then save.
		if ~exist ( sprintf( '%s%s', output_dir, 'Segments plots' ), 'dir' )
			mkdir ( sprintf( '%s%s', output_dir, 'Segments plots' ) );
		end
		saveas ( seg_fig, sprintf( '%s/%s.png', sprintf( '%s%s', output_dir, 'Segments plots' ), EEG.setname ) );
		close ( seg_fig );
		
		% Extract the assembled data.
		seg_nan = isnan ( [ log.segments.start_time ] );
		data_segs = zeros ( length( log.segments ) - sum( double( seg_nan ) ), 2 );
		for s = 1 : size ( data_segs, 1 )
			data_segs( s, 1 ) = log.segments( s ).start_time;
			data_segs( s, 2 ) = log.segments( s ).end_time;
		end
		fprintf ( '\n\n' );
		EEG = pop_select ( EEG, 'time', data_segs );
		
		% Remove 'NaN' events and any boundaries occuring before paradigm onset.
		ch_output_separator;
		ch_verbose ( 'Removing ''NaN'' events and any boundary events occuring before paradigm onset...', 2, 2 );
		rm_events = contains ( { EEG.event.type }, 'NaN' );
		EEG = pop_editeventvals ( EEG, 'delete', find( rm_events ) );
		if strcmpi ( EEG.event( 1 ).type, 'boundary' )
			EEG = pop_editeventvals ( EEG, 'delete', 1 );
		end
		
		% Iterative moderately robust re-referencing (if necessary, convert channel labels to indices first).
		ch_output_separator;
		ch_verbose ( 'Iterative re-referencing...', 2, 2 );
		if ischar ( cfg.itr_reref.channels ) || iscell ( cfg.itr_reref.channels )
			cfg.itr_reref.channels = ch_channels ( cfg.montage, cfg.itr_reref.channels );
		end
		[ EEG, log.excl_ref, log.itr_ref ] = ch_iterative_reref ( EEG, cfg.itr_reref );
		
		% High-pass filter (with extended boundary padding).
		ch_output_separator;
		ch_verbose ( 'High-pass filtering the data...', 2, 1 );
		EEG = pop_eegfiltnew ( EEG, cfg.hp_filter, [ ] );
		
		% Remove line noise with Zapline.
		ch_output_separator;
		ch_verbose ( 'Removing line noise with Zapline...', 2, 2 );
		EEG.data = nt_zapline ( EEG.data', 50 / EEG.srate, 4 )';
		
		% Low-pass filter (with extended boundary padding).
		ch_output_separator;
		ch_verbose ( 'Low-pass filtering the data...', 2, 1 );
		EEG = pop_eegfiltnew ( EEG, [ ], cfg.lp_filter );
		
		% Plot scaled colour image of channels' amplitude SD, before removal of bad segments.
		ch_output_separator;
		ch_verbose ( 'Plotting scaled colour image of channels'' amplitude SD...', 2, 2 );
		sd_img = ch_plot_channel_ampstat ( EEG, cfg.stat_image );
		
		% Save and close the figure from ch_plot_channel_ampstat.
		% If the save directory doesn't exist, create it; then save.
		if ~exist ( sprintf( '%s%s', output_dir, 'Amplitude SD plots' ), 'dir' )
			mkdir ( sprintf( '%s%s', output_dir, 'Amplitude SD plots' ) );
		end
		saveas ( sd_img, sprintf( '%s/%s_1_pre.png', sprintf( '%s%s', output_dir, 'Amplitude SD plots' ), EEG.setname ) );
		close ( sd_img );
		
		% Find and discard noisy segments.
		ch_output_separator;
		ch_verbose ( 'Finding segments which are very noisy in multiple channels...', 2, 2 );
		[ amp_fig, log.rej_segs_time, ~, ~, log.segs_amp_matrix ] = ch_ampstat_badsegments ( EEG, cfg.ampstat( 1 ) );
		
		% Save and close the figure from ch_ampstat_badsegments.
		% If the save directory doesn't exist, create it; then save.
		if ~exist ( sprintf( '%s%s', output_dir, 'Rejected segments plots' ), 'dir' )
			mkdir ( sprintf( '%s%s', output_dir, 'Rejected segments plots' ) );
		end
		saveas ( amp_fig, sprintf( '%s/%s.png', sprintf( '%s%s', output_dir, 'Rejected segments plots' ), EEG.setname ) );
		close ( amp_fig );
		
		% Remove the bad segments from the data.
		if ~isempty ( log.rej_segs_time )
			ch_verbose ( 'Discarding bad segments...', 2, 2 );
			EEG = pop_select ( EEG, 'notime', log.rej_segs_time );
		else
			ch_verbose ( 'No bad segments identified.', 2, 2 );
		end
		
		% Plot scaled colour image of channels' amplitude SD, after removal of bad segments.
		ch_output_separator;
		ch_verbose ( 'Plotting scaled colour image of channels'' amplitude SD...', 2, 2 );
		sd_img = ch_plot_channel_ampstat ( EEG, cfg.stat_image );
		
		% Save and close the figure from ch_plot_channel_ampstat.
		% If the save directory doesn't exist, create it; then save.
		if ~exist ( sprintf( '%s%s', output_dir, 'Amplitude SD plots' ), 'dir' )
			mkdir ( sprintf( '%s%s', output_dir, 'Amplitude SD plots' ) );
		end
		saveas ( sd_img, sprintf( '%s/%s_2_post.png', sprintf( '%s%s', output_dir, 'Amplitude SD plots' ), EEG.setname ) );
		close ( sd_img );
		
		% Identify channels with very low signal-to-noise ratio with the specified method, and remove these before ICA.
		ch_output_separator;
		ch_verbose ( 'Identifying channels with very low signal-to-noise ratio...' );
		[ amp_fig, ~, ~, log.bad_snr, log.snr_amp_matrix ] = ch_ampstat_badsegments ( EEG, cfg.ampstat( 2 ) );
		EEG.etc.bad_channels = log.bad_snr;
		
		% Save and close the figure from ch_ampstat_badsegments.
		% If the save directory doesn't exist, create it; then save.
		if ~exist ( sprintf( '%s%s', output_dir, 'Rejected channels plots' ), 'dir' )
			mkdir ( sprintf( '%s%s', output_dir, 'Rejected channels plots' ) );
		end
		saveas ( amp_fig, sprintf( '%s/%s_1_SNR.png', sprintf( '%s%s', output_dir, 'Rejected channels plots' ), EEG.setname ) );
		close ( amp_fig );
		
		% If any, remove the channels.
		if ~isempty ( log.bad_snr )
			ch_verbose ( sprintf( 'Removing %d channel(s) with very low signal-to-noise ratio...', length( log.bad_snr ) ), 2, 2 );
			EEG = pop_select ( EEG, 'nochannel', log.bad_snr );
		else
			ch_verbose ( 'No channels with very low signal-to-noise ratio were identified.' );
		end
		
		% Rereference to average reference.
		ch_output_separator;
		ch_verbose ( 'Re-referencing to average signal...', 2, 2 );
		EEG = pop_reref ( EEG, [ ] );
		
		% Run SOBI.
		ch_output_separator;
		ch_verbose ( 'Running SOBI...', 2, 2 );
		EEG = pop_runica ( EEG, 'icatype', 'sobi', 'chanind', 1 : EEG.nbchan );
		
		% Plot scaled colour image of channels' amplitude RMS, before removal of artefact components.
		ch_output_separator;
		ch_verbose ( 'Plotting scaled colour image of channels'' amplitude RMS...', 2, 2 );
		rms_img = ch_plot_channel_ampstat ( EEG, cfg.ic_image );
		
		% Save and close the figure from ch_plot_channel_ampstat.
		% If the save directory doesn't exist, create it; then save.
		if ~exist ( sprintf( '%s%s', output_dir, 'ICA RMS plots' ), 'dir' )
			mkdir ( sprintf( '%s%s', output_dir, 'ICA RMS plots' ) );
		end
		saveas ( rms_img, sprintf( '%s/%s_1_pre.png', sprintf( '%s%s', output_dir, 'ICA RMS plots' ), EEG.setname ) );
		close ( rms_img );
		
		% Run ICLabel, and subsequently remove independent components of specified categories.
		ch_output_separator;
		if ~isfield ( EEG.etc, 'ic_classification' )
			fprintf ( '\n\nLabelling ICs and subtracting specified categories of ICs.\n\n' );
			EEG = iclabel ( EEG );
		else
			fprintf ( '\n\nIC labels already present. Continuing to component rejection...\n\n' );
		end
		
		% If automatic component subtraction is enabled; identify, plot, and subtract components.
		if cfg.ic_rem.auto_comp_sub == true
			
			ch_verbose ( sprintf( 'Auto-subtracting ICA components. Category likelihood threshold: %4.2f.', ...
				cfg.ic_rem.label_threshold ), 2, 2 );
			
			[ ~, ic_labels ] = max ( EEG.etc.ic_classification.ICLabel.classifications, [ ], 2 );
			
			% Disregard all components with a likelihood factor below the set threshold.
			for c = 1 : length ( ic_labels )
				if EEG.etc.ic_classification.ICLabel.classifications( c, ic_labels( c ) ) < cfg.ic_rem.label_threshold
					ic_labels( c ) = 0;
				end
			end
			
			% Loop through all specified ICA component category, and index all components associated with each.
			comp_rej_index = [ ];
			for icl = 1 : length ( cfg.ic_rem.remove_types )
				switch cfg.ic_rem.remove_types{ icl }
					case { 'Brain', 'brain' },			comp_rej_index = [ comp_rej_index find( ic_labels == 1 )' ]; %#ok<*AGROW>
					case { 'Muscle', 'muscle' },		comp_rej_index = [ comp_rej_index find( ic_labels == 2 )' ];
					case { 'Eye', 'eye' },				comp_rej_index = [ comp_rej_index find( ic_labels == 3 )' ];
					case { 'Heart', 'heart' },			comp_rej_index = [ comp_rej_index find( ic_labels == 4 )' ];
					case { 'LineNoise', 'lineNoise' },	comp_rej_index = [ comp_rej_index find( ic_labels == 5 )' ];
					case { 'ChanNoise', 'chanNoise' },	comp_rej_index = [ comp_rej_index find( ic_labels == 6 )' ];
					case { 'Other', 'other' },			comp_rej_index = [ comp_rej_index find( ic_labels == 7 )' ];
				end
			end
			
			% Plot the components marked for subtraction (if any), and save the figures. Subtract component when plotted.
			if ~isempty ( comp_rej_index )
				
				ch_verbose ( sprintf( 'Plotting the subtracted ICA components. Number: %0.f', length( comp_rej_index ) ), 2, 4 );
				
				% If the save directory for subtracted ICs doesn't exist, create it.
				if ~exist ( sprintf( '%s%s', output_dir, 'Subtracted ICs plots' ), 'dir' )
					mkdir ( sprintf( '%s%s', output_dir, 'Subtracted ICs plots' ) );
				end
				
				for I = 1 : length ( comp_rej_index )
					comp = comp_rej_index( I );
					[ comp_fig, ~, ~ ] = pop_prop_extended ( EEG, 0, comp, NaN, { 'freqrange', [ 1, 100 ] }, { }, 1, 'ICLabel' );
					savename = sprintf ( '%s/%s_IC_%s.png', sprintf( '%s%s', output_dir, 'Subtracted ICs plots' ), EEG.setname, num2str( comp ) );
					saveas ( comp_fig, savename );
					close ( comp_fig );
				end
				
				% Subtract the component from the data.
				EEG = pop_subcomp ( EEG, comp_rej_index, 0, 0 );
				EEG.setname = setname;
				log.ics_subtracted = length ( comp_rej_index );
				EEG = iclabel ( EEG );
			end
			
		else
			
			% If automatic component subtraction is disabled, create empty rejection index.
			log.ics_subtracted = NaN;
		end
		
		% Plot scaled colour image of channels' amplitude RMS, after removal of artefact components.
		ch_output_separator;
		ch_verbose ( 'Plotting scaled colour image of channels'' amplitude RMS...', 2, 2 );
		rms_img = ch_plot_channel_ampstat ( EEG, cfg.ic_image );
		
		% Save and close the figure from ch_plot_channel_ampstat.
		% If the save directory doesn't exist, create it; then save.
		if ~exist ( sprintf( '%s%s', output_dir, 'ICA RMS plots' ), 'dir' )
			mkdir ( sprintf( '%s%s', output_dir, 'ICA RMS plots' ) );
		end
		saveas ( rms_img, sprintf( '%s/%s_2_post.png', sprintf( '%s%s', output_dir, 'ICA RMS plots' ), EEG.setname ) );
		close ( rms_img );
		
		% If any, interpolate the channels which were removed due to very low signal-to-noise ratio.
		if ~isempty ( EEG.etc.bad_channels )
			ch_output_separator;
			ch_verbose ( 'Interpolating the channels which were removed due to very low signal-to-noise ratio...', 2, 2 );
			EEG = pop_interp ( EEG, EEG.etc.orig_chanlocs, 'spherical' );
		end
		
		% Get the channel labels corresponding to the channel indices for the bad channels.
		chanlabels = { EEG.chanlocs.labels };
		EEG.etc.bad_channels_labels = chanlabels( EEG.etc.bad_channels );
		
		% Plot a topographic plot of the bad/interpolated channels, and save it.
		ch_verbose ( 'Plotting bad channels locations (if any)...', 2, 2 );
		topo_badchan = figure ( 'Visible', 'off' );
		
		if ~isempty ( EEG.etc.bad_channels )
			topoplot ( [ ], EEG.chanlocs, 'plotchans', EEG.etc.bad_channels, ...
				'style', 'blank', 'electrodes', 'ptslabels', 'chaninfo', EEG.chaninfo );
		end
		
		% If the save directory doesn't exist, create it; then save and close the figure.
		if ~exist ( sprintf( '%s%s', output_dir, 'Rejected channels plots' ), 'dir' )
			mkdir ( sprintf( '%s%s', output_dir, 'Rejected channels plots' ) );
		end
		saveas ( topo_badchan, sprintf( '%s/%s_topo.png', sprintf( '%s%s', output_dir, 'Rejected channels plots' ), EEG.setname ) );
		close ( topo_badchan );
		
		% Plot scaled colour image of channels' amplitude SD, after interpolation of bad channels.
		ch_output_separator;
		ch_verbose ( 'Plotting scaled colour image of channels'' amplitude SD...', 2, 2 );
		sd_img = ch_plot_channel_ampstat ( EEG, cfg.stat_image );
		
		% Save and close the figure from ch_plot_channel_ampstat.
		% If the save directory doesn't exist, create it; then save.
		if ~exist ( sprintf( '%s%s', output_dir, 'Amplitude SD plots' ), 'dir' )
			mkdir ( sprintf( '%s%s', output_dir, 'Amplitude SD plots' ) );
		end
		saveas ( sd_img, sprintf( '%s/%s_3_final.png', sprintf( '%s%s', output_dir, 'Amplitude SD plots' ), EEG.setname ) );
		close ( sd_img );
		
		% Save the processed, continuous EEG file.
		ch_output_separator;
		ch_verbose ( 'Saving the processed EEG and log files...', 2, 2 );
		pop_saveset ( EEG, 'filename', EEG.setname, 'filepath', output_dir, 'savemode', 'onefile' );
		
		% Save the log file (if the save directory for log files doesn't exist, create it).
		log.configuration = cfg;
		if ~exist ( sprintf( '%s%s', output_dir, 'Log files' ), 'dir' )
			mkdir ( sprintf( '%s%s', output_dir, 'Log files' ) );
		end
		save ( sprintf( '%s/%s_log.mat', sprintf( '%s%s', output_dir, 'Log files' ), EEG.setname ), 'log' );
		
		% Display completion statement and (if not the final file) print the estimated remaining time for the batch.
		ch_output_separator;
		ch_verbose ( sprintf( 'EEG file done: %s.', EEG.setname ), 2, 2 );
		if file ~= numel ( files )
			ch_timeremaining ( start_time, file, numel( files ) );
		end
		
		% Stop recording the command window output.
		diary off
		
	catch error_info
		
		% Display error message.
		ch_verbose ( 'ERROR ENCOUNTERED. Saving information relevant for error analysis. Continuing with next file.', 4, 4 );
		
		% If present, save the error info, EEG file, log and configuration struct for error analysis.
		error_dir = sprintf ( '%s%s_%s/', output_dir, 'Error', EEG.setname );
		mkdir ( error_dir );
		save ( sprintf( '%s%s', error_dir, 'cfg.mat' ), 'cfg' );
		try
			save ( sprintf( '%s%s', error_dir, 'log.mat' ), 'log' );
		catch
		end
		save ( sprintf( '%s%s', error_dir, 'error_info.mat' ), 'error_info' );
		try
			pop_saveset ( EEG, 'filename', EEG.setname, 'filepath', error_dir, 'savemode', 'onefile' );
		catch
			try
				save ( sprintf( '%s%s', error_dir, 'eeg.mat' ), 'EEG' );
			catch
			end
		end
		
		% Print total time elapsed and remaining time estimate.
		ch_timeremaining ( start_time, file, numel( files ) );
		
		% End the command window output recording.
		diary off
		
		% If debug mode is enabled, rethrow error; else, continue to the next file.
		if debug_mode
			ch_verbose ( 'Debug mode enabled. Terminating execution with error.', 2, 2 );
			rethrow ( error_info )
		else
			ch_verbose ( 'Debug mode disabled. Proceeding to the next file.', 2, 2 ); %#ok<*UNRCH>
			continue
		end
	end
end

%% Wrap up

% Print completion statement and total elapsed time.
ch_verbose ( 'Batch completed!', 5, 1 );
