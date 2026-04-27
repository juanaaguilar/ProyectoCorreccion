:- module(proylcc,
	[  
		connect/4
	]).

:-use_module(library(lists)).
:-discontiguous proylcc:connect/4.
:-discontiguous proylcc:is_obstacle_cell/1.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% connect(+Grid, +NumOfColumns, +Path, -Effects)
%
% donde Effects es una lista de effect(ResultingGrid, AuxiliaryInfo) 
% donde AuxiliaryInfo es una lista de información adicional que se quiera devolver 
% para la UI (por ejemplo, los objetivos cumplidos, o qué celdas se vieron afectadas, etc).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Path es la lista de indices seleccionados por el jugador (puede tener indices repetidos)
%el metodo list_to_set elimina duplicados (convierte una lista en un conjunto)

connect(Grid, NumOfColumns, Path, [effect(NewGrid, [achieved([[Color, ColorN], [~, WaterN]])])]) :-
    % 1. Identificar el color de la jugada
    [FirstIndex|_] = Path,
    nth0(FirstIndex, Grid, FirstCell),
    strip_water(FirstCell, [Color]),

    % 2. Identificar qué se elimina y qué queda atrapado adentro
    ( is_closed_loop(Path) ->
        list_to_set(Path, LoopBoundary),
        find_inside_cells(Grid, NumOfColumns, LoopBoundary, InsideSet),
        
        get_all_of_color(Grid, Color, ExpandedPath),
        list_to_set(ExpandedPath, PathSet)
    ;
        list_to_set(Path, PathSet),
        InsideSet = [] 
    ),
    
    % 3. Procesar la grilla evaluando agua POR CADA CELDA
    length(Grid, TotalCells),
    procesar_celdas_impl(Grid, Grid, PathSet, InsideSet, NumOfColumns, TotalCells, 0, GridProcesada, 0, WaterN0, 0, ColorN),

    % 3.5 Propagar agua en cascada a celdas vacías adyacentes a agua
    propagar_agua(GridProcesada, NumOfColumns, GridConAgua),

    % Contabilizar el agua nueva generada por la propagación
    contar_agua_nueva(GridProcesada, GridConAgua, AguaPropagada),
    WaterN is WaterN0 + AguaPropagada,
    
    % 4. Aplicar la gravedad
    apply_gravity(GridConAgua, NumOfColumns, NewGrid).


% --- MÓDULO DE PROCESAMIENTO DE CELDAS ---

% procesar_celdas_impl(+OriginalGrid, +Grid, +PathSet, +InsideSet, +NumOfColumns, +TotalCells, +Index, -NewGrid, 
%                       +AccWater, -TotalWater, +AccColor, -TotalColor)
% Procesa cada celda evaluando el agua de forma individual
procesar_celdas_impl(_, [], _, _, _, _, _, [], WaterN, WaterN, ColorN, ColorN).
procesar_celdas_impl(OriginalGrid, [Cell|Rest], PathSet, InsideSet, NumOfColumns, TotalCells, Index, [NewCell|NewRest], AccW, FinalW, AccC, FinalC) :-
    ( memberchk(Index, PathSet) ->
        % 1. La celda se va a eliminar
        ( should_generate_water(OriginalGrid, Cell, Index, NumOfColumns, TotalCells) ->
            NewCell = [e, ~]
        ;
            NewCell = [e]
        ),
        calcula_agua_nueva(Cell, NewCell, IncW),
        calcula_color_eliminado(Cell, IncC),
        AccW1 is AccW + IncW,
        AccC1 is AccC + IncC
        
    ; memberchk(Index, InsideSet) ->
        % 2. Si quedó atrapada, se convierte en bomba
        determinar_celda_bomba(Cell, NewCell),
        AccW1 is AccW, AccC1 is AccC
    ;
        % 3. Si no pasa nada, se queda igual
        NewCell = Cell,
        AccW1 is AccW, AccC1 is AccC
    ),
    Index1 is Index + 1,
    procesar_celdas_impl(OriginalGrid, Rest, PathSet, InsideSet, NumOfColumns, TotalCells, Index1, NewRest, AccW1, FinalW, AccC1, FinalC).


% --- MÓDULO DE PROPAGACIÓN DE AGUA ---

% Itera propagar_agua hasta que no haya cambios (punto fijo).
% Esto resuelve cadenas de celdas eliminadas apiladas sobre el agua.
propagar_agua(Grid, NumOfColumns, PropagatedGrid) :-
    length(Grid, TotalCells),
    propagar_agua_fixpoint(Grid, NumOfColumns, TotalCells, PropagatedGrid).

propagar_agua_fixpoint(Grid, NumOfColumns, TotalCells, Result) :-
    propagar_agua_una_vez(Grid, Grid, NumOfColumns, TotalCells, 0, NewGrid),
    ( NewGrid == Grid ->
        Result = Grid   % No hubo cambios, llegamos al punto fijo
    ;
        propagar_agua_fixpoint(NewGrid, NumOfColumns, TotalCells, Result)  % Hubo cambios, otra pasada
    ).

% Una pasada de propagación: convierte [e] en [e,~] si tiene un vecino con agua
propagar_agua_una_vez(_, [], _, _, _, []).
propagar_agua_una_vez(RefGrid, [Cell|Rest], NumOfColumns, TotalCells, Index, [NewCell|NewRest]) :-
    ( Cell = [e] ->
        ( neighbor_index(Index, NumOfColumns, TotalCells, NIdx),
          nth0(NIdx, RefGrid, NCell),
          has_water(NCell)
        ->  NewCell = [e, ~]
        ;   NewCell = [e]
        )
    ;
        NewCell = Cell
    ),
    Index1 is Index + 1,
    propagar_agua_una_vez(RefGrid, Rest, NumOfColumns, TotalCells, Index1, NewRest).

% Cuenta cuántas celdas nuevas pasaron de [e] a [e,~] durante la propagación
contar_agua_nueva([], [], 0).
contar_agua_nueva([OldCell|OldRest], [NewCell|NewRest], Total) :-
    contar_agua_nueva(OldRest, NewRest, SubTotal),
    ( OldCell = [e], NewCell = [e, ~] ->
        Total is SubTotal + 1
    ;
        Total is SubTotal
    ).


% --- MÓDULO DE AGUA ---

% Verifica si una celda contiene agua (ya sea con un punto o vacía)
has_water([_, ~]).
has_water([~]).

% Verifica si un índice específico tiene agua en alguna de sus celdas adyacentes ortogonales
is_adjacent_to_water(Grid, NumOfColumns, Index) :-
    length(Grid, TotalCells),
    neighbor_index(Index, NumOfColumns, TotalCells, NeighborIndex),
    nth0(NeighborIndex, Grid, NeighborCell),
    has_water(NeighborCell).

% Determina si el camino seleccionado interactúa con el agua
path_touches_water(Grid, NumOfColumns, PathSet) :-
    member(Index, PathSet),
    (
        nth0(Index, Grid, Cell), has_water(Cell)
    ;
        is_adjacent_to_water(Grid, NumOfColumns, Index)
    ),
    !.

% should_generate_water(+OriginalGrid, +Cell, +Index, +NumOfColumns, +TotalCells)
% Determina si una celda específica debe generar agua al eliminarse.
% Solo las celdas adyacentes al agua en la grilla original generan agua directamente.
% La propagación en cascada se resuelve en propagar_agua_fixpoint.
should_generate_water(OriginalGrid, _Cell, Index, NumOfColumns, TotalCells) :-
    neighbor_index(Index, NumOfColumns, TotalCells, NeighborIndex),
    nth0(NeighborIndex, OriginalGrid, NeighborCell),
    has_water(NeighborCell),
    !.
should_generate_water(_, _, _, _, _) :- false.


% --- MÓDULO DE GRAVEDAD ---

% apply_gravity(+Grid, +NumOfColumns, -NewGrid)
% Mueve los puntos hacia abajo en cada columna y genera nuevos puntos en la parte superior.
apply_gravity(Grid, NumOfColumns, NewGrid) :-
    length(Grid, Len),
    NumRows is Len // NumOfColumns,
    columns(Grid, NumOfColumns, NumRows, Columns),
    maplist(gravity_column, Columns, GravColumns),
    rebuild_grid(NumOfColumns, NumRows, GravColumns, NewGrid).

% Genera una lista de todas las columnas de la grilla
columns(Grid, NumOfColumns, NumRows, Columns) :-
    MaxCol is NumOfColumns - 1,
    findall(Column,
            (between(0, MaxCol, ColIndex),
             column_cells(Grid, NumOfColumns, NumRows, ColIndex, Column)),
            Columns).

% Extrae la columna ColIndex de la grilla
column_cells(Grid, NumOfColumns, NumRows, ColIndex, Column) :-
    MaxRow is NumRows - 1,
    findall(Cell,
            (between(0, MaxRow, RowIndex),
             Index is RowIndex * NumOfColumns + ColIndex,
             nth0(Index, Grid, Cell)),
            Column).

% Vuelve a convertir la lista de columnas en una lista plana de filas
rebuild_grid(NumOfColumns, NumRows, Columns, Grid) :-
    MaxRow is NumRows - 1,
    MaxCol is NumOfColumns - 1,
    findall(Cell,
            (between(0, MaxRow, RowIndex),
             between(0, MaxCol, ColIndex),
             nth0(ColIndex, Columns, Column),
             nth0(RowIndex, Column, Cell)),
            Grid).

% Aplica gravedad dentro de una sola columna, respetando los obstáculos [-]
gravity_column(Column, NewColumn) :-
    include(is_point_cell, Column, Points),
    exclude(is_obstacle_cell, Column, NonObstacleCells),
    length(NonObstacleCells, Count),
    fill_gravity_cells(Points, Count, NewNonObstacleCells),
    rebuild_column(Column, NewNonObstacleCells, NewColumn).

% Genera la lista de celdas no-obstáculo con gravedad aplicada
fill_gravity_cells(Points, Count, NewCells) :-
    length(Points, NumPoints),
    NumEmpty is Count - NumPoints,
    fill_new_points(NumEmpty, NewPoints),
    append(NewPoints, Points, NewCells).

% Reconstruye la columna manteniendo los obstáculos en su posición
rebuild_column([], [], []).
rebuild_column([[-]|Rest], Points, [[-]|NewRest]) :-
    rebuild_column(Rest, Points, NewRest).
rebuild_column([OriginalCell|Rest], [Point|PointsRest], [FinalCell|NewRest]) :-
    OriginalCell \= [-],
    apply_water(OriginalCell, Point, FinalCell),
    rebuild_column(Rest, PointsRest, NewRest).


% --- MÓDULO DE IDENTIFICADORES DE CELDAS ---

is_empty_cell([e]).
is_empty_cell([e, ~]).

is_point_cell([C]) :- 
    available_colors(Colors), memberchk(C, Colors).
is_point_cell([C, ~]) :- 
    available_colors(Colors), memberchk(C, Colors).
is_point_cell([b]).
is_point_cell([b, ~]).

is_obstacle_cell([-]).

available_colors([r, y, g, c, p]).


% --- HELPERS ---

% Extrae el color base del punto, quitándole el agua si la tenía
strip_water([C, ~], [C]) :- 
    C \= '~', !.
strip_water([C], [C]).

% Decide qué formato final tendrá el punto según la celda original del tablero
apply_water(OriginalCell, Point, FinalCell) :-
    has_water(OriginalCell),
    strip_water(Point, [C]),
    FinalCell = [C, ~], !.
apply_water(_, Point, FinalCell) :-
    strip_water(Point, [C]),
    FinalCell = [C].

% Reglas para crear bombas preservando obstáculos, espacios vacíos y agua
determinar_celda_bomba(Cell, Cell) :- is_empty_cell(Cell), !.
determinar_celda_bomba([-], [-]) :- !.
determinar_celda_bomba(Cell, [b, ~]) :- has_water(Cell), !.
determinar_celda_bomba(_, [b]).


% --- MÓDULO DE LOGROS Y OBJETIVOS ---

% Calcula si se generó agua nueva: suma 1 solo si la celda original NO tenía agua y la nueva SÍ tiene
calcula_agua_nueva(OldCell, NewCell, 1) :-
    \+ has_water(OldCell),
    has_water(NewCell), !.
calcula_agua_nueva(_, _, 0).

% Calcula si se eliminó un punto válido para sumar al objetivo de colores
calcula_color_eliminado(Cell, 1) :- is_point_cell(Cell), !.
calcula_color_eliminado(_, 0).

% Genera nuevos puntos aleatorios para rellenar los espacios vacíos
fill_new_points(0, []) :- !.
fill_new_points(Count, [[Color]|Rest]) :-
    Count > 0,
    available_colors(Colors),
    random_member(Color, Colors),
    Count1 is Count - 1,
    fill_new_points(Count1, Rest).


% --- MÓDULO DE FORMAS CERRADAS ---

% Verifica si el camino forma un ciclo (cuadrado o lazo).
% La longitud mínima para un lazo en Two Dots es 4.
is_closed_loop(Path) :-
    length(Path, Len),
    Len >= 4,
    list_to_set(Path, PathSet),
    length(PathSet, SetLen),
    Len > SetLen.

% Encuentra todos los índices de la grilla que tengan un color específico
get_all_of_color(Grid, TargetColor, TargetIndices) :-
    findall(Index,
            (nth0(Index, Grid, Cell),
             is_target_color(Cell, TargetColor)),
            TargetIndices).

% Verifica si una celda contiene el color buscado (tenga agua o no)
is_target_color([C], TargetColor) :- 
    C == TargetColor.
is_target_color([C, ~], TargetColor) :- 
    C == TargetColor.


% --- MÓDULO GEOMÉTRICO Y BOMBAS ---

% Encuentra todos los índices que están estrictamente dentro de un lazo cerrado
find_inside_cells(Grid, NumOfColumns, LoopBoundary, InsideSet) :-
    length(Grid, TotalCells),
    grid_boundaries(NumOfColumns, TotalCells, Borders),
    subtract(Borders, LoopBoundary, StartNodes),
    flood_fill(StartNodes, LoopBoundary, NumOfColumns, TotalCells, [], OutsideCells),
    MaxIndex is TotalCells - 1,
    findall(I, between(0, MaxIndex, I), AllCells),
    subtract(AllCells, LoopBoundary, NonLoopCells),
    subtract(NonLoopCells, OutsideCells, InsideSet).

% Obtiene los índices que conforman los 4 bordes externos de la grilla
grid_boundaries(NumOfColumns, TotalCells, Bounds) :-
    NumRows is TotalCells // NumOfColumns,
    MaxCol is NumOfColumns - 1,
    MaxRow is NumRows - 1,
    findall(I, (
        between(0, MaxRow, R),
        between(0, MaxCol, C),
        (R =:= 0 ; R =:= MaxRow ; C =:= 0 ; C =:= MaxCol),
        I is R * NumOfColumns + C
    ), RawBounds),
    list_to_set(RawBounds, Bounds).

% Algoritmo Flood Fill (BFS) para pintar el exterior
flood_fill([], _, _, _, Visited, Visited).
flood_fill([Curr|Rest], LoopBoundary, NumOfColumns, TotalCells, Visited, Outside) :-
    findall(N, (
        neighbor_index(Curr, NumOfColumns, TotalCells, N),
        \+ memberchk(N, LoopBoundary),
        \+ memberchk(N, Visited)
    ), NeighborsRaw),
    list_to_set(NeighborsRaw, Neighbors),
    subtract(Neighbors, Rest, NewNeighbors),
    append(Rest, NewNeighbors, NewQueue),
    flood_fill(NewQueue, LoopBoundary, NumOfColumns, TotalCells, [Curr|Visited], Outside).


% --- MÓDULO DE VECINOS ---

% Retorna los índices vecinos válidos (arriba, abajo, izquierda, derecha) respetando los bordes
% Izquierda
neighbor_index(Index, NumOfColumns, _TotalCells, NeighborIndex) :-
    Index mod NumOfColumns =\= 0,
    NeighborIndex is Index - 1.
% Derecha
neighbor_index(Index, NumOfColumns, _TotalCells, NeighborIndex) :-
    (Index + 1) mod NumOfColumns =\= 0,
    NeighborIndex is Index + 1.
% Arriba
neighbor_index(Index, NumOfColumns, _TotalCells, NeighborIndex) :-
    NeighborIndex is Index - NumOfColumns,
    NeighborIndex >= 0.
% Abajo
neighbor_index(Index, NumOfColumns, TotalCells, NeighborIndex) :-
    NeighborIndex is Index + NumOfColumns,
    NeighborIndex < TotalCells.