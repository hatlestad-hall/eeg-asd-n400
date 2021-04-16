function channels = ch_channels ( montage_id, selection, exclude )
%% About

% Name:		ch_channels
% Version:	1.0

% Christoffer Hatlestad-Hall


% Date created:			29 Oct 2019
% Date last modified:	09 Jan 2020

% ------------------------------------------------------------------------------------------------------------------------------------------------ %

% SUMMARY:

% Support function: Retrieves channel labels corresponding to channel indices (and the other way around). Requires a file with the montage
%					overview (see below).
%					Important note: The function does not support non-EEG (extra) channels.


% INPUT:

% montage_id	|		string											|		Which montage to use ('64' or '128').
% selection		|		array of indices OR cell of label strings		|		The channels which to look up corresponding names/indices.
% exclude		|		boolean											|		Return all channels EXCEPT those in 'selection' (default: false).


% OUTPUT:

% channels		|		array of indices OR cell of label strings		|		The corresponding names/indices of the input channel selection
%																				The output format will be the opposite of the input format.

% ------------------------------------------------------------------------------------------------------------------------------------------------ %

% MONTAGE FILE STRUCTURE:

% The montage file should be a struct with n (channels) rows and two fields; 'index' and 'label'.
% The file must be saved in *.mat format and be named such: 'channel_montage_*' where * is the number identifying the montage.

% ------------------------------------------------------------------------------------------------------------------------------------------------ %

%% Evaluate the input arguments

% Throw error if the number of arguments is less than 2, or if the 'selection' argument is neither cell nor array.
if nargin < 2 || ~iscell ( selection ) && ~ischar ( selection ) && ~isnumeric ( selection )
	error ( 'ch_channels: Error. At least 2 input arguments must be specified, and ''selection'' must be either a cell or numerical array.' );
end

% Transform character to cell.
if ischar ( selection )
	selection = { selection };
end

% Set 'exclude' to default (false) if argument isn't provided.
if nargin < 3
	exclude = false;
end

%% Function body

% Load the specified channel montage file.
load ( sprintf( '%s/channel_montage_%s', fileparts( mfilename( 'fullpath') ), montage_id ), 'montage' );

% Determine the format of the 'selection' input, and enter the appropriate branch.
switch iscell ( selection )
	case true		% Strings in cell array.
		
		channels = zeros ( 1, numel( selection ) );
		labels = { montage.label };
		for i = 1 : numel ( selection )
			channels( i ) = montage( strmatch( selection{ i }, labels ) ).index; %#ok<MATCH2>
		end
		channels = sort ( channels );
		
		if exclude
			channels_2 = 1 : length ( montage );
			channels_2( channels ) = [ ];
			channels = channels_2;
		end
		
	case false		% Indices in numerical array.
		
		if exclude
			selection_2 = 1 : length ( montage );
			selection_2( selection ) = [ ];
			selection = selection_2;
		end
		
		selection = sort ( selection );
		channels = cell ( 1, numel( selection ) );
		for i = 1 : numel ( selection )
			channels{ i } = montage( selection( i ) ).label;
		end
		
end

end