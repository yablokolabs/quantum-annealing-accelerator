import { Play, Pause, RotateCcw, Gauge } from "lucide-react";
import type { SimulationConfig } from "../../lib/localSimulator";

interface SimulationControlsProps {
  config: SimulationConfig;
  onConfigChange: (cfg: SimulationConfig) => void;
  isRunning: boolean;
  onStart: (cfg?: Partial<SimulationConfig>) => void;
  onStop: () => void;
  onReset: () => void;
  speed: number;
  onSpeedChange: (speed: number) => void;
}

export default function SimulationControls({
  config,
  onConfigChange,
  isRunning,
  onStart,
  onStop,
  onReset,
  speed,
  onSpeedChange,
}: SimulationControlsProps) {
  const inputClass =
    "w-full px-3 py-2 rounded-lg bg-slate-100 dark:bg-slate-700 border border-slate-300 dark:border-slate-600 text-sm text-slate-800 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-indigo-500";
  const labelClass = "block text-xs font-medium text-slate-500 dark:text-slate-400 mb-1";

  return (
    <div className="space-y-4">
      <h3 className="text-sm font-bold text-slate-800 dark:text-white flex items-center gap-2">
        <Gauge size={16} className="text-indigo-500" />
        Controls
      </h3>

      <div>
        <label className={labelClass}>
          Spin Count: {config.numSpins}
        </label>
        <input
          type="range"
          min={4}
          max={64}
          step={1}
          value={config.numSpins}
          disabled={isRunning}
          onChange={(e) =>
            onConfigChange({ ...config, numSpins: +e.target.value })
          }
          className="w-full accent-indigo-600"
        />
      </div>

      <div>
        <label className={labelClass}>Temperature</label>
        <input
          type="number"
          step={0.1}
          min={0.01}
          value={config.temperature}
          disabled={isRunning}
          onChange={(e) =>
            onConfigChange({ ...config, temperature: +e.target.value })
          }
          className={inputClass}
        />
      </div>

      <div>
        <label className={labelClass}>Cooling Rate</label>
        <input
          type="number"
          step={0.001}
          min={0.001}
          max={1}
          value={config.coolingRate}
          disabled={isRunning}
          onChange={(e) =>
            onConfigChange({ ...config, coolingRate: +e.target.value })
          }
          className={inputClass}
        />
      </div>

      <div>
        <label className={labelClass}>Schedule Type</label>
        <select
          value={config.schedule}
          disabled={isRunning}
          onChange={(e) =>
            onConfigChange({
              ...config,
              schedule: e.target.value as SimulationConfig["schedule"],
            })
          }
          className={inputClass}
        >
          <option value="linear">Linear</option>
          <option value="exponential">Exponential</option>
          <option value="adaptive">Adaptive</option>
        </select>
      </div>

      <div>
        <label className={labelClass}>Problem Type</label>
        <select
          value={config.problemType}
          disabled={isRunning}
          onChange={(e) =>
            onConfigChange({
              ...config,
              problemType: e.target.value as SimulationConfig["problemType"],
            })
          }
          className={inputClass}
        >
          <option value="max-cut-ring">Max-Cut Ring</option>
          <option value="max-cut-complete">Max-Cut Complete</option>
          <option value="random">Random</option>
        </select>
      </div>

      <div>
        <label className={labelClass}>Speed: {speed}%</label>
        <input
          type="range"
          min={1}
          max={100}
          value={speed}
          onChange={(e) => onSpeedChange(+e.target.value)}
          className="w-full accent-cyan-500"
        />
      </div>

      <div className="flex gap-2 pt-2">
        {!isRunning ? (
          <button
            onClick={() => onStart()}
            className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-semibold transition-colors"
          >
            <Play size={16} />
            Start
          </button>
        ) : (
          <button
            onClick={onStop}
            className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg bg-amber-600 hover:bg-amber-700 text-white text-sm font-semibold transition-colors"
          >
            <Pause size={16} />
            Stop
          </button>
        )}
        <button
          onClick={onReset}
          className="flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg bg-slate-200 dark:bg-slate-700 hover:bg-slate-300 dark:hover:bg-slate-600 text-slate-700 dark:text-slate-200 text-sm font-semibold transition-colors"
        >
          <RotateCcw size={16} />
        </button>
      </div>
    </div>
  );
}
