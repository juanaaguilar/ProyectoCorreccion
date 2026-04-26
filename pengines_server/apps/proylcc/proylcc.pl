:- module(proylcc,
	[  
		connect/4
	]).

:-use_module(library(lists)).
:-discontiguous proylcc:connect/4.
:-discontiguous proylcc:is_obstacle_cell/1.

% NOTA: Tenemos que ver que los puntos que eliminamos se reflejen en la interfaz, usar funcion effect.
% NOTA: Los cuadrados eliminan puntos que no deberían eliminar. 
% NOTA: Implementar funcionalidad para guardar la grilla y poder ir para atrás en las jugadas. 
% NOTA: BORRAR COMENTARIOS, unificar nombres.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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

% Modificación de connect/4
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
    
    % 3. Evaluar agua
    ( path_touches_water(Grid, NumOfColumns, PathSet) ->
        WaterExpands = true
    ;
        WaterExpands = false
    ),
    
    % 4. Procesar la grilla (Iniciamos ambos contadores en 0)
    procesar_celdas(Grid, PathSet, InsideSet, WaterExpands, 0, GridProcesada, 0, WaterN, 0, ColorN),
    
    % 5. Aplicar la gravedad
    apply_gravity(GridProcesada, NumOfColumns, NewGrid).


% procesar_celdas(Grid, PathSet, InsideSet, WaterExpands, Index, NewGrid, AccWater, TotalWater, AccColor, TotalColor)
procesar_celdas([], _, _, _, _, [], WaterN, WaterN, ColorN, ColorN).
procesar_celdas([Cell|Rest], PathSet, InsideSet, WaterExpands, Index, [NewCell|NewRest], AccW, FinalW, AccC, FinalC) :-
    ( memberchk(Index, PathSet) ->
        % 1. Si es del color o camino, se elimina
        determinar_celda_vacia(Cell, WaterExpands, NewCell),
        
        % Calculamos los logros de esta celda específica
        calcula_agua_nueva(Cell, NewCell, IncW),
        calcula_color_eliminado(Cell, IncC),
        
        AccW1 is AccW + IncW,
        AccC1 is AccC + IncC
        
    ; memberchk(Index, InsideSet) ->
        % 2. Si quedó atrapada, se convierte en bomba (no suma a objetivos)
        determinar_celda_bomba(Cell, NewCell),
        AccW1 is AccW, AccC1 is AccC
    ;
        % 3. Si no pasa nada, se queda igual
        NewCell = Cell,
        AccW1 is AccW, AccC1 is AccC
    ),
    Index1 is Index + 1,
    procesar_celdas(Rest, PathSet, InsideSet, WaterExpands, Index1, NewRest, AccW1, FinalW, AccC1, FinalC).


% Reglas para crear bombas preservando obstáculos, espacios vacíos y agua.
determinar_celda_bomba(Cell, Cell) :- is_empty_cell(Cell), !.
determinar_celda_bomba([-], [-]) :- !.
determinar_celda_bomba(Cell, [b, ~]) :- has_water(Cell), !.
determinar_celda_bomba(_, [b]).

% --- Lógica de sustitución de celdas ---
% Si la jugada expande agua, la celda eliminada queda vacía PERO con agua.
determinar_celda_vacia(_, true, [e, ~]).
% Si la jugada NO expande agua, pero la celda YA TENÍA agua, conserva su agua.
determinar_celda_vacia(Cell, false, [e, ~]) :- has_water(Cell), !.
% Caso contrario, la celda queda completamente vacía.
determinar_celda_vacia(_, false, [e]).

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
%recopila todos los puntos de la columna completa
%cuenta las celdas no-obstáculo
%reconstruye la columna preservando [-] en su posicion
gravity_column(Column, NewColumn) :-
    include(is_point_cell, Column, Points),
    exclude(is_obstacle_cell, Column, NonObstacleCells),
    length(NonObstacleCells, Count),
    fill_gravity_cells(Points, Count, NewNonObstacleCells),
    rebuild_column(Column, NewNonObstacleCells, NewColumn).

%genera la lista de celdas no-obstaculo con gravedad aplicada
%primero van los nuevos puntos y luego los puntos existentes, de forma que los
%puntos ocupen las posiciones mas bajas posibles
fill_gravity_cells(Points, Count, NewCells) :-
    length(Points, NumPoints),
    NumEmpty is Count - NumPoints, %numero de celdas vacias
    fill_new_points(NumEmpty, NewPoints),
    append(NewPoints, Points, NewCells).

%reconstruye la columna manteniendo los obstaculos en su posicion
%reemplaza solo las celdas no-obstáculo
rebuild_column([], [], []).

% Los obstáculos se mantienen intactos
rebuild_column([[-]|Rest], Points, [[-]|NewRest]) :-
    rebuild_column(Rest, Points, NewRest).

% Reconstruimos la celda aplicando el agua si corresponde
rebuild_column([OriginalCell|Rest], [Point|PointsRest], [FinalCell|NewRest]) :-
    OriginalCell \= [-], % Aseguramos que no es un obstáculo
    apply_water(OriginalCell, Point, FinalCell),
    rebuild_column(Rest, PointsRest, NewRest).

% Actualización de identificadores básicos
is_empty_cell([e]).
is_empty_cell([e, ~]). % El agua vacía también cuenta como espacio vacío para la gravedad

is_obstacle_cell([-]).

% Un punto real es una celda que contiene un color (tenga agua o no)
is_point_cell([C]) :- C \= e, C \= '-'.
is_point_cell([C, ~]) :- C \= e, C \= '-'.
is_point_cell([b]). %%reconocer bombas como puntos
is_point_cell([b, ~]). %%reconocer bombas como puntos
is_obstacle_cell([-]).

available_colors([r, y, g, c, p]).

%%%%%%%%%%%%%%%HELPERS:
% Extrae el color base del punto, quitándole el agua si la traía arrastrando
strip_water([C, ~], [C]) :- !.
strip_water([C], [C]).

% Decide qué formato final tendrá el punto según la celda original del tablero
apply_water(OriginalCell, Point, FinalCell) :-
    has_water(OriginalCell),     % Si la posición original en la grilla tenía agua...
    strip_water(Point, [C]),     % Tomamos el color puro del punto que está cayendo...
    FinalCell = [C, ~], !.       % Y lo ensamblamos con agua.

apply_water(_, Point, FinalCell) :-
    strip_water(Point, [C]),     % Si la celda original NO tenía agua...
    FinalCell = [C].             % Queda el color puro.
%%%%%%%%%%%%%%%%%%%%%%%%

% --- MÓDULO DE LOGROS Y OBJETIVOS ---

% Calcula si se generó agua nueva: suma 1 SOLO si la celda original NO tenía agua y la nueva SÍ tiene.
calcula_agua_nueva(OldCell, NewCell, 1) :-
    \+ has_water(OldCell),
    has_water(NewCell), !.
calcula_agua_nueva(_, _, 0).

% Calcula si se eliminó un punto válido para sumar al objetivo de colores.
calcula_color_eliminado(Cell, 1) :- is_point_cell(Cell), !.
calcula_color_eliminado(_, 0).


%Count: numero de huecos a rellenar
fill_new_points(0, []) :- !.
fill_new_points(Count, [[Color]|Rest]) :-
    Count > 0,
    available_colors(Colors),
    random_member(Color, Colors),
    Count1 is Count - 1,
    fill_new_points(Count1, Rest).

% --- MÓDULO DE AGUA ---

% Verifica si una celda contiene agua (ya sea con un punto o vacía)
has_water([_, ~]).
has_water([~]). % Por seguridad, por si en algún momento queda representada así

% Determina si el camino seleccionado interactúa con el agua
% Retorna true si alguna celda del Path ya tiene agua, O si alguna es adyacente al agua.
path_touches_water(Grid, NumOfColumns, PathSet) :-
    member(Index, PathSet), % Tomamos un índice del camino
    (
        nth0(Index, Grid, Cell), has_water(Cell) % Condición A: La celda en sí tiene agua
    ;
        is_adjacent_to_water(Grid, NumOfColumns, Index) % Condición B: Un vecino tiene agua
    ),
    !. % Corte (Green Cut): Si encontramos al menos una interacción, el agua se expande. No necesitamos seguir buscando.

% Verifica si un índice específico tiene agua en alguna de sus celdas adyacentes ortogonales
is_adjacent_to_water(Grid, NumOfColumns, Index) :-
    length(Grid, TotalCells),
    neighbor_index(Index, NumOfColumns, TotalCells, NeighborIndex),
    nth0(NeighborIndex, Grid, NeighborCell),
    has_water(NeighborCell).

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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Logica para cuadrados:La estrategia es la siguiente: en lugar de alterar cómo se elimina 
%el agua o cómo cae la gravedad, simplemente vamos a interceptar la lista de puntos a eliminar (PathSet). 
%Si detectamos que la jugada es un lazo cerrado, reemplazamos el PathSet original por una lista que contenga
%todos los puntos de ese color en el tablero. El agua se expandirá automáticamente por todos ellos si al menos uno toca el agua.

% --- MÓDULO DE FORMAS CERRADAS ---

% Verifica si el camino forma un ciclo (cuadrado o lazo).
% En la UI, si el jugador cierra un ciclo, el último punto del Path es igual a uno de los anteriores.
% Esto significa que hay índices duplicados y la longitud mínima para un lazo en Two Dots es 4.
is_closed_loop(Path) :-
    length(Path, Len),
    Len >= 4,
    list_to_set(Path, PathSet),
    length(PathSet, SetLen),
    Len > SetLen. % Si la longitud original es mayor al set, hay duplicados (se cerró el ciclo)

% Encuentra todos los índices de la grilla que tengan un color específico.
get_all_of_color(Grid, TargetColor, TargetIndices) :-
    findall(Index,
            (nth0(Index, Grid, Cell),
             is_target_color(Cell, TargetColor)),
            TargetIndices).

% Verifica si una celda contiene el color buscado (tenga agua o no).
is_target_color([Color], Color) :- Color \= e, Color \= '-'.
is_target_color([Color, ~], Color) :- Color \= e, Color \= '-'.

% --- MÓDULO GEOMÉTRICO Y BOMBAS ---

% Encuentra todos los índices que están estrictamente dentro de un lazo cerrado.
find_inside_cells(Grid, NumOfColumns, LoopBoundary, InsideSet) :-
    length(Grid, TotalCells),
    grid_boundaries(NumOfColumns, TotalCells, Borders),
    
    % Empezamos la inundación desde los bordes de la pantalla que NO son parte del lazo
    subtract(Borders, LoopBoundary, StartNodes),
    
    % Inundamos para encontrar todo lo que está afuera
    flood_fill(StartNodes, LoopBoundary, NumOfColumns, TotalCells, [], OutsideCells),
    
    % Generamos una lista con todos los índices de la grilla (0 a TotalCells - 1)
    MaxIndex is TotalCells - 1,
    findall(I, between(0, MaxIndex, I), AllCells),
    
    % Adentro = Todas las celdas MENOS el lazo MENOS las celdas de afuera
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
    % Evitamos encolar nodos que ya están esperando en Rest
    subtract(Neighbors, Rest, NewNeighbors),
    append(Rest, NewNeighbors, NewQueue),
    flood_fill(NewQueue, LoopBoundary, NumOfColumns, TotalCells, [Curr|Visited], Outside).