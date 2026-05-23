import { motion } from "framer-motion";
import { X, ArrowRight, ArrowLeft, Hash } from "lucide-react";
import type { RTLModule } from "../../data/modules";

interface ModuleDetailProps {
  module: RTLModule;
  onClose: () => void;
}

function highlightSV(code: string): string {
  const keywords = [
    "module","endmodule","input","output","logic","wire","reg","always_ff",
    "always_comb","assign","if","else","begin","end","case","endcase",
    "parameter","genvar","generate","endgenerate","for","typedef","enum",
  ];
  const types = ["int","integer","signed","unsigned"];

  let html = code
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");

  // Comments
  html = html.replace(/(\/\/.*)/g, '<span class="sv-comment">$1</span>');
  // Numbers
  html = html.replace(/\b(\d+'[bhd][\da-fA-F_]+|\d+)\b/g, '<span class="sv-number">$1</span>');
  // Keywords
  const kwRegex = new RegExp(`\\b(${keywords.join("|")})\\b`, "g");
  html = html.replace(kwRegex, '<span class="sv-keyword">$1</span>');
  // Types
  const typeRegex = new RegExp(`\\b(${types.join("|")})\\b`, "g");
  html = html.replace(typeRegex, '<span class="sv-type">$1</span>');

  return html;
}

export default function ModuleDetail({ module: mod, onClose }: ModuleDetailProps) {
  const inputs = mod.ports.filter((p) => p.direction === "input");
  const outputs = mod.ports.filter((p) => p.direction === "output");

  return (
    <motion.div
      initial={{ x: 300, opacity: 0 }}
      animate={{ x: 0, opacity: 1 }}
      exit={{ x: 300, opacity: 0 }}
      transition={{ type: "spring", damping: 25 }}
      className="bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 p-6 overflow-y-auto max-h-[calc(100vh-8rem)]"
    >
      <div className="flex items-start justify-between mb-4">
        <div>
          <h3 className="text-lg font-bold text-slate-900 dark:text-white font-mono">
            {mod.name}
          </h3>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">
            {mod.description}
          </p>
        </div>
        <button
          onClick={onClose}
          className="p-1.5 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors"
        >
          <X size={18} className="text-slate-500" />
        </button>
      </div>

      {/* Signal Flow */}
      <div className="mb-5 px-3 py-2 rounded-lg bg-indigo-50 dark:bg-indigo-900/20 border border-indigo-200 dark:border-indigo-800 text-sm text-indigo-700 dark:text-indigo-300">
        <span className="font-semibold">Signal Flow: </span>
        {mod.signalFlow}
      </div>

      {/* Ports */}
      <div className="mb-5">
        <h4 className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider mb-2">
          Ports
        </h4>
        <div className="space-y-1">
          {inputs.map((p) => (
            <div
              key={p.name}
              className="flex items-center gap-2 text-sm py-1 px-2 rounded bg-slate-50 dark:bg-slate-900/50"
            >
              <ArrowRight size={12} className="text-green-500 shrink-0" />
              <code className="font-mono text-xs text-slate-800 dark:text-slate-200 flex-1">
                {p.name}
              </code>
              <span className="text-xs text-slate-400 flex items-center gap-1">
                <Hash size={10} />{p.width}
              </span>
            </div>
          ))}
          {outputs.map((p) => (
            <div
              key={p.name}
              className="flex items-center gap-2 text-sm py-1 px-2 rounded bg-slate-50 dark:bg-slate-900/50"
            >
              <ArrowLeft size={12} className="text-blue-500 shrink-0" />
              <code className="font-mono text-xs text-slate-800 dark:text-slate-200 flex-1">
                {p.name}
              </code>
              <span className="text-xs text-slate-400 flex items-center gap-1">
                <Hash size={10} />{p.width}
              </span>
            </div>
          ))}
        </div>
      </div>

      {/* Parameters */}
      {mod.parameters.length > 0 && (
        <div className="mb-5">
          <h4 className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider mb-2">
            Parameters
          </h4>
          <div className="space-y-1">
            {mod.parameters.map((p) => (
              <div
                key={p.name}
                className="flex items-center justify-between text-sm py-1 px-2 rounded bg-slate-50 dark:bg-slate-900/50"
              >
                <code className="font-mono text-xs text-cyan-600 dark:text-cyan-400">
                  {p.name}
                </code>
                <span className="text-xs text-slate-500">
                  = {p.defaultValue}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Source Code */}
      <div>
        <h4 className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider mb-2">
          SystemVerilog
        </h4>
        <pre className="code-block bg-slate-900 dark:bg-slate-950 text-slate-300 p-4 rounded-xl overflow-x-auto border border-slate-700">
          <code dangerouslySetInnerHTML={{ __html: highlightSV(mod.code) }} />
        </pre>
      </div>
    </motion.div>
  );
}
