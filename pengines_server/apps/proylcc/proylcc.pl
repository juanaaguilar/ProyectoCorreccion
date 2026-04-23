:- module(proylcc,
	[  
		connect/4
	]).

:-use_module(library(lists)).
:-discontiguous proylcc:connect/4.
%	NOTA: Tenemos que hacer que los que caen debajo del obstaculo sean los mismos q estaban arriba
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% connect(+Grid, +NumOfColumns, +Path, -Effects)
%
% donde Effects es una lista de effect(ResultingGrid, AuxiliaryInfo) 
% donde AuxiliaryInfo es una lista de información adicional que se quiera devolver 
% para la UI (por ejemplo, los objetivos cumplidos, o qué celdas se vieron afectadas, etc).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Parámetros
%Grid / [Cell|Rest]: grilla original como lista plana de celdas.
%PathSet: conjunto de índices que deben convertirse en agua.
%Index: índice actual de la celda que se está procesando.
%[NewCell|NewRest]: lista resultante con los cambios aplicados.
%Acc: contador acumulado de celdas reemplazadas hasta el momento.
%N: resultado final del contador cuando termina.
%Path es la lista de indices seleccionados por el jugador (puede tener indices repetidos)
%el metodo list_to_set elimina duplicados (convierte una lista en un conjunto)

connect(Grid, NumOfColumns, Path, [effect(NewGrid, [achieved([[~, N]])])]) :-
    list_to_set(Path, PathSet),
    eliminar_camino(Grid, PathSet, 0, GridSinCamino, 0, N),
    apply_gravity(GridSinCamino, NumOfColumns, NewGrid).

writeln('Grilla inicial cargada. ¡Listo para jugar!').

%Cell: primera celda de la lista original 
%Rest: resto de la lista original
%NewGrid: lista resultante con los cambios aplicados
%el método memberchk verifica si Index está en PathSet.

eliminar_camino([], _, _, [], N, N).
eliminar_camino([Cell|Rest], PathSet, Index, [NewCell|NewRest], Acc, N) :-
    ( memberchk(Index, PathSet) ->
        NewCell = [e],
        Acc1 is Acc + 1
    ;
        NewCell = Cell,
        Acc1 is Acc
    ),
    Index1 is Index + 1,
    eliminar_camino(Rest, PathSet, Index1, NewRest, Acc1, N).

% apply_gravity(+Grid, +NumOfColumns, -NewGrid)
% Mueve los puntos hacia abajo en cada columna y genera nuevos puntos en la parte superior.
apply_gravity(Grid, NumOfColumns, NewGrid) :-
    length(Grid, Len), %len guarda la cant total de celdas de la grilla
    NumRows is Len // NumOfColumns, %numrows es la cantidad de filas
    columns(Grid, NumOfColumns, NumRows, Columns),
    maplist(gravity_column, Columns, GravColumns), %aplica grvity_column a cada columna, GravColumns guarda las columnas procesadas
    rebuild_grid(NumOfColumns, NumRows, GravColumns, NewGrid). %reconstruye la grilla NewGrid a partir de las columans procesadas

%genera una lista de todas las columnas de la grilla (cada columna es una lista de celdas)
columns(Grid, NumOfColumns, NumRows, Columns) :-
    MaxCol is NumOfColumns - 1, %MaxCol es el indice de la ultima columna
    findall(Column,
            (between(0, MaxCol, ColIndex),
             column_cells(Grid, NumOfColumns, NumRows, ColIndex, Column)),
            Columns).


%extrae la columna ColIndex de la grilla
%devuelve Column (lista de celdas en esa columna)
%Index convierte la coordenada (fila,columna) a posicion en la lista plana. 
column_cells(Grid, NumOfColumns, NumRows, ColIndex, Column) :-
    MaxRow is NumRows - 1,
    findall(Cell,
            (between(0, MaxRow, RowIndex),
             Index is RowIndex * NumOfColumns + ColIndex,
             nth0(Index, Grid, Cell)),
            Column).
%vuelve a convertir la lista de columnas en una lista plana de filas.
rebuild_grid(NumOfColumns, NumRows, Columns, Grid) :-
    MaxRow is NumRows - 1,
    MaxCol is NumOfColumns - 1,
    findall(Cell,
            (between(0, MaxRow, RowIndex),
             between(0, MaxCol, ColIndex),
             nth0(ColIndex, Columns, Column),
             nth0(RowIndex, Column, Cell)),
            Grid).

%aplica gravedad dentro de una sola columna, respetando los obstaculos [-]
gravity_column(Column, NewColumn) :-
    split_column_by_obstacle(Column, Groups),
    maplist(process_column_group, Groups, ProcessedGroups),
    append(ProcessedGroups, NewColumn).

%divide la columna en segmentos separados por obstaculos [-]
split_column_by_obstacle([], []).
split_column_by_obstacle([[-]|Rest], [[[-]]|Groups]) :-
    split_column_by_obstacle(Rest, Groups).
split_column_by_obstacle(Column, [Segment|Groups]) :-
    take_until_obstacle(Column, Segment, Remaining),
    Segment \= [],
    split_column_by_obstacle(Remaining, Groups).

take_until_obstacle([], [], []).
take_until_obstacle([[-]|Rest], [], [[-]|Rest]).
take_until_obstacle([Cell|Rest], [Cell|Segment], Remaining) :-
    Cell \= [-],
    take_until_obstacle(Rest, Segment, Remaining).

%procesa un segmento que no contiene obstaculos
process_column_group([[-]], [[-]]).
process_column_group(Segment, NewCells) :-
    Segment \= [[-]],
    include(is_point_cell, Segment, Points),
    length(Segment, Len),
    length(Points, NumPoints),
    NumEmpty is Len - NumPoints,
    fill_new_points(NumEmpty, NewPoints),
    append(NewPoints, Points, NewCells).

is_empty_cell([e]).
%el método is_point_cell verifica si la celda contiene un punto.
is_point_cell(Cell) :-
    Cell \= [-],
    Cell \= [e].

is_obstacle_cell([-]).

available_colors([r, y, g, c, p]).

%Count: numero de huecos a rellenar
fill_new_points(0, []) :- !.
fill_new_points(Count, NewPoints) :-
    Count > 0,
    available_colors(Colors),
    fill_new_points(Count, Colors, 0, NewPoints).

fill_new_points(0, _, _, []) :- !.
fill_new_points(Count, Colors, Index, [[Color]|Rest]) :-
    Count > 0,
    length(Colors, Len),
    J is Index mod Len,
    nth0(J, Colors, Color),
    Count1 is Count - 1,
    Index1 is Index + 1,
    fill_new_points(Count1, Colors, Index1, Rest).





