import { useState, useEffect, lazy, Suspense } from "react";
import { AnimatePresence, motion } from "framer-motion";
import Sidebar, { type Page } from "./components/layout/Sidebar";
import HeroSection from "./components/hero/HeroSection";

const SimulationDashboard = lazy(
  () => import("./components/simulation/SimulationDashboard")
);
const ArchitectureExplorer = lazy(
  () => import("./components/architecture/ArchitectureExplorer")
);
const BenchmarkDashboard = lazy(
  () => import("./components/benchmark/BenchmarkDashboard")
);
const EnergyLandscape = lazy(
  () => import("./components/three/EnergyLandscape")
);

function DocsPage() {
  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="space-y-8 max-w-3xl"
    >
      <div>
        <h2 className="text-2xl font-bold text-slate-900 dark:text-white">
          Documentation
        </h2>
        <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">
          Quantum-Inspired Optimization Accelerator — Reference Guide
        </p>
      </div>

      {[
        {
          title: "Overview",
          content:
            "The QA Accelerator implements a stochastic Ising machine in RTL (SystemVerilog). It uses simulated annealing with configurable cooling schedules to solve combinatorial optimization problems mapped to Ising Hamiltonians. The architecture supports 8-64 spin sites with programmable coupling coefficients.",
        },
        {
          title: "Architecture",
          content:
            "The top-level module (qa_top) instantiates a spin_array of N spin_cell units, each connected to an ising_coupler for J-matrix storage and an rng_module for Metropolis acceptance. The anneal_controller FSM orchestrates temperature scheduling, while config_registers provide memory-mapped parameter access. The energy_tracker monitors and records the best configuration found.",
        },
        {
          title: "Simulation",
          content:
            "The interactive simulator runs a Monte Carlo Metropolis algorithm. At each step, a random spin is selected and flipped if the resulting energy change ΔE < 0 or with probability exp(-ΔE/T). Three cooling schedules are available: Linear (T -= rate), Exponential (T *= 1-rate), and Adaptive (reheats on stagnation).",
        },
        {
          title: "Problem Types",
          content:
            "Max-Cut Ring: Spins on a ring graph with antiferromagnetic couplings. Max-Cut Complete: Fully connected graph — hardest for small N. Random: Random J-matrix entries in [-1, 1], representing arbitrary Ising problems.",
        },
        {
          title: "FPGA Targeting",
          content:
            "The RTL is designed for Xilinx 7-series and UltraScale FPGAs. Key constraints: BRAM for J-matrix storage, DSP slices for fixed-point multiplication, LUT-based LFSR RNGs. Target clock: 100-200 MHz depending on spin count and connectivity.",
        },
      ].map((section) => (
        <div
          key={section.title}
          className="bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 p-6"
        >
          <h3 className="text-lg font-bold text-slate-800 dark:text-white mb-2">
            {section.title}
          </h3>
          <p className="text-sm text-slate-600 dark:text-slate-300 leading-relaxed">
            {section.content}
          </p>
        </div>
      ))}
    </motion.div>
  );
}

function LoadingSpinner() {
  return (
    <div className="flex items-center justify-center py-24">
      <div className="w-8 h-8 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin" />
    </div>
  );
}

export default function App() {
  const [page, setPage] = useState<Page>("dashboard");
  const [darkMode, setDarkMode] = useState(true);

  useEffect(() => {
    document.documentElement.classList.toggle("dark", darkMode);
  }, [darkMode]);

  return (
    <div className="flex h-screen overflow-hidden bg-slate-50 dark:bg-slate-900">
      <Sidebar
        currentPage={page}
        onNavigate={setPage}
        darkMode={darkMode}
        onToggleDark={() => setDarkMode(!darkMode)}
      />
      <main className="flex-1 overflow-y-auto">
        <div className="p-6 lg:p-8">
          <AnimatePresence mode="wait">
            <Suspense fallback={<LoadingSpinner />}>
              {page === "dashboard" && (
                <div className="space-y-8">
                  <HeroSection onNavigate={setPage} />
                  <div>
                    <h3 className="text-lg font-bold text-slate-800 dark:text-white mb-4">
                      3D Energy Landscape
                    </h3>
                    <EnergyLandscape />
                  </div>
                </div>
              )}
              {page === "simulation" && <SimulationDashboard />}
              {page === "architecture" && <ArchitectureExplorer />}
              {page === "benchmarks" && <BenchmarkDashboard />}
              {page === "docs" && <DocsPage />}
            </Suspense>
          </AnimatePresence>
        </div>
      </main>
    </div>
  );
}
