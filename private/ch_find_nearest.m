%% About support function
%
% Name:		ch_find_nearest
% Version:	1.0
%
% Christoffer Hatlestad-Hall
%
%
% Date created:			08 Apr 2020
% Date last modified:	08 Apr 2020
%
% ------------------------------------------------------------------------------------------------------------------------------------------------ %
%
% SUMMARY:
%
% Returns the index of array x with the value closest to y.
%
%
% INPUT:
%
% x			|		array		|		Array to search in.
% y			|		number		|		Value to search for.
%
%
% OUTPUT:
%
% index		|		integer		|		Number indexing the value nearest to y in x.
%
% ------------------------------------------------------------------------------------------------------------------------------------------------ %
function index = ch_find_nearest ( x, y )

% Find value in array x closest to value y
[ ~, index ] = min ( abs( x - y ) );

end