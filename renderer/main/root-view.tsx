import { Outlet } from "@tanstack/react-router";
import * as React from "react";
import { Status } from "@electron-core/components";
import { useTheme, useConnection, useEnvironment } from "@electron-core/hooks";
import { ToolStateProvider } from "./tool-state";
import { DepsGate } from "../components/deps-gate";

export function RootView() {
  useTheme();

  const connectionQuery = useConnection();
  const environmentQuery = useEnvironment();

  React.useEffect(() => {
    return () => {
      console.log("[RootView] cleanup - disconnecting IPC client");
      window.electronAPI?.app?.ipc?.disconnect();
    };
  }, []);

  return (
    <ToolStateProvider>
      <DepsGate>
        <div className="h-full relative [&:not(:has([data-toolbar]))_.drag-region]:z-50">
          {/* Draggable top bar - fallback for when no toolbar is present */}
          <div className="drag-region fixed top-0 left-0 right-0 h-13" />
          <div className="h-full">
            <Outlet />
          </div>

          <div className="flex flex-col items-end gap-1 mt-2 fixed bottom-12 right-2">
            {import.meta.env.DEV ? (
              <>
                {connectionQuery.error ? <Status variant="error">Backend disconnected</Status> : null}
                {environmentQuery.data ? null : <Status variant="error">Dev Server not found</Status>}
              </>
            ) : null}
          </div>
        </div>
      </DepsGate>
    </ToolStateProvider>
  );
}
