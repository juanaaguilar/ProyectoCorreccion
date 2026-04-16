# Two Dots - Proyecto LCC 2026

Implementación del juego de puzzle Two Dots usando React + Prolog para la materia Lógica para Ciencias de la Computación.

## Contexto Pedagógico

### Objetivos de la Materia
Continuar con la formación de los alumnos como profesionales de la computación, fomentando:
- Espíritu crítico
- Capacidad de análisis y resolución de problemas
- Consideración y evaluación de soluciones alternativas

### Objetivos Específicos del Proyecto
Los alumnos están **aprendiendo tecnologías nuevas**:
- **Prolog**: Paradigma de programación lógica (nuevo para ellos)
- **React + Next.js**: Desarrollo web con componentes (nueva para la mayoría)
- **TypeScript/JavaScript**: Tipado y programación funcional
- **HTML/CSS**: Maquetado y estilos web

**Importante para asistentes de IA**: Considerar que los alumnos son principiantes en estas tecnologías. Proporcionar explicaciones claras, ejemplos didácticos y guiar el proceso de aprendizaje, no solo dar soluciones directas.

## Stack Tecnológico

**Frontend:**
- Next.js 16.1.6 (React 19, App Router)
- TypeScript (strict mode)
- CSS Modules para estilos de componentes

**Backend:**
- SWI-Prolog (servidor Pengines)
- Lógica del juego implementada en Prolog

## Estructura del Proyecto

```
src/
  app/              # Next.js App Router (layout, page, globals)
  components/       # Componentes React del juego (Board, Cell, Game, etc.)
  services/         # Cliente Pengines para comunicación con Prolog
pengines_server/
  apps/proylcc/     # Código Prolog del proyecto
    init.pl         # Configuración de grilla inicial y objetivos
    proylcc.pl      # Lógica principal (predicado connect/4)
```

## Convenciones de Código

### TypeScript
- Usar TypeScript estricto, tipos explícitos
- CSS Modules para componentes (`.module.css`)
- Imports con alias `@/*` para `src/*`

### Prolog
- **CRÍTICO**: No modificar la representación de la grilla en `init.pl`
- Mantener interfaz del predicado `connect/4` (consultarlo con docente si necesita cambios)
- La lógica del juego debe implementarse en Prolog, no en JavaScript

### Nomenclatura
- Componentes React: PascalCase (`Board.tsx`, `Cell.tsx`)
- Archivos helpers: camelCase (`helpers.ts`, `util.ts`)
- Módulos CSS: ComponentName.module.css

## Comandos Principales

```bash
npm install        # Instalar dependencias
npm run dev        # Servidor Next.js (http://localhost:3000)
npm run pengines   # Servidor Prolog (http://localhost:3030)
npm run build      # Build de producción
npm run lint       # Linter ESLint
```

**Importante**: Levantar ambos servidores (React y Pengines) para desarrollo. Los cambios en Prolog requieren reiniciar el servidor Pengines.

## Requerimientos Funcionales

El proyecto debe implementar fielmente la mecánica del juego Two Dots:
- Conexión de puntos del mismo color
- Gravedad y generación de nuevos puntos
- Formas cerradas (elimina todos los puntos del color)
- Bombas (se crean al encerrar elementos, explotan en 3×3)
- Agua (se expande al eliminar puntos adyacentes)
- Obstáculos/espacios no utilizables

Ver [README.md](README.md) para detalles completos de cada requerimiento.

## Aspectos Importantes

1. **Testing**: Los tests usarán diferentes grillas en `init.pl` → mantener representación intacta
2. **División de Responsabilidades**: Lógica del juego en Prolog, UI/interacción en React
3. **Documentación**: Incluir explicación de estrategias y casos de test con capturas en `docs/INFORME.md`
4. **Fidelidad**: Imitar comportamiento exacto de la app oficial Two Dots

## Referencias

- Documentación Next.js: https://nextjs.org/docs
- SWI-Prolog: https://www.swi-prolog.org/pldoc/
- Two Dots oficial: https://www.twodots-game.com/game
