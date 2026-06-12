:- module(init, [ init/4, init2/4, init3/4 ]).

/**
 * init(-Grid, -NumOfColumns, -Goals, -Moves).
 * 
 * Predicado especificando la grilla inicial, que será mostrada al comienzo del juego, donde:
 * - Grid es una lista plana con las celdas que conforman la grilla
 * - NumOfColumns es la cantidad de columnas (determina las dimensiones)
 * - Goals es una lista con los objetivos del juego, por ejemplo, [[r, 10], [g, 7], [p, 15], [~, 21]] (recolectar 10 rojos, 7 verdes, etc).
 * - Moves es la cantidad de movimientos disponibles para el jugador.
 * 
 * Representación de contenido de una celda:
 * r = red
 * c = cyan
 * p = purple
 * y = yellow
 * g = green
 * e = empty (celda vacía, sin punto)
 * - = obstáculo (celda no jugable)
 * ~ = agua
 */

 init([
	% Fila 0 (índices 0-7)
	[-], [-], [c], [p], [-], [-], [-], [-],
	% Fila 1 (índices 8-15)
	[-], [y], [n3], [p], [g], [-], [-], [-],
	% Fila 2 (índices 16-23)
	[r], [r], [g], [y], [p], [g], [-], [-],
	% Fila 3 (índices 24-31)
	[y], [c], [-], [r], [g], [r], [n3], [-],
	% Fila 4 (índices 32-39)
	[n3, ~], [c, ~], [-], [r], [r, ~], [r, ~], [c, ~], [c,~],
	% Fila 5 (índices 40-47)
	[c, ~], [c, ~], [-], [r, ~], [c, ~], [r, ~], [c, ~], [-],
	% Fila 6 (índices 48-55)
	[c, ~], [n3, ~], [g, ~], [r, ~], [r, ~], [r, ~], [-], [-],
	% Fila 7 (índices 56-63)
	[-], [y, ~], [y, ~], [y, ~], [y, ~], [-], [-], [-],
	% Fila 8 (índices 64-71)
	[-], [-], [y, ~], [y,~], [-], [-], [-], [-]
], 8, [[r, 10], [g, 15], [y, 15], [~, 10]], 25).

init2([
	% Fila 0 (índices 0-7)
	[-], [-], [r], [y], [g], [p], [r], [g],
	% Fila 1 (índices 8-15)
	[-], [r], [n3], [r], [n3], [g], [y], [-],
	% Fila 2 (índices 16-23)
	[r], [y], [g], [y], [p], [g], [-], [-],
	% Fila 3 (índices 24-31)
	[r], [n3], [y], [c, ~], [-], [-], [-], [-],
	% Fila 4 (índices 32-39)
	[r, ~], [p, ~], [p, ~], [r, ~], [-], [-], [-], [-],
	% Fila 5 (índices 40-47)
	[c, ~], [c, ~], [n3,~], [-], [-], [-], [-], [-],
	% Fila 6 (índices 48-55)
	[c, ~], [y, ~], [-], [-], [-], [c, ~], [p,~], [p,~],
	% Fila 7 (índices 56-63)
	[c, ~], [y, ~], [-], [-], [p, ~], [g], [r], [g],
	% Fila 8 (índices 64-71)
	[p], [-], [y, ~], [g, ~], [y], [r], [g], [p]
], 8, [[r, 10], [c, 15], [p, 10], [~, 29]], 35).

init3([
	% Fila 0 (índices 0-7)
	[-], [-], [-], [-], [-], [-], [-], [-],
	% Fila 1 (índices 8-15)
	[p,~], [p,~], [-], [-], [-], [y,~], [y,~], [-],
	% Fila 2 (índices 16-23)
	[y,~], [c,~], [n3], [-], [c], [c], [g], [g],
	% Fila 3 (índices 24-31)
	[g,~], [c,~], [y], [p], [y], [c], [p], [g],
	% Fila 4 (índices 32-39)
	[g,~], [r,~], [g,~], [y], [r], [p], [c, ~], [c],
	% Fila 5 (índices 40-47)
	[c, ~], [c, ~], [g,~], [r,~], [n3, ~], [r,~], [c, ~], [-],
	% Fila 6 (índices 48-55)
	[-], [y, ~], [g, ~], [g, ~], [c, ~], [c, ~], [-], [-],
	% Fila 7 (índices 56-63)
	[-], [-], [y, ~], [y, ~], [y, ~], [-], [-], [-],
	% Fila 8 (índices 64-71)
	[-], [-], [-], [y], [-], [-], [-], [-]
], 8, [[r, 10], [g, 15], [p, 10], [~, 15]], 20).