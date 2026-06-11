import React from 'react';
import styles from './Connector.module.css';

interface ConnectorProps {
    type: "horizontal" | "vertical";
    color?: string;
}

function Connector({ type, color }: ConnectorProps) {

    const active = color !== undefined;

    return (
        <div className={styles.connector}>
            <div
                className={`
                    ${styles.connectorLine}
                    ${type === "vertical" ? styles.vertical : ""}
                    ${active ? styles.connectorActive : ""}
                `}
                style={{ background: color }}
            />
        </div>
    );
}

export default Connector;
