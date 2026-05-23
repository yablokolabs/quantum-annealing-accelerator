import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ReferenceLine,
  ResponsiveContainer,
} from "recharts";

interface EnergyChartProps {
  history: { step: number; energy: number; temperature: number }[];
  bestEnergy: number;
}

export default function EnergyChart({
  history,
  bestEnergy,
}: EnergyChartProps) {
  const data = history.slice(-300);

  return (
    <div className="h-full min-h-[300px]">
      <h3 className="text-sm font-bold text-slate-800 dark:text-white mb-3">
        Energy Landscape
      </h3>
      <ResponsiveContainer width="100%" height="90%">
        <LineChart data={data} margin={{ top: 5, right: 10, left: 0, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#334155" opacity={0.3} />
          <XAxis
            dataKey="step"
            tick={{ fontSize: 11, fill: "#94a3b8" }}
            stroke="#475569"
          />
          <YAxis
            yAxisId="energy"
            tick={{ fontSize: 11, fill: "#94a3b8" }}
            stroke="#475569"
            label={{
              value: "Energy",
              angle: -90,
              position: "insideLeft",
              fill: "#94a3b8",
              fontSize: 11,
            }}
          />
          <YAxis
            yAxisId="temp"
            orientation="right"
            tick={{ fontSize: 11, fill: "#94a3b8" }}
            stroke="#475569"
            label={{
              value: "Temp",
              angle: 90,
              position: "insideRight",
              fill: "#94a3b8",
              fontSize: 11,
            }}
          />
          <Tooltip
            contentStyle={{
              backgroundColor: "#1e293b",
              borderColor: "#334155",
              borderRadius: 8,
              fontSize: 12,
              color: "#e2e8f0",
            }}
          />
          <ReferenceLine
            yAxisId="energy"
            y={bestEnergy}
            stroke="#22d3ee"
            strokeDasharray="5 5"
            label={{
              value: `Best: ${bestEnergy.toFixed(2)}`,
              fill: "#22d3ee",
              fontSize: 11,
            }}
          />
          <Line
            yAxisId="energy"
            type="monotone"
            dataKey="energy"
            stroke="#6366f1"
            strokeWidth={2}
            dot={false}
            isAnimationActive={false}
          />
          <Line
            yAxisId="temp"
            type="monotone"
            dataKey="temperature"
            stroke="#f97316"
            strokeWidth={1.5}
            dot={false}
            strokeDasharray="4 2"
            isAnimationActive={false}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
