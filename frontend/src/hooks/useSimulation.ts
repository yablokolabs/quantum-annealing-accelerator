import { useState, useRef, useCallback, useEffect } from "react";
import {
  createSimulator,
  type SimulationConfig,
  type SimulationState,
} from "../lib/localSimulator";

const defaultConfig: SimulationConfig = {
  numSpins: 16,
  temperature: 5.0,
  coolingRate: 0.02,
  schedule: "exponential",
  problemType: "max-cut-ring",
};

const initialState: SimulationState = {
  spins: new Int8Array(16).fill(1),
  energy: 0,
  temperature: 5.0,
  step: 0,
  bestEnergy: 0,
  bestSpins: new Int8Array(16).fill(1),
  history: [{ step: 0, energy: 0, temperature: 5.0 }],
  converged: false,
};

export function useSimulation() {
  const [config, setConfig] = useState<SimulationConfig>(defaultConfig);
  const [state, setState] = useState<SimulationState>(initialState);
  const [isRunning, setIsRunning] = useState(false);
  const [speed, setSpeed] = useState(50);
  const [useBackend, setUseBackend] = useState(false);

  const simulatorRef = useRef<ReturnType<typeof createSimulator> | null>(null);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const wsRef = useRef<WebSocket | null>(null);

  const tryWebSocket = useCallback(
    (cfg: SimulationConfig) => {
      try {
        const proto = window.location.protocol === "https:" ? "wss:" : "ws:";
        const ws = new WebSocket(
          `${proto}//${window.location.host}/ws/simulate`
        );
        ws.onopen = () => {
          setUseBackend(true);
          ws.send(JSON.stringify({ action: "start", config: cfg }));
        };
        ws.onmessage = (ev) => {
          const data = JSON.parse(ev.data);
          setState((prev) => ({
            spins: new Int8Array(data.spins ?? prev.spins),
            energy: data.energy ?? prev.energy,
            temperature: data.temperature ?? prev.temperature,
            step: data.step ?? prev.step,
            bestEnergy: data.best_energy ?? prev.bestEnergy,
            bestSpins: new Int8Array(data.best_spins ?? prev.bestSpins),
            history: [
              ...prev.history,
              {
                step: data.step,
                energy: data.energy,
                temperature: data.temperature,
              },
            ],
            converged: data.converged ?? false,
          }));
        };
        ws.onerror = () => {
          ws.close();
          setUseBackend(false);
        };
        wsRef.current = ws;
        return true;
      } catch {
        return false;
      }
    },
    []
  );

  const start = useCallback(
    (cfg?: Partial<SimulationConfig>) => {
      const mergedConfig = { ...config, ...cfg };
      setConfig(mergedConfig);

      // Try backend first, fall back to local
      if (!tryWebSocket(mergedConfig)) {
        setUseBackend(false);
      }

      // Always set up local simulator as fallback
      simulatorRef.current = createSimulator(mergedConfig);
      setIsRunning(true);
    },
    [config, tryWebSocket]
  );

  const stop = useCallback(() => {
    setIsRunning(false);
    if (wsRef.current) {
      wsRef.current.send(JSON.stringify({ action: "stop" }));
      wsRef.current.close();
      wsRef.current = null;
    }
    if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  }, []);

  const reset = useCallback(() => {
    stop();
    const newSpins = new Int8Array(config.numSpins);
    for (let i = 0; i < config.numSpins; i++)
      newSpins[i] = Math.random() < 0.5 ? 1 : -1;
    setState({
      spins: newSpins,
      energy: 0,
      temperature: config.temperature,
      step: 0,
      bestEnergy: 0,
      bestSpins: new Int8Array(newSpins),
      history: [{ step: 0, energy: 0, temperature: config.temperature }],
      converged: false,
    });
    simulatorRef.current = null;
  }, [stop, config]);

  // Run local simulation loop
  useEffect(() => {
    if (!isRunning || useBackend) return;
    if (!simulatorRef.current) return;

    const delay = Math.max(10, 200 - speed * 2);
    const sim = simulatorRef.current;

    intervalRef.current = setInterval(() => {
      const newState = sim.doStep();
      setState(newState);
      if (newState.converged) {
        setIsRunning(false);
        if (intervalRef.current) clearInterval(intervalRef.current);
      }
    }, delay);

    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [isRunning, useBackend, speed]);

  const getLocalField = useCallback(
    (idx: number) => simulatorRef.current?.getLocalField(idx) ?? 0,
    []
  );

  return {
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
  };
}
