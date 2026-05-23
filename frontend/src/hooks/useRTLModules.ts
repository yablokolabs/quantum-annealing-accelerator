import { useState, useEffect } from "react";
import { rtlModules, type RTLModule } from "../data/modules";

export function useRTLModules() {
  const [modules, setModules] = useState<RTLModule[]>(rtlModules);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function fetchModules() {
      try {
        const res = await fetch("/api/rtl/modules");
        if (!res.ok) throw new Error("Backend unavailable");
        const data: RTLModule[] = await res.json();
        if (!cancelled) {
          setModules(data);
          setError(null);
        }
      } catch {
        if (!cancelled) {
          setModules(rtlModules);
          setError("Using local module data (backend unavailable)");
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    fetchModules();
    return () => { cancelled = true; };
  }, []);

  return { modules, loading, error };
}
