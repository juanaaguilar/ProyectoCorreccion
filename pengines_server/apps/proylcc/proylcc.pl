:- module(proylcc,
	[  
		connect/4
	]).

:-use_module(library(lists)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% connect(+Grid, +NumOfColumns, +Path, -Effects)
%
% donde Effects es una lista de effect(ResultingGrid, AuxiliaryInfo) 
% donde AuxiliaryInfo es una lista de información adicional que se quiera devolver 
% para la UI (por ejemplo, los objetivos cumplidos, o qué celdas se vieron afectadas, etc).
connect(Grid, _NumOfColumns, Path, [effect(NewGrid, [achieved([[~, N]])])]) :-
    list_to_set(Path, PathSet),
    replace_with_water(Grid, PathSet, 0, NewGrid, 0, N).

writeln('Grilla inicial cargada. ¡Listo para jugar!').

replace_with_water([], _, _, [], N, N).
replace_with_water([Cell|Rest], PathSet, Index, [NewCell|NewRest], Acc, N) :-
    ( memberchk(Index, PathSet) ->
        NewCell = [-],
        Acc1 is Acc + 1
    ;
        NewCell = Cell,
        Acc1 is Acc
    ),
    Index1 is Index + 1,
    replace_with_water(Rest, PathSet, Index1, NewRest, Acc1, N).


connect(
	[
		[-], [r], [c], [p], [-], [-], [-], [-],	
		[c], [y], [g], [p], [r], [-], [-], [-],	
		[r], [r], [g], [y], [r], [g], [-], [-],	
		[y], [c], [-], [y], [c], [g], [g], [-],	
		[y, ~], [c, ~], [-], [g], [c, ~], [y, ~], [c, ~], [c],	
		[c, ~], [c, ~], [-], [g, ~], [c, ~], [y, ~], [c, ~], [-],	
		[c, ~], [y, ~], [g, ~], [g, ~], [c, ~], [c, ~], [-], [-],	
		[c, ~], [y, ~], [y, ~], [y, ~], [y, ~], [-], [-], [-],	
		[-], [y, ~], [y, ~], [y], [-], [-], [-], [-]
	], 8, [21, 29, 30],
	[
		effect([
			[-], [r], [c], [p], [-], [-], [-], [-],	
			[c], [y], [g], [p], [r], [-], [-], [-],	
			[r], [r], [g], [y], [r], [~], [-], [-],	
			[y], [c], [-], [y], [c], [~], [~], [-],	
			[y, ~], [c, ~], [-], [g], [c, ~], [y, ~], [c, ~], [c],	
			[c, ~], [c, ~], [-], [g, ~], [c, ~], [y, ~], [c, ~], [-],	
			[c, ~], [y, ~], [g, ~], [g, ~], [c, ~], [c, ~], [-], [-],	
			[c, ~], [y, ~], [y, ~], [y, ~], [y, ~], [-], [-], [-],	
			[-], [y, ~], [y, ~], [y], [-], [-], [-], [-]
		], [			
			achieved([[g, 3], [~, 3]])
			% o dejar libre qué info auxiliar para la UI se devuelve.			
		]),
		effect([
			[-], [r], [c], [p], [-], [-], [-], [-],	
			[c], [y], [g], [p], [r], [-], [-], [-],	
			[r], [r], [g], [y], [r], [r, ~], [-], [-],	
			[y], [c], [-], [y], [c], [c, ~], [r, ~], [-],	
			[y, ~], [c, ~], [-], [g], [c, ~], [y, ~], [c, ~], [c],	
			[c, ~], [c, ~], [-], [g, ~], [c, ~], [y, ~], [c, ~], [-],	
			[c, ~], [y, ~], [g, ~], [g, ~], [c, ~], [c, ~], [-], [-],	
			[c, ~], [y, ~], [y, ~], [y, ~], [y, ~], [-], [-], [-],	
			[-], [y, ~], [y, ~], [y], [-], [-], [-], [-]
		], [gravity])
	]
).

connect(
	[
		[-], [r], [c], [p], [-], [-], [-], [-],	
		[c], [y], [g], [p], [r], [-], [-], [-],	
		[r], [r], [g], [y], [r], [g], [-], [-],	
		[y], [c], [-], [y], [c], [g], [g], [-],	
		[y, ~], [c, ~], [-], [g], [c, ~], [y, ~], [c, ~], [c],	
		[c, ~], [c, ~], [-], [g, ~], [c, ~], [y, ~], [c, ~], [-],	
		[c, ~], [y, ~], [g, ~], [g, ~], [c, ~], [c, ~], [-], [-],	
		[c, ~], [y, ~], [y, ~], [y, ~], [y, ~], [-], [-], [-],	
		[-], [y, ~], [y, ~], [y], [-], [-], [-], [-]
	], 8, [57, 58, 66, 65, 57],
	[
		effect([
			[-], [r], [c], [p], [-], [-], [-], [-],	
			[c], [], [g], [p], [r], [-], [-], [-],	
			[r], [r], [g], [], [r], [g], [-], [-],	
			[~], [c], [-], [], [c], [g], [g], [-],	
			[~], [c, ~], [-], [g], [c, ~], [~], [c, ~], [c],	
			[c, ~], [c, ~], [-], [g, ~], [c, ~], [~], [c, ~], [-],	
			[c, ~], [~], [g, ~], [g, ~], [c, ~], [c, ~], [-], [-],	
			[c, ~], [~], [~], [~], [~], [-], [-], [-],	
			[-], [~], [~], [~], [-], [-], [-], [-]
		], [			
			achieved([[y, 15], [~, 2]])			
		]),		
		effect([
			[-], [r], [p], [c], [-], [-], [-], [-],	
			[g], [g], [p], [c], [p], [-], [-], [-],	
			[g], [g], [g], [r], [r], [r], [-], [-],	
			[c, ~], [p], [-], [r], [r], [y], [g], [-],	
			[r, ~], [r, ~], [-], [p], [c, ~], [g, ~], [c, ~], [c],	
			[c, ~], [r, ~], [-], [p, ~], [c, ~], [g, ~], [c, ~], [-],	
			[c, ~], [c,~], [c, ~], [g, ~], [c, ~], [c, ~], [-], [-],	
			[c, ~], [c,~], [g,~], [g, ~], [c, ~], [-], [-], [-],	
			[-], [c,~], [g, ~], [g, ~], [-], [-], [-], [-]
		], [gravity])
	]
).