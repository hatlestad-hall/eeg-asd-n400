%% About function
%
% Name:		ch_padded_filter
% Version:	1.1
%
% Christoffer Hatlestad-Hall
%
%
% Date created:			17 Feb 2020
% Date last modified:	08 Apr 2020
%
% ------------------------------------------------------------------------------------------------------------------------------------------------ %
%
% SUMMARY:
%
% This function implements padded filtering of continuous data which file contains discontinuities marked by boundary events.
% Mirrored data are added at the start and at the end of each segment (default is 10 seconds of mirrored data).
% The function uses the default 'pop_eegnewfilt' to filter each segment.
% Note that the function only accepts data with the following structure: [data] - boundary - [data] - boundary - ... - [data]
%
%
% INPUT:
%
% EEG		|		struct		|		EEGLAB data structure.
% hp		|		number		|		Lower-edge limit passed to 'pop_eegfiltnew'.
% lp		|		number		|		Upper-edge limit passed to 'pop_eegfiltnew'.
%
%
% OUTPUT:
%
% EEG		|		struct		|		Filtered EEGLAB data structure.
% nb_segs	|		integer		|		The number of filtered segments. May be used as a sanity check.
%
% ------------------------------------------------------------------------------------------------------------------------------------------------ %
function [ EEG, nb_segs ] = ch_padded_filter ( EEG, hp, lp )																			%#ok<*INUSD>

% Set padding size (seconds).
padding_s = 10;

% Find the boundary events.
all_events	= { EEG.event.type };
all_lats	= [ EEG.event.latency ];
boundaries	= contains ( all_events, 'boundary' );
bound_lats	= all_lats( boundaries );
bound_ints	= zeros ( size( bound_lats, 2 ) + 1, 2 );
for i = 1 : size ( bound_ints, 1 )
	if i == 1
		bound_ints( i, 1 ) = 1;
		bound_ints( i, 2 ) = bound_lats( i );
	elseif i == size ( bound_ints, 1 )
		bound_ints( i, 1 ) = bound_lats( i - 1 ) + 1;
		bound_ints( i, 2 ) = size ( EEG.data, 2 );
	else
		bound_ints( i, 1 ) = bound_lats( i - 1 ) + 1;
		bound_ints( i, 2 ) = bound_lats( i );
	end
end

% Filter the segments separated by boundaries separately.
nb_segs = size ( bound_ints, 1 );
for s = 1 : nb_segs
	
	% Extract the segment data.
	[ ~, EEG_seg( s ) ] = evalc ( 'pop_select ( EEG, ''point'', [ bound_ints( s, 1 ), bound_ints( s, 2 ) ] );' );						%#ok<*AGROW>
	
	% Remove potential boundary events from the segment data.
	rm_events = contains ( { EEG_seg( s ).event.type }, 'boundary' );
	if any ( rm_events )
		EEG_seg( s ) = pop_editeventvals ( EEG_seg( s ), 'delete', find( rm_events ) );
	end
	
	% Add n seconds of mirrored data on each side of the segment before filtering.
	length_ok = false;
	pad_length = padding_s;
	while length_ok == false
		try		% If the segment length is shorter than the padding length, try reducing the padding length.
			padding_data = EEG_seg( s ).data( :, 1 : pad_length * EEG.srate );
		catch
			pad_length = pad_length - 1;
			continue
		end
		length_ok = true;
	end
	padding_data = fliplr ( padding_data );
	EEG_seg( s ).data = insertrows ( EEG_seg( s ).data', padding_data', 0 )';
	
	padding_data = EEG_seg( s ).data( :, end - pad_length * EEG.srate : end );
	padding_data = fliplr ( padding_data );
	EEG_seg( s ).data = insertrows ( EEG_seg( s ).data', padding_data', size( EEG_seg( s ).data, 2 ) )';
	
	EEG_seg( s ).pnts = size ( EEG_seg( s ).data, 2 );
	
	% Filter the data.
	[ ~, EEG_seg( s ) ] = evalc ( 'pop_eegfiltnew ( EEG_seg( s ), hp, lp );' );
	
	% Remove the padding.
	EEG_seg( s ).data( :, [ 1 : pad_length * EEG.srate, end - pad_length * EEG.srate : end ] ) = [ ];
end

% Transfer the filtered data to the original EEG structure.
EEG.data = [ EEG_seg.data ];

end