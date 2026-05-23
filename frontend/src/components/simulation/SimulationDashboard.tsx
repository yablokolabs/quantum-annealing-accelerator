import { motion } from "framer-motion";
import { Activity, Thermometer, Zap, TrendingDown, Hash } from "lucide-react";
import SpinGrid from "./SpinGrid";
import SimulationControls from "./SimulationControls";
import EnergyChart from "./EnergyChart";
import { useSimulation } from "../../hooks/useSimulation";

export default function SimulationDashboard() {
  const {
    config,
    setConfig,
    state,
    isRunning,
    speed,
    setSpeed,
    useBackend,
    start,
    stop,
    reset,
    getLocalField,
  } = useSimulation();

  const gridSize = Math.min(8, Math.max(2, Math.round(Math.sqrt(config.numSpins))));

  const convergencePct =
    state.bestEnergy !== 0
      ? Math.min(100, Math.abs((state.energy / state.bestEnergy) * 100))
      : 0;

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="space-y-6"
    >
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-slate-900 dark:text-white">
            Ising Simulation
          </h2>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">
            Monte Carlo annealing with Metropolis criterion
          </p>
        </div>
        {useBackend && (
          <span className="px-3 py-1 rounded-full bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 text-xs font-medium">
            Backend Connected
          </span>
        )}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Controls */}
        <div className="lg:col-span-3">
          <div className="bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 p-5">
            <SimulationControls
              config={config}
              onConfigChange={setConfig}
              isRunning={isRunning}
              onStart={start}
              onStop={stop}
              onReset={reset}
              speed={speed}
              onSpeedChange={setSpeed}
            />
          </div>
        </div>

        {/* Spin Grid */}
        <div className="lg:col-span-4">
          <div className="bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 p-5">
            <h3 className="text-sm font-bold text-slate-800 dark:text-white mb-4 flex items-center gap-2">
              <Activity size={16} className="text-cyan-500" />
              Spin Configuration
            </h3>
            <SpinGrid
              spins={state.spins}
              gridSize={gridSize}
              getLocalField={getLocalField}
              temperature={state.temperature}
            />
          </div>
        </div>

        {/* Energy Chart */}
        <div className="lg:col-span-5">
          <div className="bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 p-5 h-full">
            <EnergyChart
              history={state.history}
              bestEnergy={state.bestEnergy}
            />
          </div>
        </div>
      </div>

      {/* Stats Bar */}
      <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
        {[
          {
            icon: Zap,
            label: "Energy",
            value: state.energy.toFixed(2),
            color: "text-indigo-500",
          },
          {
            icon: TrendingDown,
            label: "Best Energy",
            value: state.bestEnergy.toFixed(2),
            color: "text-cyan-500",
          },
          {
            icon: Thermometer,
            label: "Temperature",
            value: state.temperature.toFixed(4),
            color: "text-orange-500",
          },
          {
            icon: Hash,
            label: "Step",
            value: state.step.toLocaleString(),
            color: "text-emerald-500",
          },
          {
            icon: Activity,
            label: "Convergence",
            value: `${convergencePct.toFixed(1)}%`,
            color: "text-purple-500",
          },
        ].map((stat) => {
          const Icon = stat.icon;
          return (
            <div
              key={stat.label}
              className="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-4"
            >
              <div className="flex items-center gap-2 mb-1">
                <Icon size={14} className={stat.color} />
                <span className="text-xs text-slate-500 dark:text-slate-400">
                  {stat.label}
                </span>
              </div>
              <div className="text-lg font-bold font-mono text-slate-900 dark:text-white">
                {stat.value}
              </div>
            </div>
          );
        })}
      </div>
    </motion.div>
  );
}
