import React, { useEffect, useState } from "react";
import { CellContent, colorToCss } from "./model";
import styles from "./Cell.module.css";

interface CellProps {
    value: CellContent[];
    onMouseEnter: () => void;
    onMouseDown: () => void;
    isBomb?: boolean;
    isExplosionRadius?: boolean;
    dropTick?: number;
    shouldDrop?: boolean;
    isSelected?: boolean;
}

function Cell({
    value,
    onMouseEnter,
    onMouseDown,
    isBomb,
    isExplosionRadius
    , dropTick, shouldDrop, isSelected
}: CellProps) {

    const [isDropping, setIsDropping] = useState(false as boolean);

    useEffect(() => {
        if (typeof dropTick === 'number' && shouldDrop) {
            setIsDropping(true);
            const t = setTimeout(() => setIsDropping(false), 640);
            return () => clearTimeout(t);
        }
    }, [dropTick, shouldDrop]);

    if (!value) {
        return <div className={styles.empty} />;
    }

    const normalizedValue = Array.isArray(value) ? value : [value];

    const content = normalizedValue.map((cellContent, i) => {
        switch (cellContent) {

            case "~":
                return <div className={styles.water} key={i} />;

            case "-":
            case "e":
                return <div className={styles.empty} key={i} />;

            /* ---------- NESTING DOTS ---------- */

            case "n3":
                return (
                    <button
                        className={`${styles.color} ${styles.n3}`}
                        key={i}
                    >
                        <div />
                    </button>
                );

            case "n2":
                return (
                    <button
                        className={`${styles.color} ${styles.n2}`}
                        key={i}
                    >
                        <div />
                    </button>
                );

            case "n1":
                return (
                    <button
                        className={`${styles.color} ${styles.n1} ${styles.n1Critical}`}
                        key={i}
                    >
                        <div />
                    </button>
                );

            /* ---------- DOTS NORMALES Y BOMBAS ---------- */

            default: {

                let dotClass = styles.color;

                // Punto seleccionado
                if (isSelected) {
                    dotClass += ` ${styles.selected}`;
                }

                // Bomba
                if (cellContent === "b" || isBomb) {
                    dotClass += ` ${styles.bombAnim}`;
                }

                // Explosión
                if (isExplosionRadius) {
                    dotClass += ` ${styles.flashAnim}`;
                }

                const dotStyle =
                    cellContent === "b"
                        ? {}
                        : {
                              backgroundColor: colorToCss(cellContent)
                          };

                return (
                    <button
                            className={`${dotClass} ${isDropping ? styles.dropAnim : ''}`}
                            onMouseDown={onMouseDown}
                            onMouseEnter={onMouseEnter}
                            key={i}
                        >
                            <div style={dotStyle} />
                        </button>
                );
            }
        }
    });

    return (
        <div className={styles.cell}>
            {content}
        </div>
    );
}

export default Cell;