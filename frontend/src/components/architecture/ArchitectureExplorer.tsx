import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useRTLModules } from "../../hooks/useRTLModules";
import ModuleDetail from "./ModuleDetail";

interface BlockDef {
  id: string;
  label: string;
  x: number;
  y: number;
  w: number;
  h: number;
  color: string;
  parent?: string;
}

const blocks: BlockDef[] = [
  { id: "qa_top", label: "qa_top", x: 30, y: 20, w: 740, h: 420, color: "#312e81" },
  { id: "config_registers", label: "config_registers", x: 60, y: 60, w: 160, h: 80, color: "#4338ca" },
  { id: "anneal_controller", label: "anneal_controller", x: 60, y: 170, w: 160, h: 80, color: "#4338ca" },
  { id: "spin_array", label: "spin_array", x: 270, y: 60, w: 310, h: 280, color: "#0891b2" },
  { id: "spin_cell", label: "spin_cell", x: 290, y: 100, w: 120, h: 60, color: "#06b6d4", parent: "spin_array" },
  { id: "ising_coupler", label: "ising_coupler", x: 290, y: 180, w: 120, h: 60, color: "#06b6d4", parent: "spin_array" },
  { id: "rng_module", label: "rng_module", x: 430, y: 140, w: 120, h: 60, color: "#06b6d4", parent: "spin_array" },
  { id: "energy_tracker", label: "energy_tracker", x: 620, y: 60, w: 130, h: 80, color: "#4338ca" },
];

const connections: [string, string][] = [
  ["config_registers", "anneal_controller"],
  ["anneal_controller", "spin_array"],
  ["spin_array", "energy_tracker"],
  ["config_registers", "spin_array"],
];

function getCenter(b: BlockDef): [number, number] {
  return [b.x + b.w / 2, b.y + b.h / 2];
}

function getEdgePoint(
  from: BlockDef,
  to: BlockDef
): { x1: number; y1: number; x2: number; y2: number } {
  const [cx1, cy1] = getCenter(from);
  const [cx2, cy2] = getCenter(to);
  const dx = cx2 - cx1;
  const dy = cy2 - cy1;

  let x1: number, y1: number, x2: number, y2: number;

  if (Math.abs(dx) > Math.abs(dy)) {
    x1 = dx > 0 ? from.x + from.w : from.x;
    y1 = cy1;
    x2 = dx > 0 ? to.x : to.x + to.w;
    y2 = cy2;
  } else {
    x1 = cx1;
    y1 = dy > 0 ? from.y + from.h : from.y;
    x2 = cx2;
    y2 = dy > 0 ? to.y : to.y + to.h;
  }

  return { x1, y1, x2, y2 };
}

export default function ArchitectureExplorer() {
  const { modules, error } = useRTLModules();
  const [selected, setSelected] = useState<string | null>(null);

  const selectedModule = modules.find((m) => m.name === selected);
  const blockMap = Object.fromEntries(blocks.map((b) => [b.id, b]));

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-slate-900 dark:text-white">
          Hardware Architecture
        </h2>
        <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">
          Click on any module to explore its RTL implementation
        </p>
        {error && (
          <p className="text-xs text-amber-500 mt-1">{error}</p>
        )}
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-5 gap-6">
        <div className="xl:col-span-3">
          <div className="bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 p-4 overflow-x-auto">
            <svg viewBox="0 0 800 460" className="w-full h-auto" style={{ minWidth: 600 }}>
              <defs>
                <marker id="arrowhead" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
                  <polygon points="0 0, 8 3, 0 6" fill="#22d3ee" />
                </marker>
              </defs>

              {/* Connections with animated dashes */}
              {connections.map(([fromId, toId]) => {
                const from = blockMap[fromId];
                const to = blockMap[toId];
                if (!from || !to) return null;
                const { x1, y1, x2, y2 } = getEdgePoint(from, to);
                return (
                  <line
                    key={`${fromId}-${toId}`}
                    x1={x1} y1={y1} x2={x2} y2={y2}
                    stroke="#22d3ee"
                    strokeWidth={2}
                    markerEnd="url(#arrowhead)"
                    strokeDasharray="6 3"
                    opacity={0.6}
                  >
                    <animate
                      attributeName="stroke-dashoffset"
                      from="18"
                      to="0"
                      dur="1.5s"
                      repeatCount="indefinite"
                    />
                  </line>
                );
              })}

              {/* Blocks */}
              {blocks.map((block) => {
                const isSelected = selected === block.id;
                return (
                  <g
                    key={block.id}
                    onClick={() => setSelected(block.id)}
                    className="cursor-pointer"
                  >
                    <rect
                      x={block.x}
                      y={block.y}
                      width={block.w}
                      height={block.h}
                      rx={12}
                      fill={block.parent ? "rgba(6, 182, 212, 0.08)" : "rgba(67, 56, 202, 0.08)"}
                      stroke={isSelected ? "#22d3ee" : block.color}
                      strokeWidth={isSelected ? 3 : 1.5}
                      opacity={0.9}
                    />
                    <text
                      x={block.x + (block.parent ? block.w / 2 : 12)}
                      y={block.y + (block.parent ? block.h / 2 + 4 : 18)}
                      textAnchor={block.parent ? "middle" : "start"}
                      className="fill-slate-700 dark:fill-slate-200"
                      fontSize={block.parent ? 11 : 13}
                      fontFamily="JetBrains Mono, monospace"
                      fontWeight={600}
                    >
                      {block.label}
                    </text>
                  </g>
                );
              })}

              {/* Animated data flow particles */}
              {connections.map(([fromId, toId], i) => {
                const from = blockMap[fromId];
                const to = blockMap[toId];
                if (!from || !to) return null;
                const { x1, y1, x2, y2 } = getEdgePoint(from, to);
                return (
                  <circle key={`particle-${i}`} r={3} fill="#22d3ee" opacity={0.8}>
                    <animate
                      attributeName="cx"
                      values={`${x1};${x2}`}
                      dur="2s"
                      repeatCount="indefinite"
                      begin={`${i * 0.4}s`}
                    />
                    <animate
                      attributeName="cy"
                      values={`${y1};${y2}`}
                      dur="2s"
                      repeatCount="indefinite"
                      begin={`${i * 0.4}s`}
                    />
                  </circle>
                );
              })}
            </svg>
          </div>
        </div>

        <div className="xl:col-span-2">
          <AnimatePresence mode="wait">
            {selectedModule ? (
              <ModuleDetail
                key={selectedModule.name}
                module={selectedModule}
                onClose={() => setSelected(null)}
              />
            ) : (
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                className="bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 p-8 text-center"
              >
                <div className="text-4xl mb-4">🔍</div>
                <h3 className="font-bold text-slate-700 dark:text-slate-300 mb-2">
                  Select a Module
                </h3>
                <p className="text-sm text-slate-500 dark:text-slate-400">
                  Click on any block in the architecture diagram to explore its
                  RTL implementation, ports, and SystemVerilog source.
                </p>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </div>
    </motion.div>
  );
}
