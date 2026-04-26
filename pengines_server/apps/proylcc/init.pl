:- module(init, [ init/4 ]).

/*NOTAA IMPORTANTE: modifiqué la cantidad de objetivos, volver a ponerlo como estaba*/

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
	[r], [-], [c], [p], [-], [-], [-], [-],
	% Fila 1 (índices 8-15)
	[c], [y], [g], [p], [r], [-], [-], [-],
	% Fila 2 (índices 16-23)
	[r], [r], [g], [y], [r], [g], [-], [-],
	% Fila 3 (índices 24-31)
	[y], [c], [-], [y], [c], [c], [c], [-],
	% Fila 4 (índices 32-39)
	[y, ~], [c, ~], [-], [g], [c, ~], [y, ~], [c, ~], [c],
	% Fila 5 (índices 40-47)
	[c, ~], [c, ~], [-], [g, ~], [c, ~], [c, ~], [c, ~], [-],
	% Fila 6 (índices 48-55)
	[c, ~], [y, ~], [g, ~], [g, ~], [c, ~], [c, ~], [-], [-],
	% Fila 7 (índices 56-63)
	[c, ~], [y, ~], [y, ~], [y, ~], [y, ~], [-], [-], [-],
	% Fila 8 (índices 64-71)
	[-], [y, ~], [y, ~], [y], [-], [-], [-], [-]
], 8, [[r, 5], [g, 5], [p, 5], [~, 10]], 3).

%no tocar este archivo,es solo para crear la grilla

%hacer un predicado para sacar una celda y completar 

%recorrer la matriz y por cada posicion llamar a otro predicado que revise si hay un punto, devuelva true or false.
%o si no se puede buscar la primera posicion vacia y si la encuentra bajar el punto.




%predicado para ir reemplazando una celda por punto poara q vayan cayendo, recursivo empieza en la primera fila 
%y pasa a la segunda, si encuentra un punto vuelve a la primera y lo baja
%inicializar dinamicamente segun el tamaño de la grilla 
%hacer una lista para ir moviendo las posiciones de los puntos
%podemos hacer un predicado que devuelva la posicion de abajo
%recorrer la matriz y por cada posicion llamar a otro predicado que revise si hay un punto, devuelva true or false.
%o si no se puede buscar la primera posicion vacia y si la encuentra bajar el punto.



%armar distintas tablas para ir probando distintos casos
%(armar niveles extra)

%procesar la grilla como columnas, y luego volvela a grilla
%contar cantidad de huecos en la columna una vez q eliminamos el path 
%pensar por un lado los colores (almacenar en una lista) y rellenar en los huecos los colores

%no tocar history grid