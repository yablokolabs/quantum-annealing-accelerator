import { useState, useMemo } from "react";
import { motion } from "framer-motion";

interface SpinGridProps {
  spins: Int8Array;
  gridSize: number;
  getLocalField?: (idx: number) => number;
  temperature?: number;
}

export default function SpinGrid({
  spins,
  gridSize,
  getLocalField,
  temperature = 0,
}: SpinGridProps) {
  const [hoveredIdx, setHoveredIdx] = useState<number | null>(null);

  const cells = useMemo(() => {
    const size = gridSize * gridSize;
    const arr: number[] = [];
    for (let i = 0; i < size && i < spins.length; i++) {
      arr.push(spins[i]);
    }
    return arr;
  }, [spins, gridSize]);

  return (
    <div className="relative">
      <div
        className="grid gap-1.5 mx-auto"
        style={{
          gridTemplateColumns: `repeat(${gridSize}, minmax(0, 1fr))`,
          maxWidth: `${gridSize * 56}px`,
        }}
      >
        {cells.map((spin, idx) => (
          <motion.div
            key={idx}
            className="spin-cell relative aspect-square rounded-lg cursor-pointer flex items-center justify-center text-xs font-mono font-bold border border-slate-200/20"
            animate={{
              backgroundColor:
                spin === 1
                  ? "rgba(34, 211, 238, 0.8)"
                  : "rgba(79, 70, 229, 0.8)",
            }}
            transition={{ duration: 0.3 }}
            onMouseEnter={() => setHoveredIdx(idx)}
            onMouseLeave={() => setHoveredIdx(null)}
          >
            <span className="text-white drop-shadow-sm">
              {spin === 1 ? "+1" : "−1"}
            </span>
          </motion.div>
        ))}
      </div>

      {/* Tooltip */}
      {hoveredIdx !== null && (
        <div className="absolute top-full left-1/2 -translate-x-1/2 mt-2 z-20 px-3 py-2 rounded-lg bg-slate-800 dark:bg-slate-700 text-white text-xs shadow-xl whitespace-nowrap">
          <div>
            <span className="text-slate-400">Spin</span> #{hoveredIdx}
          </div>
          <div>
            <span className="text-slate-400">Value:</span>{" "}
            {spins[hoveredIdx] === 1 ? "+1 (↑)" : "-1 (↓)"}
          </div>
          {getLocalField && (
            <div>
              <span className="text-slate-400">Local field:</span>{" "}
              {getLocalField(hoveredIdx).toFixed(3)}
            </div>
          )}
          <div>
            <span className="text-slate-400">Temperature:</span>{" "}
            {temperature.toFixed(3)}
          </div>
        </div>
      )}
    </div>
  );
}
