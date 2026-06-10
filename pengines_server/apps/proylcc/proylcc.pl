:- module(proylcc,
	[  
		connect/4
	]).

:-use_module(library(lists)).
:-discontiguous proylcc:connect/4.
:-discontiguous proylcc:is_obstacle_cell/1.
:- discontiguous proylcc:neighbor_9_index/4.
:- use_module(library(random)).

%No borrar: %%%%%%%%%%%%%

%NOTA GRAFICA: Acomodar color de los botones "Deshacer" y "Rehacer" para que no se póngan en gris cuando pones el mouse sobre ellosd

%FUNCIONALIDADES A IMPLEMENTAR (OPCIONALES): 
% Agregar mas niveles 
% Agregar puntos "obstaculo" grises (Nesting dots): estos cambian de tamaño cuando explotas puntos
%al lado, y si explotas 3 puntos se convierten en bombas. Se pueden poner como objetivos
%Implementar reaccion en cadena de las bombas, si explota una al lado, las demas deben explotar (LISTO)


%REFACTOREO DE CÓDIGO: 
% NOTA: Agrupar los predicados segun la funcionalidad (todos los de agua juntos, todos los de cuadrados juntos, etc)
% NOTA: BORRAR COMENTARIOS (solo los innecesarios, no borrar los q explican que hace cada cosa), unificar nombres.

%TESTEO:
%NOTA: Probar casos límite (poner movimientos en 0, arrancar con 0 objetivos, todos los casos límite que podamos probar desde el init)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% connect(+Grid, +NumOfColumns, +Path, -Effects)
%
% donde Effects es una lista de effect(ResultingGrid, AuxiliaryInfo) 
% donde AuxiliaryInfo es una lista de información adicional que se quiera devolver 
% para la UI (por ejemplo, los objetivos cumplidos, o qué celdas se vieron afectadas, etc).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Path es la lista de indices seleccionados por el jugador (puede tener indices repetidos)
%el metodo list_to_set elimina duplicados (convierte una lista en un conjunto)
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

% ==============================================================================
% 1. PUNTO DE ENTRADA PRINCIPAL
% ==============================================================================
% connect(+Grid, +NumOfColumns, +Path, -Effects)
% Refinado para incluir detonación de bombas antes de la gravedad.
% connect(+Grid, +NumOfColumns, +Path, -Effects)
% Se añade explosions(UniqueBombs, ExplosionSet) a la respuesta para la UI.
% Ejecución en DOS fases para permitir que las bombas caigan antes de explotar.
% connect(+Grid, +NumOfColumns, +Path, -Effects)
connect(Grid, NumOfColumns, Path, Effects) :-
    % 1. Identificar color y lazo
    [FirstIndex|_] = Path,
    nth0(FirstIndex, Grid, FirstCell),
    strip_water(FirstCell, [Color]),

    ( is_closed_loop(Path) ->
        list_to_set(Path, LoopBoundary),
        find_inside_cells(Grid, NumOfColumns, LoopBoundary, InsideSet),
        get_all_of_color(Grid, Color, ExpandedPath),
        list_to_set(ExpandedPath, PathSet)
    ;
        list_to_set(Path, PathSet),
        InsideSet = [] 
    ),
    
    length(Grid, TotalCells),
    findall(Idx, (member(Idx, PathSet), nth0(Idx, Grid, Cell), is_bomb_cell(Cell)), PathBombs),
    % Atrapamos los Nesting Dots de nivel 1 que van a recibir daño y convertirse en bombas
    append(InsideSet, PathSet, RemovedInF1),
    findall(Idx, (
        nth0(Idx, Grid, Cell), 
        is_n1_dot(Cell), 
        (memberchk(Idx, RemovedInF1) ; is_adjacent_to_cleared(Idx, NumOfColumns, TotalCells, RemovedInF1))
    ), N1BombsToExplode),
    
    % Todas las bombas que DEBEN explotar en este turno
    append(InsideSet, PathBombs, TempBombs),
    append(TempBombs, N1BombsToExplode, AllBombsToExplode),
    list_to_set(AllBombsToExplode, UniqueBombsToActivate),
    
    ( UniqueBombsToActivate = [] ->
        % --- CASO A: SIN BOMBAS ---
        procesar_celdas_impl(Grid, Grid, PathSet, [], NumOfColumns, TotalCells, 0, GridProcesada, 0, WaterN0, 0, ColorN),
        propagar_agua(GridProcesada, NumOfColumns, GridConAgua),
        contar_agua_nueva(GridProcesada, GridConAgua, AguaPropagada),
        WaterN is WaterN0 + AguaPropagada,
        
        apply_gravity(GridConAgua, NumOfColumns, RawNewGrid),
        
        % Verificamos si hay movimientos y mezclamos si es necesario
        ensure_valid_moves(RawNewGrid, NumOfColumns, NewGrid, WasShuffled),
        BaseEffect = effect(RawNewGrid, [achieved([[Color, ColorN], [~, WaterN]])]),
        
        ( WasShuffled == true -> 
            Effects = [BaseEffect, effect(NewGrid, [shuffled])]
        ; 
            Effects = [BaseEffect]
        )
        
    ;
       % --- CASO B: CON BOMBAS ---
        subtract(PathSet, PathBombs, NormalPathSet),
        procesar_celdas_fase1(Grid, Grid, NormalPathSet, UniqueBombsToActivate, NumOfColumns, TotalCells, 0, GridF1, 0, Water1, 0, Color1),
        propagar_agua(GridF1, NumOfColumns, GridAgua1),
        contar_agua_nueva(GridF1, GridAgua1, AguaProp1),
        WaterTotal1 is Water1 + AguaProp1,
        
        apply_gravity(GridAgua1, NumOfColumns, IntermediateGridRaw),
        get_active_bombs(IntermediateGridRaw, ActiveBombIndices),
        normalize_grid(IntermediateGridRaw, IntermediateGrid),
        
        % Guardamos el fotograma 1 (La primera jugada, las bombas caen a su lugar)
        BaseEffect = effect(IntermediateGrid, [achieved([[Color, Color1], [~, WaterTotal1]])]),
        
        % Invocamos el bucle mágico de cascada que devolverá el resto de los fotogramas
        detonar_cascada(IntermediateGrid, ActiveBombIndices, NumOfColumns, TotalCells, Color, WaterTotal1, Color1, CascadeEffects),
        
        Effects = [BaseEffect | CascadeEffects]
    ).

% ==============================================================================
% 2. MÓDULO DE PROCESAMIENTO DE CELDAS
% ==============================================================================

procesar_celdas_impl(_, [], _, _, _, _, _, [], WaterN, WaterN, ColorN, ColorN).
procesar_celdas_impl(OriginalGrid, [Cell|Rest], CellsToClear, InsideSet, NumOfColumns, TotalCells, Index, [NewCell|NewRest], AccW, FinalW, AccC, FinalC) :-
    ( is_nesting_dot(Cell), (memberchk(Index, CellsToClear) ; is_adjacent_to_cleared(Index, NumOfColumns, TotalCells, CellsToClear)) ->
        % Si es un obstáculo gris y está en la explosión o al lado, se achica
        damage_nesting_dot(Cell, NewCell),
        AccW1 is AccW, AccC1 is AccC
    ; memberchk(Index, CellsToClear) -> 
        ( should_generate_water(OriginalGrid, Cell, Index, NumOfColumns, TotalCells) ->
            NewCell = [e, ~]
        ;
            NewCell = [e]
        ),
        calcula_agua_nueva(Cell, NewCell, IncW),
        calcula_color_eliminado(Cell, IncC),
        AccW1 is AccW + IncW, AccC1 is AccC + IncC
    ; memberchk(Index, InsideSet) ->
        determinar_celda_bomba(Cell, NewCell),
        AccW1 is AccW, AccC1 is AccC
    ;
        NewCell = Cell,
        AccW1 is AccW, AccC1 is AccC
    ),
    Index1 is Index + 1,
    procesar_celdas_impl(OriginalGrid, Rest, CellsToClear, InsideSet, NumOfColumns, TotalCells, Index1, NewRest, AccW1, FinalW, AccC1, FinalC).

procesar_celdas_fase1(_, [], _, _, _, _, _, [], WaterN, WaterN, ColorN, ColorN).
procesar_celdas_fase1(OriginalGrid, [Cell|Rest], NormalPathSet, ActiveBombs, NumOfColumns, TotalCells, Index, [NewCell|NewRest], AccW, FinalW, AccC, FinalC) :-
    ( is_nesting_dot(Cell), (memberchk(Index, NormalPathSet) ; is_adjacent_to_cleared(Index, NumOfColumns, TotalCells, NormalPathSet)) ->
        % APLICAMOS EL DAÑO ESPECIAL DE FASE 1
        damage_nesting_dot_fase1(Cell, NewCell),
        AccW1 is AccW, AccC1 is AccC
    ; memberchk(Index, NormalPathSet) ->
        ( should_generate_water(OriginalGrid, Cell, Index, NumOfColumns, TotalCells) ->
            NewCell = [e, ~]
        ;
            NewCell = [e]
        ),
        calcula_agua_nueva(Cell, NewCell, IncW),
        calcula_color_eliminado(Cell, IncC),
        AccW1 is AccW + IncW, AccC1 is AccC + IncC
        
    ; memberchk(Index, ActiveBombs) ->
        determinar_bomba_activa(Cell, NewCell),
        AccW1 is AccW, AccC1 is AccC
    ;
        NewCell = Cell,
        AccW1 is AccW, AccC1 is AccC
    ),
    Index1 is Index + 1,
    procesar_celdas_fase1(OriginalGrid, Rest, NormalPathSet, ActiveBombs, NumOfColumns, TotalCells, Index1, NewRest, AccW1, FinalW, AccC1, FinalC).
% ==============================================================================
% 3. MÓDULO DE GRAVEDAD
% ==============================================================================

apply_gravity(Grid, NumOfColumns, NewGrid) :-
    length(Grid, Len),
    NumRows is Len // NumOfColumns,
    columns(Grid, NumOfColumns, NumRows, Columns),
    maplist(gravity_column, Columns, GravColumns),
    rebuild_grid(NumOfColumns, NumRows, GravColumns, NewGrid).

columns(Grid, NumOfColumns, NumRows, Columns) :-
    MaxCol is NumOfColumns - 1,
    findall(Column, (between(0, MaxCol, ColIndex), column_cells(Grid, NumOfColumns, NumRows, ColIndex, Column)), Columns).

column_cells(Grid, NumOfColumns, NumRows, ColIndex, Column) :-
    MaxRow is NumRows - 1,
    findall(Cell, (between(0, MaxRow, RowIndex), Index is RowIndex * NumOfColumns + ColIndex, nth0(Index, Grid, Cell)), Column).

rebuild_grid(NumOfColumns, NumRows, Columns, Grid) :-
    MaxRow is NumRows - 1,
    MaxCol is NumOfColumns - 1,
    findall(Cell, (between(0, MaxRow, RowIndex), between(0, MaxCol, ColIndex), nth0(ColIndex, Columns, Column), nth0(RowIndex, Column, Cell)), Grid).

gravity_column(Column, NewColumn) :-
    include(is_point_cell, Column, Points),
    exclude(is_obstacle_cell, Column, NonObstacleCells),
    length(NonObstacleCells, Count),
    fill_gravity_cells(Points, Count, NewNonObstacleCells),
    rebuild_column(Column, NewNonObstacleCells, NewColumn).

fill_gravity_cells(Points, Count, NewCells) :-
    length(Points, NumPoints),
    NumEmpty is Count - NumPoints,
    fill_new_points(NumEmpty, NewPoints),
    append(NewPoints, Points, NewCells).

rebuild_column([], [], []).
rebuild_column([[-]|Rest], Points, [[-]|NewRest]) :- rebuild_column(Rest, Points, NewRest).
rebuild_column([OriginalCell|Rest], [Point|PointsRest], [FinalCell|NewRest]) :-
    OriginalCell \= [-],
    apply_water(OriginalCell, Point, FinalCell),
    rebuild_column(Rest, PointsRest, NewRest).


% ==============================================================================
% 4. MÓDULO DE AGUA Y PROPAGACIÓN
% ==============================================================================

propagar_agua(Grid, NumOfColumns, PropagatedGrid) :-
    length(Grid, TotalCells),
    propagar_agua_fixpoint(Grid, NumOfColumns, TotalCells, PropagatedGrid).

propagar_agua_fixpoint(Grid, NumOfColumns, TotalCells, Result) :-
    propagar_agua_una_vez(Grid, Grid, NumOfColumns, TotalCells, 0, NewGrid),
    ( NewGrid == Grid -> Result = Grid ; propagar_agua_fixpoint(NewGrid, NumOfColumns, TotalCells, Result) ).

propagar_agua_una_vez(_, [], _, _, _, []).
propagar_agua_una_vez(RefGrid, [Cell|Rest], NumOfColumns, TotalCells, Index, [NewCell|NewRest]) :-
    ( Cell = [e] ->
        ( neighbor_index(Index, NumOfColumns, TotalCells, NIdx), nth0(NIdx, RefGrid, NCell), has_water(NCell)
        -> NewCell = [e, ~] ; NewCell = [e] )
    ; NewCell = Cell ),
    Index1 is Index + 1,
    propagar_agua_una_vez(RefGrid, Rest, NumOfColumns, TotalCells, Index1, NewRest).

has_water([_, ~]).
has_water([~]).

is_adjacent_to_water(Grid, NumOfColumns, Index) :-
    length(Grid, TotalCells),
    neighbor_index(Index, NumOfColumns, TotalCells, NeighborIndex),
    nth0(NeighborIndex, Grid, NeighborCell),
    has_water(NeighborCell).

path_touches_water(Grid, NumOfColumns, PathSet) :-
    member(Index, PathSet),
    ( nth0(Index, Grid, Cell), has_water(Cell) ; is_adjacent_to_water(Grid, NumOfColumns, Index) ), !.

should_generate_water(OriginalGrid, _Cell, Index, NumOfColumns, TotalCells) :-
    neighbor_index(Index, NumOfColumns, TotalCells, NeighborIndex),
    nth0(NeighborIndex, OriginalGrid, NeighborCell), has_water(NeighborCell), !.
should_generate_water(_, _, _, _, _) :- false.


% ==============================================================================
% 5. MÓDULO GEOMÉTRICO (LAZOS Y VECINOS)
% ==============================================================================

is_closed_loop(Path) :-
    length(Path, Len), Len >= 4,
    list_to_set(Path, PathSet), length(PathSet, SetLen), Len > SetLen.

get_all_of_color(Grid, TargetColor, TargetIndices) :-
    findall(Index, (nth0(Index, Grid, Cell), is_target_color(Cell, TargetColor)), TargetIndices).

find_inside_cells(Grid, NumOfColumns, LoopBoundary, InsideSet) :-
    length(Grid, TotalCells),
    grid_boundaries(NumOfColumns, TotalCells, Borders),
    subtract(Borders, LoopBoundary, StartNodes),
    flood_fill(StartNodes, LoopBoundary, NumOfColumns, TotalCells, [], OutsideCells),
    MaxIndex is TotalCells - 1,
    findall(I, between(0, MaxIndex, I), AllCells),
    subtract(AllCells, LoopBoundary, NonLoopCells),
    subtract(NonLoopCells, OutsideCells, InsideSet).

grid_boundaries(NumOfColumns, TotalCells, Bounds) :-
    NumRows is TotalCells // NumOfColumns, MaxCol is NumOfColumns - 1, MaxRow is NumRows - 1,
    findall(I, (between(0, MaxRow, R), between(0, MaxCol, C), (R =:= 0 ; R =:= MaxRow ; C =:= 0 ; C =:= MaxCol), I is R * NumOfColumns + C), RawBounds),
    list_to_set(RawBounds, Bounds).

flood_fill([], _, _, _, Visited, Visited).
flood_fill([Curr|Rest], LoopBoundary, NumOfColumns, TotalCells, Visited, Outside) :-
    findall(N, (neighbor_index(Curr, NumOfColumns, TotalCells, N), \+ memberchk(N, LoopBoundary), \+ memberchk(N, Visited)), NeighborsRaw),
    list_to_set(NeighborsRaw, Neighbors),
    subtract(Neighbors, Rest, NewNeighbors),
    append(Rest, NewNeighbors, NewQueue),
    flood_fill(NewQueue, LoopBoundary, NumOfColumns, TotalCells, [Curr|Visited], Outside).

neighbor_index(Index, NumOfColumns, _, NeighborIndex) :- Index mod NumOfColumns =\= 0, NeighborIndex is Index - 1.
neighbor_index(Index, NumOfColumns, _, NeighborIndex) :- (Index + 1) mod NumOfColumns =\= 0, NeighborIndex is Index + 1.
neighbor_index(Index, NumOfColumns, _, NeighborIndex) :- NeighborIndex is Index - NumOfColumns, NeighborIndex >= 0.
neighbor_index(Index, NumOfColumns, TotalCells, NeighborIndex) :- NeighborIndex is Index + NumOfColumns, NeighborIndex < TotalCells.

neighbor_9_index(Index, NumOfColumns, TotalCells, NeighborIndex) :-
    Row is Index // NumOfColumns, Col is Index mod NumOfColumns, NumRows is TotalCells // NumOfColumns,
    between(-1, 1, DR), between(-1, 1, DC),
    NewRow is Row + DR, NewCol is Col + DC,
    NewRow >= 0, NewRow < NumRows, NewCol >= 0, NewCol < NumOfColumns,
    NeighborIndex is NewRow * NumOfColumns + NewCol.


% ==============================================================================
% 6. MÓDULO DE EXPLOSIONES Y CASCADAS RECURSIVAS
% ==============================================================================
/*detonar_cascada destruye las bombas actuales, marca a las bombas adyacentes como activas (b_act), 
aplica gravedad para que caigan a su nueva posición,
 y se vuelve a llamar a sí misma para detonarlas en el siguiente fotograma.*/

 
% Caso base: Ya no hay bombas por detonar. Verificamos si hay que mezclar el tablero y terminamos.
detonar_cascada(Grid, [], NumOfColumns, _, _, _, _, Effects) :-
    ensure_valid_moves(Grid, NumOfColumns, FinalGrid, WasShuffled),
    ( WasShuffled == true ->
        Effects = [effect(FinalGrid, [shuffled])]
    ;
        Effects = []
    ).

% Caso recursivo: Hay bombas listas para detonar en este fotograma
detonar_cascada(Grid, [Bomb|RestBombs], NumOfColumns, TotalCells, Color, AccWater, AccColor, [CurrentEffect | RestEffects]) :-
    BombsToExplode = [Bomb|RestBombs],
    
    % 1. Calcular el radio de explosión actual
    calcular_radio_explosion(BombsToExplode, NumOfColumns, TotalCells, ExplosionSetRaw),
    list_to_set(ExplosionSetRaw, ExplosionSet),

    % 2. Identificar bombas encadenadas (que están en el radio de la explosión pero no detonan HOY)
    findall(N, (
        member(N, ExplosionSet),
        nth0(N, Grid, Cell),
        is_bomb_cell(Cell),
        \+ memberchk(N, BombsToExplode)
    ), NextBombsRaw),
    list_to_set(NextBombsRaw, NextBombs),

    % 3. Las bombas encadenadas sobreviven al radio de esta explosión (se detonarán en la próxima iteración)
    subtract(ExplosionSet, NextBombs, TrueCellsToClear),

    % 4. Procesar la grilla (las que explotan se vacían, las encadenadas se marcan como "activas")
    procesar_celdas_cascada(Grid, Grid, TrueCellsToClear, NextBombs, NumOfColumns, TotalCells, 0, ClearedGrid, 0, WaterInc, 0, ColorInc),

    % 5. Agua y Gravedad
    propagar_agua(ClearedGrid, NumOfColumns, WaterGrid),
    contar_agua_nueva(ClearedGrid, WaterGrid, WaterProp),
    NewAccWater is AccWater + WaterInc + WaterProp,
    NewAccColor is AccColor + ColorInc,

    apply_gravity(WaterGrid, NumOfColumns, GravGrid),

    % 6. Buscar dónde cayeron las bombas encadenadas tras la gravedad y normalizar a bombas estándar
    get_active_bombs(GravGrid, NextActiveBombs),
    normalize_grid(GravGrid, FinalIterGrid),

    % 7. Crear el EFECTO de la interfaz para ESTE turno
    CurrentEffect = effect(FinalIterGrid, [achieved([[Color, NewAccColor], [~, NewAccWater]]), explosions(BombsToExplode, ExplosionSet)]),

    % 8. Llamada recursiva: detonar las bombas encadenadas en la próxima iteración (fotograma)
    detonar_cascada(FinalIterGrid, NextActiveBombs, NumOfColumns, TotalCells, Color, NewAccWater, NewAccColor, RestEffects).


% Procesador exclusivo para turnos de cascada
procesar_celdas_cascada(_, [], _, _, _, _, _, [], WaterN, WaterN, ColorN, ColorN).
procesar_celdas_cascada(OriginalGrid, [Cell|Rest], CellsToClear, BombsToActivate, NumOfColumns, TotalCells, Index, [NewCell|NewRest], AccW, FinalW, AccC, FinalC) :-
    ( is_nesting_dot(Cell), (memberchk(Index, CellsToClear) ; is_adjacent_to_cleared(Index, NumOfColumns, TotalCells, CellsToClear)) ->
        % Si el radio golpea un Nesting Dot, sufre daño de fase 1. 
        % (Si llega a nivel 1, se convierte en b_act y se suma mágicamente a la próxima cascada!)
        damage_nesting_dot_fase1(Cell, NewCell),
        AccW1 is AccW, AccC1 is AccC
    ; memberchk(Index, BombsToActivate) ->
        % Las bombas encadenadas se preparan para el próximo turno
        determinar_bomba_activa(Cell, NewCell),
        AccW1 is AccW, AccC1 is AccC
    ; memberchk(Index, CellsToClear) ->
        ( should_generate_water(OriginalGrid, Cell, Index, NumOfColumns, TotalCells) -> NewCell = [e, ~] ; NewCell = [e] ),
        calcula_agua_nueva(Cell, NewCell, IncW),
        calcula_color_eliminado(Cell, IncC),
        AccW1 is AccW + IncW, AccC1 is AccC + IncC
    ;
        NewCell = Cell,
        AccW1 is AccW, AccC1 is AccC
    ),
    Index1 is Index + 1,
    procesar_celdas_cascada(OriginalGrid, Rest, CellsToClear, BombsToActivate, NumOfColumns, TotalCells, Index1, NewRest, AccW1, FinalW, AccC1, FinalC).

% --- HELPERS DE EXPLOSIONES ---
calcular_radio_explosion([], _, _, []).
calcular_radio_explosion([BombIdx|Rest], NumOfColumns, TotalCells, ExplosionSet) :-
    calcular_radio_explosion(Rest, NumOfColumns, TotalCells, RestExplosion),
    findall(N, neighbor_9_index(BombIdx, NumOfColumns, TotalCells, N), Neighbors),
    append(Neighbors, RestExplosion, ExplosionSetRaw),
    list_to_set(ExplosionSetRaw, ExplosionSet).

get_active_bombs(Grid, Indices) :- 
    findall(Idx, (nth0(Idx, Grid, Cell), is_active_bomb(Cell)), Indices).

determinar_celda_bomba(Cell, Cell) :- is_empty_cell(Cell), !.
determinar_celda_bomba([-], [-]) :- !.
determinar_celda_bomba(Cell, [b, ~]) :- has_water(Cell), !.
determinar_celda_bomba(_, [b]).

determinar_bomba_activa(Cell, Cell) :- is_empty_cell(Cell), !.
determinar_bomba_activa([-], [-]) :- !.
determinar_bomba_activa(Cell, [b_act, ~]) :- has_water(Cell), !.
determinar_bomba_activa(_, [b_act]).

normalize_grid([], []).
normalize_grid([[b_act]|Rest], [[b]|NormRest]) :- !, normalize_grid(Rest, NormRest).
normalize_grid([[b_act, ~]|Rest], [[b, ~]|NormRest]) :- !, normalize_grid(Rest, NormRest).
normalize_grid([Cell|Rest], [Cell|NormRest]) :- normalize_grid(Rest, NormRest).

% ==============================================================================
% 7. MÓDULO DE IDENTIFICADORES Y HELPERS BÁSICOS
% ==============================================================================

is_empty_cell([e]).
is_empty_cell([e, ~]).

is_obstacle_cell([-]).

available_colors([r, y, g, c, p]).

is_target_color([C], TargetColor) :- C == TargetColor.
is_target_color([C, ~], TargetColor) :- C == TargetColor.

% Todos los elementos que se ven afectados por la gravedad
is_point_cell([C]) :- available_colors(Colors), memberchk(C, Colors).
is_point_cell([C, ~]) :- available_colors(Colors), memberchk(C, Colors).
is_point_cell([b]).
is_point_cell([b, ~]).
is_point_cell([b_act]).      % Bombas cayendo en Fase 1
is_point_cell([b_act, ~]).
is_point_cell([n1]). is_point_cell([n1, ~]).
is_point_cell([n2]). is_point_cell([n2, ~]).
is_point_cell([n3]). is_point_cell([n3, ~]).

is_bomb_cell([b]).
is_bomb_cell([b, ~]).

is_active_bomb([b_act]).
is_active_bomb([b_act, ~]).

strip_water([C, ~], [C]) :- C \= '~', !.
strip_water([C], [C]).

apply_water(OriginalCell, Point, FinalCell) :- has_water(OriginalCell), strip_water(Point, [C]), FinalCell = [C, ~], !.
apply_water(_, Point, FinalCell) :- strip_water(Point, [C]), FinalCell = [C].

% --- HELPERS DE NESTING DOTS (OBSTÁCULOS GRISES) ---

is_adjacent_to_cleared(Index, NumOfColumns, TotalCells, ClearedSet) :-
    neighbor_index(Index, NumOfColumns, TotalCells, NIdx),
    memberchk(NIdx, ClearedSet), !.

is_nesting_dot([n1]). is_nesting_dot([n1, ~]).
is_nesting_dot([n2]). is_nesting_dot([n2, ~]).
is_nesting_dot([n3]). is_nesting_dot([n3, ~]).

is_n1_dot([n1]). is_n1_dot([n1, ~]).

% Daño estándar (se usa en Caso A o si es golpeado por una explosión en Fase 2)
damage_nesting_dot([n3], [n2]).
damage_nesting_dot([n3, ~], [n2, ~]).
damage_nesting_dot([n2], [n1]).
damage_nesting_dot([n2, ~], [n1, ~]).
damage_nesting_dot([n1], [b]).
damage_nesting_dot([n1, ~], [b, ~]).

% Daño en Fase 1: El n1 se convierte en b_act para que explote instantáneamente
damage_nesting_dot_fase1([n3], [n2]).
damage_nesting_dot_fase1([n3, ~], [n2, ~]).
damage_nesting_dot_fase1([n2], [n1]).
damage_nesting_dot_fase1([n2, ~], [n1, ~]).
damage_nesting_dot_fase1([n1], [b_act]).
damage_nesting_dot_fase1([n1, ~], [b_act, ~]).
% ==============================================================================
% 8. MÓDULO DE LOGROS Y OBJETIVOS (UI)
% ==============================================================================

calcula_agua_nueva(OldCell, NewCell, 1) :- \+ has_water(OldCell), has_water(NewCell), !.
calcula_agua_nueva(_, _, 0).

calcula_color_eliminado(Cell, 1) :- is_point_cell(Cell), !.
calcula_color_eliminado(_, 0).

contar_agua_nueva([], [], 0).
contar_agua_nueva([OldCell|OldRest], [NewCell|NewRest], Total) :-
    contar_agua_nueva(OldRest, NewRest, SubTotal),
    ( OldCell = [e], NewCell = [e, ~] -> Total is SubTotal + 1 ; Total is SubTotal ).

fill_new_points(0, []) :- !.
fill_new_points(Count, [[Color]|Rest]) :-
    Count > 0,
    available_colors(Colors), random_member(Color, Colors),
    Count1 is Count - 1,
    fill_new_points(Count1, Rest).

% ==============================================================================
% 9. MÓDULO DE REORDENAMIENTO (SHUFFLE)
% ==============================================================================

% Verifica recursivamente que la grilla tenga movimientos. Si no los tiene, la mezcla.
ensure_valid_moves(Grid, NumOfColumns, FinalGrid, WasShuffled) :-
    ( has_valid_move(Grid, NumOfColumns) ->
        FinalGrid = Grid,
        WasShuffled = false
    ;
        shuffle_grid(Grid, ShuffledGrid),
        % Validamos de nuevo por si la mezcla aleatoria tampoco tiene movimientos (raro, pero posible)
        ensure_valid_moves(ShuffledGrid, NumOfColumns, FinalGrid, _) ,
        WasShuffled = true
    ).

% Verifica si hay al menos dos puntos del mismo color adyacentes
has_valid_move(Grid, NumOfColumns) :-
    length(Grid, TotalCells),
    MaxIndex is TotalCells - 1,
    between(0, MaxIndex, Index),
    nth0(Index, Grid, Cell),
    is_shuffleable_color(Cell),
    strip_water(Cell, [Color]),
    (
        % Chequear vecino a la derecha
        ( (Index + 1) mod NumOfColumns =\= 0,
          NeighborIdx is Index + 1,
          nth0(NeighborIdx, Grid, NeighborCell),
          is_shuffleable_color(NeighborCell),
          strip_water(NeighborCell, [NeighborColor]),
          Color == NeighborColor
        )
    ;
        % Chequear vecino de abajo
        ( NeighborIdx is Index + NumOfColumns,
          NeighborIdx =< MaxIndex,
          nth0(NeighborIdx, Grid, NeighborCell),
          is_shuffleable_color(NeighborCell),
          strip_water(NeighborCell, [NeighborColor]),
          Color == NeighborColor
        )
    ),
    !. % Green cut: detiene la búsqueda apenas encuentra un movimiento

% Identifica si la celda es un color combinable (ignora bombas y obstáculos)
is_shuffleable_color(Cell) :- 
    is_point_cell(Cell),
    strip_water(Cell, [C]),
    available_colors(Colors),
    memberchk(C, Colors).

% Extrae los colores, los mezcla y los reinserta en el esqueleto de la grilla original
shuffle_grid(Grid, ShuffledGrid) :-
    extract_points_and_skeletons(Grid, Points, Skeleton),
    random_permutation(Points, ShuffledPoints),
    rebuild_shuffled_grid(Skeleton, ShuffledPoints, ShuffledGrid).

extract_points_and_skeletons([], [], []).

% Si es un punto de color CON agua
extract_points_and_skeletons([Cell|Rest], [[C]|P], [p_water|S]) :-
    is_shuffleable_color(Cell), has_water(Cell), strip_water(Cell, [C]), !,
    extract_points_and_skeletons(Rest, P, S). % <--- FALTABA ESTA RECURSIVIDAD

% Si es un punto de color SIN agua
extract_points_and_skeletons([Cell|Rest], [[C]|P], [p|S]) :-
    is_shuffleable_color(Cell), \+ has_water(Cell), strip_water(Cell, [C]), !,
    extract_points_and_skeletons(Rest, P, S). % <--- FALTABA ESTA RECURSIVIDAD

% Si no se puede mezclar (bombas, vacíos, obstáculos), queda anclado en el esqueleto
extract_points_and_skeletons([Cell|Rest], P, [Cell|S]) :-
    extract_points_and_skeletons(Rest, P, S).

rebuild_shuffled_grid([], _, []).
rebuild_shuffled_grid([p_water|RestS], [[C]|RestP], [[C, ~]|RestGrid]) :-
    !, rebuild_shuffled_grid(RestS, RestP, RestGrid).
rebuild_shuffled_grid([p|RestS], [[C]|RestP], [[C]|RestGrid]) :-
    !, rebuild_shuffled_grid(RestS, RestP, RestGrid).
rebuild_shuffled_grid([Cell|RestS], Points, [Cell|RestGrid]) :-
    rebuild_shuffled_grid(RestS, Points, RestGrid).
