import { useEffect, useState } from 'react';
import PengineClient from '../services/PengineClient';
import Board from './Board';
import { delay } from './util';
import styles from './Game.module.css';
import { CellContent, Grid, Objectives, EffectTerm, EffectInfoTerm } from './model';
// import { useHistory } from './helpers'; (PREGUNTAR  si podemos borrar esto)



// Definimos la interfaz para los datos de la explosión
export interface ExplosionData {
  bombs: number[];
  radius: number[];
}
function Game() {
  // State
  const [pengine, setPengine] = useState<any>(null);
  const [grid, setGrid] = useState<Grid | null>(null);
  const [numOfColumns, setNumOfColumns] = useState<number | null>(null);
  const [moves, setMoves] = useState<number | null>(null);
  const [objectives, setObjectives] = useState<Objectives>({});
  const [path, setPath] = useState<number[]>([]);
  const [waiting, setWaiting] = useState(false);
  const [isShuffling, setIsShuffling] = useState(false);
  const [showMenu, setShowMenu] = useState(true);
  const [connecting, setConnecting] = useState(false);
  const [menuError, setMenuError] = useState<string | null>(null);
  const [bombActivated, setBombActivated] = useState(false);
  const [bombExploded, setBombExploded] = useState(false);
  const [level, setLevel] = useState<number>(1);
  const maxLevel = 3;
  //preguntar si podemos borrar esto je
  //const { grid: historyGrid, objectives: historyObjectives } = useHistory({ grid: grid!, objectives, waiting });
  const [explosionData, setExplosionData] = useState<ExplosionData | null>(null);
  interface GameSnapshot {
    grid: Grid;
    objectives: Objectives;
    moves: number;
  }
  const [history, setHistory] = useState<GameSnapshot[]>([]);
  const [currentStep, setCurrentStep] = useState<number>(0);
  

  useEffect(() => {
    // This is executed just once, after the first render.
    connectToPenginesServer();
  }, []);

  async function connectToPenginesServer() {
    const created = await PengineClient.create();
    setPengine(created); // Await until the server is initialized
    return created;
  }

  useEffect(() => {
    // Do not auto-start the game on connect. The user must press "Jugar".
  }, [pengine]);


  async function initGame(pe?: any, levelToLoad: number = level) {
    
    // 1. Lógica dinámica: Si es el nivel 1, pedimos 'init'. Si es mayor, pedimos 'initX' (ej: init2)
    const predicateName = levelToLoad === 1 ? 'init' : `init${levelToLoad}`;
    
    // 2. Inyectamos el nombre dinámico en la consulta usando template literals
    const queryS = `${predicateName}(Grid, NumOfColumns, Goals, Moves)`;
    
    const engine = pe || pengine;
    const response = await engine!.query(queryS);
    if (!response) {
       alert(`No se pudo cargar el nivel ${levelToLoad}. Revisa la consola para más detalles.`);
       throw new Error(`Prolog falló o devolvió falso al ejecutar: ${queryS}`);
    }
    setGrid(response['Grid']);
    setNumOfColumns(response['NumOfColumns']);
    setMoves(response['Moves']);
    
    const objectives: Objectives = {};
    response['Goals'].forEach(([block, value]: [CellContent, number]) => {
      objectives[block] = value;
    });
    
    setObjectives(objectives);
    setHistory([{
      grid: response['Grid'],
      objectives: objectives,
      moves: response['Moves']
    }]);
    setCurrentStep(0);
  }

  function formatError(err: any) {
    if (typeof err === 'string') return err;
    if (err instanceof Error) return err.message;
    try {
      return JSON.stringify(err, null, 2);
    } catch {
      return String(err);
    }
  }

  async function startGame() {
    setMenuError(null);
    setConnecting(true);
    try {
      setShowMenu(false);
      const engine = pengine || await connectToPenginesServer();
      await initGame(engine, level);
    } catch (err) {
      console.error('Failed to start game:', err);
      setMenuError(formatError(err) || 'No se pudo iniciar el nivel. Verifica que el servidor Pengines esté levantado.');
      setShowMenu(true);
    } finally {
      setConnecting(false);
    }
  }

  function triggerBombExplosion() {
    setBombActivated(true);
    setTimeout(() => {
      setBombExploded(true);
      setTimeout(() => setBombExploded(false), 450);
    }, 300);
    setTimeout(() => setBombActivated(false), 520);
  }

  /**
   * Called while the user is drawing a path in the grid, each time the path changes.
   */
  function onPathChange(newPath: number[]) {
    // No effect if waiting.
    if (waiting) {
      return;
    }
    setPath(newPath);
    console.log(JSON.stringify(newPath));
  }

  /**
   * Called when the user finished drawing a path in the grid.
   */
  //modificamos esta funcion para que cada vez que se complete un path,
  //se actualicen la cantidad de movimientos realizados.
  async function onPathDone() {
    /*
    Build Prolog query, which will be like:
    connect([
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
          RGrids
        ).
    */
   try{
    const gridS = JSON.stringify(grid).replaceAll('"', '');
    const pathS = JSON.stringify(path);
    const queryS = "connect(" + gridS + "," + numOfColumns + "," + pathS + ", Effects)";
    setWaiting(true);
    const response = await pengine.query(queryS);
    setPath([]);
    if (response) {
      // codigo original:
      //setMoves(moves! - 1);
      //animateEffects(response['Effects']);
      const newMoves = moves! - 1;
        setMoves(newMoves);
        // Le pasamos newMoves a la animación para que sepa qué guardar
        animateEffects(response['Effects'], newMoves);
    } else {
      console.log("Prolog query failed")
      setWaiting(false);
    }
  } catch (error) {
    console.error("Error while executing Prolog query:", error);
    setWaiting(false);
  }
 }
  /**
   * Displays each grid of the sequence as the current grid in 1sec intervals, and considers the other effect information.
   * @param effects The list of effects to be animated.
   */
  //modificamos la funcion animateEffects para que reciba los movimientos realizados hasta el momento

  async function animateEffects(effects: EffectTerm[], currentMoves: number) {
    let currentGrid = grid;
    let currentObjectives = { ...objectives };

    for (let i = 0; i < effects.length; i++) {
      
      // Calculamos cómo quedará el estado para guardarlo
      const [effectGrid, effectInfo] = effects[i].args;
      // --- Interceptamos la información de explosión ---
      const explosionInfoItem = effectInfo.find((item: EffectInfoTerm) => item.functor === 'explosions');
      
      // Verificamos si existe el evento de explosión y si trajo bombas para detonar
      if (explosionInfoItem && explosionInfoItem.args[0].length > 0) {
        const bombs = explosionInfoItem.args[0];
        const radius = explosionInfoItem.args[1];
        
        // 1. Prendemos la animación visual pasando las coordenadas
        setExplosionData({ bombs, radius });
        
        // 2. Pausamos la ejecución para darle tiempo al CSS de brillar (1.2 seg)
        await delay(1200);
        
        // 3. Apagamos la animación antes de que caiga la gravedad
        setExplosionData(null);
      }
      // Interceptamos el evento de reordenamiento
     const isShuffledEvent = effectInfo.some((item: any) => item === 'shuffled');
      if (isShuffledEvent) {
          setIsShuffling(true);
          await delay(1500); // Mantenemos el cartel visible 1.5 segundos
          setIsShuffling(false);
      }
      // ---------------------------------------------------------
       applyEffect(effects[i]);
      currentGrid = effectGrid;

      effectInfo.forEach((effectInfoItem: EffectInfoTerm) => {
        if (effectInfoItem.functor === 'achieved') {
          effectInfoItem.args[0].forEach(([block, value]: [CellContent, number]) => {
            if (currentObjectives[block] !== undefined) {
              currentObjectives[block] = Math.max(currentObjectives[block]! - value, 0);
            }
          });
        }
      });

      if (i < effects.length - 1) {
        await delay(1000);
      }
    }
    
    // Al terminar la animación, cortamos futuros alternativos y guardamos la foto
    setHistory(prev => {
      const past = prev.slice(0, currentStep + 1);
      return [...past, { grid: currentGrid!, objectives: currentObjectives, moves: currentMoves }];
    });
    setCurrentStep(prev => prev + 1);
    setWaiting(false);
  }

  function applyEffect(effect: EffectTerm) {
    const [effectGrid, effectInfo] = effect.args;
    setGrid(effectGrid);
    effectInfo.forEach((effectInfoItem: EffectInfoTerm) => {
      const { functor, args } = effectInfoItem;
      switch (functor) {
        case 'achieved':
          setObjectives(prev => {
            const newObjectives = { ...prev };
            args[0].forEach(([block, value]: [CellContent, number]) => {
              if (newObjectives[block] === undefined) {
                return;
              }
              newObjectives[block] = Math.max(newObjectives[block]! - value, 0);
            });
            return newObjectives;
          });
          break;
        default:
          break;
      }
    });
  }
// --- FUNCIONES DE DESHACER / REHACER ---
  function undo() {
    if (currentStep > 0) {
      const prevStep = currentStep - 1;
      setCurrentStep(prevStep);
      const snapshot = history[prevStep];
      setGrid(snapshot.grid);
      setObjectives(snapshot.objectives);
      setMoves(snapshot.moves);
    }
  }

  function redo() {
    if (currentStep < history.length - 1) {
      const nextStep = currentStep + 1;
      setCurrentStep(nextStep);
      const snapshot = history[nextStep];
      setGrid(snapshot.grid);
      setObjectives(snapshot.objectives);
      setMoves(snapshot.moves);
    }
  }

  async function restartLevel() {
    await initGame(undefined, level);
  }

  async function goToNextLevel() {
    const next = Math.min(level + 1, maxLevel);
    setLevel(next);
    try {
      await initGame(undefined, next);
    } catch (error) {
      console.error("Falló al cargar el siguiente nivel. ¿Reiniciaste el servidor Prolog?:", error);
      // Esto evita que React cambie el número de nivel si la grilla falló
      setLevel(level); 
    }
  }

  function goToMenu() {
    setShowMenu(true);
    setLevel(1);
    setGrid(null);
    setNumOfColumns(null);
    setMoves(null);
    setObjectives({});
    setPath([]);
    setWaiting(false);
    setIsShuffling(false);
    setExplosionData(null);
    setHistory([]);
    setCurrentStep(0);
  }

  // Don't display anything until the Prolog server is ready (alternatively render a loading UI).
  if (showMenu) {
    return (
      <div className={styles.startMenu}>
        <div className={styles.menuBombWrapper}>
          <button
            type="button"
            className={`${styles.menuBomb} ${bombActivated ? styles.menuBombActive : styles.menuBombInitial} ${bombExploded ? styles.bombExploded : ''}`}
            onClick={triggerBombExplosion}
            aria-label="Toca la bomba"
          >
            <span className={`${styles.bombCore} ${bombActivated ? styles.bombCoreActive : styles.bombCoreInitial}`} />
          </button>
          {bombExploded && <span className={styles.bombBlast} />}
        </div>
        <div className={styles.dotsContainer} aria-hidden>
          <span className={styles.dot} style={{ top: '7%', left: '8%', width: '28px', height: '28px', backgroundColor: '#e84d60' }} />
          <span className={styles.dot} style={{ top: '16%', left: '78%', width: '18px', height: '18px', backgroundColor: '#7bbdc9' }} />
          <span className={styles.dot} style={{ top: '56%', left: '18%', width: '22px', height: '22px', backgroundColor: '#2cac75' }} />
          <span className={styles.dot} style={{ top: '70%', left: '74%', width: '16px', height: '16px', backgroundColor: '#b388e3' }} />
          <span className={styles.dot} style={{ top: '42%', left: '50%', width: '32px', height: '32px', backgroundColor: '#fecd6c' }} />
          <span className={styles.dot} style={{ top: '54%', left: '86%', width: '12px', height: '12px', backgroundColor: '#e84d60' }} />
          <span className={styles.dot} style={{ top: '10%', left: '56%', width: '14px', height: '14px', backgroundColor: '#2cac75' }} />
          <span className={styles.dot} style={{ top: '28%', left: '24%', width: '10px', height: '10px', backgroundColor: '#b388e3' }} />
          <span className={styles.dot} style={{ top: '22%', left: '62%', width: '20px', height: '20px', backgroundColor: '#e84d60' }} />
          <span className={styles.dot} style={{ top: '66%', left: '36%', width: '14px', height: '14px', backgroundColor: '#7bbdc9' }} />
          <span className={styles.dot} style={{ top: '82%', left: '22%', width: '18px', height: '18px', backgroundColor: '#2cac75' }} />
          <span className={styles.dot} style={{ top: '8%', left: '84%', width: '12px', height: '12px', backgroundColor: '#fecd6c' }} />
        </div>
        <div className={styles.menuCard}>
          <div className={styles.menuHeader}>
            <h1 className={styles.menuTitle} aria-label="Two Dots">
              Tw<span className={styles.titleDot} style={{ backgroundColor: '#e84d60' }} /> D<span className={styles.titleDot} style={{ backgroundColor: '#7bbdc9' }} /><span className={styles.titleT}>t</span><span className={styles.titleS}>s</span>
            </h1>
          </div>
          <div className={styles.menuActions}>
            <button className={styles.playButton} onClick={startGame} disabled={connecting}>
              {connecting ? 'Conectando...' : 'Jugar'}
            </button>
          </div>
          {menuError && <div className={styles.menuError}>{menuError}</div>}
          
        </div>
      </div>
    );
  }

  if (!pengine) {
    return null;
  }

  if (grid === null) {
    return null;
  }
  // --- CONDICIONES DE FIN DE JUEGO ---
  // Ganamos si ya cargaron los objetivos y absolutamente todos llegaron a 0
  const isVictory = Object.keys(objectives).length > 0 && Object.values(objectives).every((val: number | undefined) => val !== undefined && val <= 0);
  // Perdemos si nos quedamos sin movimientos y todavía no ganamos
  const isDefeat = moves !== null && moves <= 0 && !isVictory;
  // El juego termina si se cumple alguna de las dos
  const isGameOver = isVictory || isDefeat;

  return (
    <div className={styles.game}>
      <div className={styles.header}>
        <button className={styles.backButton} onClick={goToMenu}>
          <span className={styles.icon}>&lt;</span>
          
        </button>

        <div className={styles.moves}>
          Moves <span>{moves}</span>
        </div>
          <div className={styles.objectives}>
            {Object.entries(objectives).map(([key, value]) => (
            <div key={key} className={`${styles.obj} ${key === '~' ? styles.water : styles[key]}`}>
              {value}
            </div>
            ))}
          </div>
      </div>
      
      {/* BOTONES DEL HISTORIAL */}
      <div className={styles.controls}>
        <button 
          className={`${styles.gameButton} ${styles.undo}`}
          onClick={undo}
          disabled={currentStep === 0 || waiting}
        >
          <span className={styles.icon}>↺</span>
          <span>Deshacer</span>
        </button>

        <div className={styles.step}>
          Paso {currentStep} / {history.length > 0 ? history.length - 1 : 0}
        </div>

        <button 
          className={`${styles.gameButton} ${styles.redo}`}
          onClick={redo}
          disabled={currentStep === history.length - 1 || waiting}
        >
          <span className={styles.icon}>↻</span>
          <span>Rehacer</span>
        </button>
    </div>
      <div className={styles.boardWrapper}>
        <Board
          grid={grid}
          numOfColumns={numOfColumns!}
          path={path}
          onPathChange={onPathChange}
          onDone={onPathDone}
          readonly={waiting || (history.length > 0 && currentStep < history.length - 1) || isGameOver}
          explosionData={explosionData} /* Pasamos la prop al tablero */
        />
      </div> 

      {/* --- CARTEL DE FIN DE JUEGO --- */}
      {isGameOver && (
        <div className={styles.gameOverOverlay}>
          <div className={styles.gameOverModal}>
            <h2 className={styles.gameOverTitle}>
              {isVictory ? "¡Victoria!" : "Sin movimientos disponibles"}
            </h2>
            {isVictory ? (
              level < maxLevel ? (
                <button onClick={goToNextLevel} className={styles.restartButton}>
                  Siguiente nivel
                </button>
              ) : (
                <button onClick={goToMenu} className={styles.restartButton}>
                  Volver al menú
                </button>
              )
            ) : (
              <button onClick={restartLevel} className={styles.restartButton}>
                Volver a jugar
              </button>
            )}
          </div>
        </div>
      )}
      {/* --- CARTEL DE MEZCLADO --- */}
      {isShuffling && (
        <div className={styles.shufflingOverlay}>
          <div className={styles.shufflingModal}>
            <h2>No hay combinaciones disponibles</h2>
            <p>Reordenando el tablero...</p>
          </div>
        </div>
      )}
    </div>
    
  );
}
export default Game;