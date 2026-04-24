:- module(proylcc,
	[  
		connect/4
	]).

:-use_module(library(lists)).
:-discontiguous proylcc:connect/4.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% connect/4 - Path cerrado (lazo)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

connect(Grid, NumOfColumns, Path, [effect(NewGrid, [achieved(Achievements)])]) :-
    es_path_cerrado(Path, NumOfColumns),
    !,
    Path = [FirstIndex|_],
    nth0(FirstIndex, Grid, FirstCell),
    color_de_celda(FirstCell, Color),
    eliminar_color(Grid, Color, 0, GridSinColor, 0, _N),
    contar_color(Grid, Color, NColor),
    interior_del_lazo(Path, NumOfColumns, Grid, Interior),
    expandir_agua_interior(GridSinColor, Interior, GridConAgua, 0, NAgua),
    apply_gravity(GridConAgua, NumOfColumns, GridGravity),
    marcar_agua(GridGravity, NumOfColumns, NewGrid, 0, NMarcado),
    NTotal is NAgua + NMarcado,
    ( NTotal > 0 ->
        Achievements = [[~, NTotal], [Color, NColor]]
    ;
        Achievements = [[Color, NColor]]
    ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% connect/4 - Path normal
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

connect(Grid, NumOfColumns, Path, [effect(NewGrid, [achieved(Achievements)])]) :-
    list_to_set(Path, PathSet),
    eliminar_camino(Grid, PathSet, 0, GridSinCamino, 0, _N),
    contar_por_color(Grid, PathSet, ColorCounts),
    apply_gravity(GridSinCamino, NumOfColumns, GridGravity),
    marcar_agua(GridGravity, NumOfColumns, NewGrid, 0, NAgua),
    ( NAgua > 0 ->
        Achievements = [[~, NAgua] | ColorCounts]
    ;
        Achievements = ColorCounts
    ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% es_path_cerrado(+Path, +NumOfColumns)
% El path es cerrado si el primero y el último índice son iguales y tiene más de 1 elemento.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

es_path_cerrado(Path, _NumOfColumns) :-
    length(Path, Len),
    Len > 2,
    last(Path, Last),
    Path = [First|_],
    First =:= Last.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% color_de_celda(+Cell, -Color)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

color_de_celda([Color], Color) :-
    Color \= e, Color \= (-).
color_de_celda([Color, ~], Color).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% eliminar_color(+Grid, +Color, +Index, -NewGrid, +Acc, -N)
% Elimina todos los puntos del color dado.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

eliminar_color([], _, _, [], N, N).
eliminar_color([Cell|Rest], Color, Index, [NewCell|NewRest], Acc, N) :-
    ( celda_tiene_color(Cell, Color) ->
        NewCell = [e],
        Acc1 is Acc + 1
    ;
        NewCell = Cell,
        Acc1 is Acc
    ),
    Index1 is Index + 1,
    eliminar_color(Rest, Color, Index1, NewRest, Acc1, N).

celda_tiene_color([Color], Color).
celda_tiene_color([Color, ~], Color).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% contar_color(+Grid, +Color, -N)
% Cuenta cuántas celdas tienen ese color.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

contar_color(Grid, Color, N) :-
    include(celda_tiene_color_wrap(Color), Grid, Matching),
    length(Matching, N).

celda_tiene_color_wrap(Color, Cell) :- celda_tiene_color(Cell, Color).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% interior_del_lazo(+Path, +NumOfColumns, +Grid, -Interior)
% Devuelve los índices de las celdas dentro del lazo que tienen un punto.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

interior_del_lazo(Path, NumOfColumns, Grid, Interior) :-
    list_to_set(Path, PathSet),
    length(Grid, Len),
    NumRows is Len // NumOfColumns,
    findall(Index,
        (   between(0, Len, Index),
            \+ memberchk(Index, PathSet),
            nth0(Index, Grid, Cell),
            es_punto_sin_agua(Cell),
            punto_interior(Index, PathSet, NumOfColumns, NumRows)
        ),
        Interior).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% punto_interior(+Index, +PathSet, +NumOfColumns, +NumRows)
% Ray casting: un punto es interior si un rayo horizontal cruza el borde
% del lazo un número impar de veces.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

punto_interior(Index, PathSet, NumOfColumns, NumRows) :-
    Fila is Index // NumOfColumns,
    Col is Index mod NumOfColumns,
    contar_cruces(Fila, 0, Col, PathSet, NumOfColumns, NumRows, Cruces),
    1 is Cruces mod 2.

contar_cruces(_, C, 0, _, _, _, C) :- !.
contar_cruces(Fila, Acc, Col, PathSet, NumOfColumns, NumRows, Cruces) :-
    Col > 0,
    ColAnterior is Col - 1,
    Index is Fila * NumOfColumns + ColAnterior,
    ( memberchk(Index, PathSet) ->
        Acc1 is Acc + 1
    ;
        Acc1 is Acc
    ),
    contar_cruces(Fila, Acc1, ColAnterior, PathSet, NumOfColumns, NumRows, Cruces).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% expandir_agua_interior(+Grid, +Interior, -NewGrid, +Acc, -NAgua)
% Convierte los puntos interiores en [Color, ~].
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

expandir_agua_interior(Grid, [], Grid, N, N).
expandir_agua_interior(Grid, [Index|Rest], NewGrid, Acc, N) :-
    nth0(Index, Grid, Cell),
    Cell = [Color],
    reemplazar(Grid, Index, [Color, ~], Grid1),
    Acc1 is Acc + 1,
    expandir_agua_interior(Grid1, Rest, NewGrid, Acc1, N).
expandir_agua_interior(Grid, [_|Rest], NewGrid, Acc, N) :-
    expandir_agua_interior(Grid, Rest, NewGrid, Acc, N).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% eliminar_camino(+Grid, +PathSet, +Index, -NewGrid, +Acc, -N)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% contar_por_color(+Grid, +PathSet, -ColorCounts)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

contar_por_color(Grid, PathSet, ColorCounts) :-
    findall(Color,
        (member(Index, PathSet),
         nth0(Index, Grid, Cell),
         color_de_celda(Cell, Color)),
        Colors),
    contar_colores(Colors, ColorCounts).

contar_colores([], []).
contar_colores([Color|Rest], [[Color, Count]|Counts]) :-
    include(=(Color), Rest, Same),
    exclude(=(Color), Rest, Others),
    length(Same, SameLen),
    Count is SameLen + 1,
    contar_colores(Others, Counts).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% apply_gravity
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

apply_gravity(Grid, NumOfColumns, NewGrid) :-
    length(Grid, Len),
    NumRows is Len // NumOfColumns,
    columns(Grid, NumOfColumns, NumRows, Columns),
    maplist(gravity_column, Columns, GravColumns),
    rebuild_grid(NumOfColumns, NumRows, GravColumns, NewGrid).

columns(Grid, NumOfColumns, NumRows, Columns) :-
    MaxCol is NumOfColumns - 1,
    findall(Column,
            (between(0, MaxCol, ColIndex),
             column_cells(Grid, NumOfColumns, NumRows, ColIndex, Column)),
            Columns).

column_cells(Grid, NumOfColumns, NumRows, ColIndex, Column) :-
    MaxRow is NumRows - 1,
    findall(Cell,
            (between(0, MaxRow, RowIndex),
             Index is RowIndex * NumOfColumns + ColIndex,
             nth0(Index, Grid, Cell)),
            Column).

rebuild_grid(NumOfColumns, NumRows, Columns, Grid) :-
    MaxRow is NumRows - 1,
    MaxCol is NumOfColumns - 1,
    findall(Cell,
            (between(0, MaxRow, RowIndex),
             between(0, MaxCol, ColIndex),
             nth0(ColIndex, Columns, Column),
             nth0(RowIndex, Column, Cell)),
            Grid).

gravity_column(Column, NewColumn) :-
    split_column_by_obstacle(Column, Groups),
    maplist(process_column_group, Groups, ProcessedGroups),
    append(ProcessedGroups, NewColumn).

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

process_column_group([[-]], [[-]]).
process_column_group(Segment, NewCells) :-
    Segment \= [[-]],
    include(is_point_cell, Segment, Points),
    length(Segment, Len),
    length(Points, NumPoints),
    NumEmpty is Len - NumPoints,
    fill_new_points(NumEmpty, NewPoints),
    append(NewPoints, Points, NewCells).

is_point_cell(Cell) :-
    Cell \= [-],
    Cell \= [e].

available_colors([r, y, g, c, p]).

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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% marcar_agua
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

marcar_agua(Grid, NumOfColumns, NewGrid, Acc, NAgua) :-
    length(Grid, Len),
    NumRows is Len // NumOfColumns,
    marcar_agua_indices(Grid, Grid, 0, NumOfColumns, NumRows, NewGrid, Acc, NAgua).

marcar_agua_indices(_, [], _, _, _, [], N, N).
marcar_agua_indices(GridOriginal, [Cell|Rest], Index, NumOfColumns, NumRows, [NewCell|NewRest], Acc, N) :-
    ( es_punto_sin_agua(Cell),
      tiene_agua_adyacente(Index, GridOriginal, NumOfColumns, NumRows) ->
        Cell = [Color],
        NewCell = [Color, ~],
        Acc1 is Acc + 1
    ;
        NewCell = Cell,
        Acc1 is Acc
    ),
    Index1 is Index + 1,
    marcar_agua_indices(GridOriginal, Rest, Index1, NumOfColumns, NumRows, NewRest, Acc1, N).

es_punto_sin_agua([Color]) :-
    Color \= e,
    Color \= (-).

tiene_agua_adyacente(Index, Grid, NumOfColumns, NumRows) :-
    vecinos(Index, NumOfColumns, NumRows, Vecinos),
    member(V, Vecinos),
    nth0(V, Grid, Celda),
    tiene_agua(Celda), !.

tiene_agua([~]).
tiene_agua([_, ~]).

vecinos(Index, NumOfColumns, NumRows, Vecinos) :-
    Fila is Index // NumOfColumns,
    Col is Index mod NumOfColumns,
    MaxFila is NumRows - 1,
    MaxCol is NumOfColumns - 1,
    findall(V, (
        ( V is Index - NumOfColumns, Fila > 0 )
        ;
        ( V is Index + NumOfColumns, Fila < MaxFila )
        ;
        ( V is Index - 1, Col > 0 )
        ;
        ( V is Index + 1, Col < MaxCol )
    ), Vecinos).

reemplazar([_|T], 0, NewCell, [NewCell|T]) :- !.
reemplazar([H|T], Index, NewCell, [H|T1]) :-
    Index > 0,
    Index1 is Index - 1,
    reemplazar(T, Index1, NewCell, T1).