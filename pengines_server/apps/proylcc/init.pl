:- module(init, [ init/4 ]).

/*NOTAA IMPORTANTE: modifiqué la cantidad de objetivos,y el nivel inicial, volver a ponerlo como estaba*/

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
	[r], [-], [c], [-], [-], [-], [-], [-],
	% Fila 1 (índices 8-15)
	[-], [-], [-], [-], [-], [-], [-], [-],
	% Fila 2 (índices 16-23)
	[r], [-], [g], [-], [p], [-], [-], [-],
	% Fila 3 (índices 24-31)
	[-], [-], [-], [r], [r], [r], [-], [-],
	% Fila 4 (índices 32-39)
	[y, ~], [c, ~], [-], [-], [c, ~], [-], [-], [c],
	% Fila 5 (índices 40-47)
	[c, ~], [-], [-], [-], [-], [r, ~], [c, ~], [-],
	% Fila 6 (índices 48-55)
	[-], [y, ~], [g, ~], [b, ~], [c, ~], [-], [-], [-],
	% Fila 7 (índices 56-63)
	[c, ~], [-], [-], [y, ~], [-], [-], [-], [-],
	% Fila 8 (índices 64-71)
	[-], [y, ~], [-], [-], [-], [-], [-], [-]
], 8, [[r, 10], [g, 10], [p, 15], [~, 21]], 35).



%armar distintas tablas para ir probando distintos casos
%(armar niveles extra)

%no tocar history grid