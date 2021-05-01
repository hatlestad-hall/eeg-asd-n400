function vrbstr = ch_verbose ( inpstr, prespace, postspace, indent )
%% About
%
% Name:		ch_verbose
% Version:	1.0
%
% Christoffer Hatlestad-Hall
%
%
% Date created:			18 Mar 2020
% Date last modified:	07 Apr 2020
%
% ------------------------------------------------------------------------------------------------------------------------------------------------ %
%
% SUMMARY:
%
% Support function: Takes a string and produces neat and tidy verbose output.
%
%
% INPUT:
%
% inpstr		|		string		|		Input string.
% prespace		|		integer		|		Number of spacing lines above the text.
% postspace		|		integer		|		Number of spacing lines below the text.
% indent		|		integer		|		Text indentation, in number of spaces.
%
%
%
% OUTPUT:
%
% vrbstr		|		string		|		Optional output; the verbose string as a variable.
%
% ------------------------------------------------------------------------------------------------------------------------------------------------ %

%% Evaluate the input arguments

if nargin < 1
	error ( 'ch_verbose: Error. An input string must be provided as a minimum.' );
	
elseif nargin < 2
	prespace	= 1;
	postspace	= 1;
	indent		= 0;
	
elseif nargin < 3
	postspace	= 1;
	indent		= 0;
	
elseif nargin < 4
	indent		= 0;
	
end

%% Generate the verbose string

% Generate the above-text spacing and indentation string.
if prespace == 0
	prestr = '';
	
else
	prestr = '';
	for i = 1 : prespace
		prestr = [ prestr, '\n' ]; %#ok<AGROW>
	end
	
end
if indent ~= 0
	for i = 1 : indent
		prestr = [ prestr, ' ' ]; %#ok<AGROW>
	end
end

% Generate the below-text spacing string.
if postspace == 0
	pststr = '';
	
else
	pststr = '';
	for i = 1 : postspace
		pststr = [ pststr, '\n' ]; %#ok<AGROW>
	end
	
end

% Assemble the verbose string.
vrbstr = sprintf ( '%s%s%s', prestr, inpstr, pststr );

%% Print the verbose string

fprintf ( vrbstr );

end