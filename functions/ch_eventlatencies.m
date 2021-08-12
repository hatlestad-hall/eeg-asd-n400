function [ samples, times ] = ch_eventlatencies ( EEG, event, wildcard )
%% About support function

% Name:		ch_eventlatencies
% Version:	1.0

% Christoffer Hatlestad-Hall


% Date created:			27 Nov 2019
% Date last modified:	28 Nov 2019

% ------------------------------------------------------------------------------------------------------------------------------------------------ %

% SUMMARY:

% This support function's purpose is to extract the latencies of all occurrences of a specified event in an EEG set.
% The optional input argument 'wildcard' allows input of event names starting or ending with a particular set of characters.
% The function works on the EEG.event.type field, and only supports string entries.


% INPUT:

% EEG			|	struct		|		EEGLAB format EEG set.
% event			|	char		|		Event marker name to extract (note: Case sensitive).
% wildcard		|	char		|		Optional: Toggle for wildcard function (see above). Possible inputs: 'starts', 'ends' or 'off'.


% OUTPUT:

% samples		|	num (array)	|		Array of samples where the specified event occurs (note: Sample rate dependent!).
% times			|	num (array)	|		Array of time points (seconds) where the specified event occurs.

% ------------------------------------------------------------------------------------------------------------------------------------------------ %

%% Verify input arguments
if nargin == 2
	wildcard = 'off';
end
if nargin < 2
	error('Not enough input arguments');
end

% Remove the '*' from the input event string.
if ~strcmp ( wildcard, 'off' )
	event = strrep ( event, '*', '' );
end

%% Identify event latencies

% Create arrays for storing event latencies (memory allocation).
samples	= zeros ( 1, length( EEG.event ) );
times	= zeros ( 1, length( EEG.event ) );

% Select the appropriate string comparison function, given 'wildcard' input.
switch lower ( wildcard )
	case 'off',		str_fnc = @strcmp;		% Wildcard function disabled: Find latencies for events matching all specified characters.
	case 'starts',	str_fnc = @startsWith;	% Wildcard set to 'starts': Find latencies for events starting with specified characters.
	case 'ends',	str_fnc = @endsWith;	% Wildcard set to 'starts': Find latencies for events ending with specified characters.	
end

% Find event latencies.
i = 0;
for e = 1 : length ( EEG.event )
	if str_fnc ( EEG.event( e ).type, event )
		i = i + 1;
		samples( 1, i ) = EEG.event( e ).latency;
		times( 1, i ) = EEG.event( e ).latency / EEG.srate;
	end
end

% Retain only non-zero values.
samples = nonzeros ( samples );
times	= nonzeros ( times );

end