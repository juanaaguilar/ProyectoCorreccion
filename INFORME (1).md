# Informe de Proyecto: Two Dots

**Materia:** Lógica para Ciencias de la Computación  
**Tecnologías:** Prolog + React  
**Integrantes:** * Aguilar Juana  
* Damiani Luana  
* Gonzalez Aburto Ignacio  

---

## 1. Arquitectura General y Conectividad (React + Prolog)

El desarrollo de la aplicación **Two Dots** se estructuró bajo un modelo híbrido:
* **Frontend (React):** Desde `Game.tsx` se gestiona la interfaz, capturando las interacciones del usuario.
* **Backend Lógico (Prolog):** Implementa el núcleo determinista a través del archivo `proylcc.pl`.

La comunicación se establece mediante la biblioteca **Pengines**. Cuando el jugador completa un trazo, React construye la consulta `connect(Grid, NumOfColumns, Path, Effects)` y la envía al servidor Prolog. El motor lógico procesa la jugada y retorna una lista de `Effects`, la cual es interpretada en el frontend por la función `animateEffects(...)` para renderizar secuencialmente las grillas resultantes y actualizar los objetivos de la interfaz. De esta forma, React es simplemente un presentador visual del estado calculado íntegramente en Prolog.

---

## 2. Lógica del Juego y Estrategias de los Predicados

A continuación se detalla la implementación del predicado central `connect/4` y los módulos auxiliares que rigen las mecánicas del juego.

### 2.1. El Predicado Principal: `connect/4`
La firma del predicado es `connect(Grid, NumOfColumns, Path, Effects)`. Su ejecución se divide en los siguientes pasos lógicos:

**Paso 1: Detección del Color Base**
Toma el primer índice de la lista `Path`. Obtiene el contenido de la celda mediante `nth0/3` y utiliza el helper `strip_water/2` para abstraer el agua (si la hubiera) y quedarse exclusivamente con el color base de la jugada.

**Paso 2: Detección de Formas Cerradas**
Se evalúa el camino mediante `is_closed_loop(Path)`. Este predicado es verdadero si la longitud del trazo es $\geq 4$ y el índice final coincide con uno previo.
* **Si es un lazo cerrado:** Se utiliza `find_inside_cells/4` (apoyado por `flood_fill/6`) para determinar qué celdas quedan atrapadas dentro del polígono. Luego, mediante `get_all_of_color/3`, se extraen todos los índices de ese mismo color presentes en la grilla (`PathSet`).
* **Si no es lazo:** El conjunto de celdas a afectar (`PathSet`) es estrictamente la lista original `Path`.

**Paso 3: Identificación de Bombas y Bifurcación de Rutas**
Se recorre el `PathSet` utilizando `is_bomb_cell/1` para detectar si la jugada activó bombas. Dependiendo de esto, la ejecución toma una de dos rutas principales:

#### Caso A: Ejecución sin Bombas Activas
Se resuelve en una única pasada lógica, devolviendo **1 solo efecto**:
1. `procesar_celdas_impl/11`: Transforma los índices seleccionados en vacíos `[e]` o en agua vacía `[e, ~]`. Si hay índices internos (provenientes del lazo cerrado), utiliza `determinar_celda_bomba/2` para mutarlos a nuevas bombas.
2. `propagar_agua/3`: Expande el agua colindante.
3. `contar_agua_nueva/3`: Actualiza la estadística de agua generada.
4. `apply_gravity/3`: Aplica la gravedad y repone el tablero.
5. **Salida:** `[effect(NewGrid, [achieved([[Color, ColorN], [~, WaterN]])])]`

#### Caso B: Ejecución con Bombas
Requiere una resolución en **dos fases** para poder animar correctamente la secuencia en React (retorna **2 efectos**):
* **Fase 1 (Pre-Explosión):** Mediante `procesar_celdas_fase1/11` se borran las celdas normales del trazo y las bombas involucradas cambian a un estado temporal de "bomba activa" (`b_act`). Luego se propaga el agua y se aplica la gravedad. Se guarda este estado intermedio y se normalizan las bombas temporales.
* **Fase 2 (Detonación):** Se ejecuta `calcular_radio_explosion/4` usando `neighbor_9_index/4` para obtener la zona $3	imes3$ alrededor de cada bomba. `procesar_celdas_impl/11` borra toda la zona afectada, seguida de una nueva expansión de agua (`propagar_agua/3`) y gravedad (`apply_gravity/3`).

### 2.2. Módulo de Gravedad (`apply_gravity/3`)
El procesamiento de la gravedad se maneja dividiendo la grilla mediante predicados como `columns/4` y resolviendo la caída con `gravity_column/2`.
* Se respetan los obstáculos fijos representados internamente como `[-]`. Los puntos válidos caen a través de ellos para ocupar casilleros vacíos inferiores.
* Una vez compactada la columna hacia abajo, el predicado `fill_new_points/2` se encarga de reabastecer las celdas superiores vacías con puntos nuevos aleatorios.

### 2.3. Módulo de Expansión de Agua (`propagar_agua/3`)
El agua se expande evaluando si una celda vacía comparte vecindad directa (utilizando `neighbor_index/4`) con un casillero validado por `has_water/1`. 
La lógica de propagación delega en `propagar_agua_fixpoint/4` y `propagar_agua_una_vez/6` para asegurar que el fluido se extienda hasta su punto de equilibrio antes de que actúe la gravedad, transformando celdas a su versión de fluido `[..., ~]`.

---

## 3. Proceso de Desarrollo Asistido por Inteligencia Artificial

La incorporación de herramientas de Inteligencia Artificial generativa durante el ciclo de vida del proyecto representó una experiencia sumamente entretenida y dinamizadora, modificando positivamente la curva de aprendizaje y resolviendo bloqueos técnicos complejos.

| Área de Aplicación | Impacto de la Asistencia con IA | Beneficio Percibido |
| :--- | :--- | :--- |
| **Interpretación Lógica** | Comprensión acelerada de la unificación y el retroceso (backtracking) nativo de Prolog. | Claridad conceptual inmediata. |
| **Integración de Funciones** | Diseño preciso de interfaces limpias para comunicar las llamadas de React con el backend lógico (`Effects`). | Menos fricción en el flujo de datos. |
| **Optimización de Código** | Reescritura de predicados recursivos para evitar bucles infinitos en el motor lógico (ej: propagación del agua). | Código más limpio y eficiente. |
| **Resolución de Bugs** | Aislamiento rápido de casos de borde erróneos en el cálculo del área $3	imes3$ de las bombas y generación de celdas internas (`flood_fill`). | Reducción del tiempo de testing. |

Lejos de automatizar el trabajo de forma monótona, la IA funcionó como un tutor interactivo de alta disponibilidad. Permitió desglosar las funciones matemáticas subyacentes del juego, ayudando a comprender la importancia relacional de cada predicado y cómo estructurarlos de la manera más óptima posible.

---

## 4. Banco de Pruebas y Casos Significativos

A fin de asegurar la robustez de la lógica implementada en Prolog y su correcto acoplamiento con la interfaz de React, se definieron escenarios de prueba críticos:

### Caso de Prueba 1: Conexión Lineal Estándar, Caída por Gravedad y Reabastecimiento
* **Descripción:** Selección de una línea simple de tres puntos del mismo color. Se verifica el funcionamiento del Caso A (sin bombas) de `connect/4`, constatando que `apply_gravity/3` y `fill_new_points/2` operen correctamente.
* *[Insertar Captura de Pantalla: Comportamiento de gravedad lineal exitoso]*

### Caso de Prueba 2: Activación de Lazo Cerrado y Conversión a Bombas Internas
* **Descripción:** Conexión en forma geométrica cerrada (cuadrado). Se constata la correcta ejecución de `is_closed_loop/1` y `find_inside_cells/4`, verificando la eliminación masiva mediante `get_all_of_color/3` y la creación de nuevas bombas con `determinar_celda_bomba/2`.
* *[Insertar Captura de Pantalla: Demostración de remoción masiva y creación de bombas]*

### Caso de Prueba 3: Detonación de Bomba y Expansión Periférica del Agua
* **Descripción:** Caída y explosión de una bomba adyacente a un sector con agua. Se valida el ciclo de 2 Fases del Caso B: la explosión del área $3	imes3$ (`calcular_radio_explosion/4`) y la inmediata propagación dinámica del agua sobre las celdas liberadas (`propagar_agua_fixpoint/4`) previas a la gravedad.
* *[Insertar Captura de Pantalla: Explosión 3x3 y propagación del agua sobre las celdas afectadas]*
