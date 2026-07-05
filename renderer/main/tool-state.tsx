import React, { createContext, useCallback, useContext, useRef, useState } from "react";
import type { VideoInfo } from "./types";

// Per-tool session state persisted across navigation within the session.
export interface ToolSession {
  droppedPaths: string[]; // raw paths from Finder drop or dialog
  scannedFiles: VideoInfo[];
  selectedPaths: Set<string>;
  filters: Record<string, boolean>;
  options: Record<string, unknown>;
}

function makeEmptySession(): ToolSession {
  return {
    droppedPaths: [],
    scannedFiles: [],
    selectedPaths: new Set<string>(),
    filters: {},
    options: {},
  };
}

interface ToolStateContextValue {
  getSession: (toolId: string) => ToolSession;
  updateSession: (toolId: string, patch: Partial<ToolSession>) => void;
  preloadPaths: (toolId: string, paths: string[]) => void;
  resetSession: (toolId: string) => void;
}

const ToolStateContext = createContext<ToolStateContextValue | null>(null);

export function ToolStateProvider({ children }: { children: React.ReactNode }) {
  // Use a ref-backed map so updates to one tool don't re-render unrelated tools.
  // Components that need reactivity call updateSession which triggers local state.
  const sessionsRef = useRef<Map<string, ToolSession>>(new Map());
  // Revision counter to force consumers to re-read from ref when needed.
  const [_revision, setRevision] = useState(0);

  const getSession = useCallback((toolId: string): ToolSession => {
    if (!sessionsRef.current.has(toolId)) {
      sessionsRef.current.set(toolId, makeEmptySession());
    }
    return sessionsRef.current.get(toolId)!;
  }, []);

  const updateSession = useCallback((toolId: string, patch: Partial<ToolSession>) => {
    const current = sessionsRef.current.get(toolId) ?? makeEmptySession();
    sessionsRef.current.set(toolId, { ...current, ...patch });
    setRevision((r) => r + 1);
    console.log("[ToolState:update]", { toolId, patch });
  }, []);

  const preloadPaths = useCallback((toolId: string, paths: string[]) => {
    const current = sessionsRef.current.get(toolId) ?? makeEmptySession();
    sessionsRef.current.set(toolId, { ...current, droppedPaths: paths });
    setRevision((r) => r + 1);
    console.log("[ToolState:preloadPaths]", { toolId, count: paths.length });
  }, []);

  const resetSession = useCallback((toolId: string) => {
    sessionsRef.current.set(toolId, makeEmptySession());
    setRevision((r) => r + 1);
    console.log("[ToolState:reset]", { toolId });
  }, []);

  return (
    <ToolStateContext.Provider value={{ getSession, updateSession, preloadPaths, resetSession }}>
      {children}
    </ToolStateContext.Provider>
  );
}

export function useToolState(toolId: string) {
  const ctx = useContext(ToolStateContext);
  if (!ctx) throw new Error("useToolState must be used inside <ToolStateProvider>");

  const session = ctx.getSession(toolId);

  return {
    session,
    updateSession: (patch: Partial<ToolSession>) => ctx.updateSession(toolId, patch),
    preloadPaths: (paths: string[]) => ctx.preloadPaths(toolId, paths),
    resetSession: () => ctx.resetSession(toolId),
  };
}

export function useToolStateContext() {
  const ctx = useContext(ToolStateContext);
  if (!ctx) throw new Error("useToolStateContext must be used inside <ToolStateProvider>");
  return ctx;
}
