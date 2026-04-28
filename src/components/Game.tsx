import { useEffect, useState } from 'react';
import PengineClient from '../services/PengineClient';
import Board from './Board';
import { delay } from './util';
import styles from './Game.module.css';
import { CellContent, Grid, Objectives, EffectTerm, EffectInfoTerm } from './model';
// import { useHistory } from './helpers'; (PREGUNTAR  si podemos borrar esto)

function Game() {
  // State
  const [pengine, setPengine] = useState<any>(null);
  const [grid, setGrid] = useState<Grid | null>(null);
  const [numOfColumns, setNumOfColumns] = useState<number | null>(null);
  const [moves, setMoves] = useState<number | null>(null);
  const [objectives, setObjectives] = useState<Objectives>({});
  const [path, setPath] = useState<number[]>([]);
  const [waiting, setWaiting] = useState(false);
  //preguntar si podemos borrar esto je
  //const { grid: historyGrid, objectives: historyObjectives } = useHistory({ grid: grid!, objectives, waiting });
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
    setPengine(await PengineClient.create()); // Await until the server is initialized
  }

  useEffect(() => {
    if (pengine) {
      // This is executed after pengine was set.
      initGame();
    }
  }, [pengine]);


  async function initGame() {
    const queryS = 'init(Grid, NumOfColumns, Goals, Moves)';
    const response = await pengine!.query(queryS);
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
      applyEffect(effects[i]);
      
      // Calculamos cómo quedará el estado para guardarlo
      const [effectGrid, effectInfo] = effects[i].args;
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
  // Don't display anything until the Prolog server is ready (alternatively render a loading UI).
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
        />
      </div> 

      {/* --- CARTEL DE FIN DE JUEGO --- */}
      {isGameOver && (
        <div className={styles.gameOverOverlay}>
          <div className={styles.gameOverModal}>
            <h2 className={styles.gameOverTitle}>
              {isVictory ? "¡Victoria!" : "Sin turnos"}
            </h2>
            {/* Como initGame ya reinicia el estado y llama a Prolog, nos sirve perfecto para reiniciar */}
            <button onClick={initGame} className={styles.restartButton}>
              Volver a jugar
            </button>
          </div>
        </div>
      )}
    </div>
    
  );
}
export default Game;