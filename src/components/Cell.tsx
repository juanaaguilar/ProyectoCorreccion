import { CellContent, colorToCss } from "./model";
import styles from "./Cell.module.css";


interface CellProps {
    value: CellContent[];
    onMouseEnter: () => void;
    onMouseDown: () => void;
}
/* Lo modifique para q si llega un null o undefined no rompa, 
y para que acepte tanto un string como un array de strings **/

function Cell({ value, onMouseEnter, onMouseDown }: CellProps) {
      console.log("Cell value:", JSON.stringify(value));
  console.log("El valor de la celda es:", value, "y su tipo es:", typeof value);
  // 1. Si value es undefined o null, no renderizamos nada (o renderizamos una celda vacía)
  if (!value) return <div className={styles.empty} />;

  // 2. Nos aseguramos de que siempre sea un arreglo. 
  // Si es un string como "-", lo convertimos a ["-"]
  const normalizedValue = Array.isArray(value) ? value : [value];

  const content = normalizedValue.map((cellContent, i) => {
    switch (cellContent) {
      case "~": return <div className={styles.water} key={i} />;
      case "-": return <div className={styles.empty} key={i} />;
      case "e": return <div className={styles.empty} key={i} />;
            default: return (
                <button
                    className={styles.color}
                    onMouseDown={onMouseDown}
                    onMouseEnter={onMouseEnter}
                    key={i}
                >
                    <div style={{ backgroundColor: colorToCss(cellContent) }} />
                </button>
            );
        }
  });

  return (
     <div className={styles.cell}>
            {content}
    </div>
  );
}

export default Cell;