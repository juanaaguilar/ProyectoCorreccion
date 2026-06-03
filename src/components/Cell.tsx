import { CellContent, colorToCss } from "./model";
import styles from "./Cell.module.css";


interface CellProps {
    value: CellContent[];
    onMouseEnter: () => void;
    onMouseDown: () => void;
    isBomb?: boolean;            
    isExplosionRadius?: boolean;  
}
/* Lo modifique para q si llega un null o undefined no rompa, 
y para que acepte tanto un string como un array de strings **/

// 1. AÑADIDO: Extraemos isBomb e isExplosionRadius de las props
function Cell({ value, onMouseEnter, onMouseDown, isBomb, isExplosionRadius }: CellProps) {
    // console.log("Cell value:", JSON.stringify(value));
    // console.log("El valor de la celda es:", value, "y su tipo es:", typeof value);
    
    if (!value) return <div className={styles.empty} />;

    const normalizedValue = Array.isArray(value) ? value : [value];

    const content = normalizedValue.map((cellContent, i) => {
        switch (cellContent) {
            case "~": return <div className={styles.water} key={i} />;
            case "-": return <div className={styles.empty} key={i} />;
            case "e": return <div className={styles.empty} key={i} />;
            default: 
                // 2. AÑADIDO: Lógica condicional para las animaciones
                let dotClass = styles.color;
                
                // Si colorToCss rompe cuando le pasas una "b" (de bomba), 
                // podés manejarlo acá de forma segura.
                let dotStyle = { backgroundColor: cellContent === "b" ? "#111" : colorToCss(cellContent) };

                if (isBomb) {
                    dotClass = `${styles.color} ${styles.bombAnim}`;
                    dotStyle.backgroundColor = "#111"; // Forzamos negro
                } else if (isExplosionRadius) {
                    dotClass = `${styles.color} ${styles.flashAnim}`;
                    dotStyle.backgroundColor = "#fff"; // Forzamos blanco
                }

                return (
                    <button
                        className={dotClass}
                        onMouseDown={onMouseDown}
                        onMouseEnter={onMouseEnter}
                        key={i}
                    >
                        <div style={dotStyle} />
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