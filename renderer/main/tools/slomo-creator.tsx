import React, { useCallback, useEffect, useId, useRef, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import {
  Button,
  Text,
  toast,
  SegmentedControl,
  SegmentedControlItem,
} from "@glaze/core/components";
import { PlayIcon, GripVerticalIcon, XIcon } from "lucide-react";
import { cn } from "@glaze/core/utils";

import { ToolPage } from "../../components/tool-page";
import { DropZone } from "../../components/drop-zone";
import { DryRunToggle } from "../../components/dry-run-toggle";
import { ProgressBar } from "../../components/progress-bar";
import { CancelButton } from "../../components/cancel-button";
import { SectionLabel } from "../../components/section-label";
import { useToolState } from "../tool-state";
import type { JobProgress, FileOpResult } from "../types";

async function invokeIpc<T>(channel: string, params: unknown): Promise<T> {
  return window.glazeAPI.glaze.ipc.invoke(channel, params) as Promise<T>;
}

type SlomoFactor = "0.5" | "0.25";

interface FileEntry {
  path: string;
  name: string;
}

function basename(p: string): string {
  return p.split("/").pop() ?? p;
}


export function SlomoCreator() {
  const toolId = "slomo-creator";
  const { session, updateSession } = useToolState(toolId);
  const jobId = useId();

  const [factor, setFactor] = useState<SlomoFactor>("0.5");
  const [dryRun, setDryRun] = useState(true);
  const [fileList, setFileList] = useState<FileEntry[]>([]);
  const [opResults, setOpResults] = useState<FileOpResult[]>([]);
  const [progress, setProgress] = useState<JobProgress | null>(null);
  const [isRunning, setIsRunning] = useState(false);

  // Reorder state
  const dragIndexRef = useRef<number | null>(null);

  // Preload dropped paths from tool-state on mount (intentionally run only once on mount)
  const didPreload = useRef(false);
  useEffect(() => {
    if (!didPreload.current && session.droppedPaths.length > 0 && fileList.length === 0) {
      didPreload.current = true;
      setFileList(session.droppedPaths.map((p) => ({ path: p, name: basename(p) })));
    }
  });

  useEffect(() => {
    const unsub = window.glazeAPI.glaze.ipc.onNotification(
      "job:progress",
      (payload: unknown) => {
        const p = payload as JobProgress;
        if (p.jobId === jobId) setProgress(p);
      },
    );
    return () => { if (typeof unsub === "function") unsub(); };
  }, [jobId]);

  const handlePaths = useCallback(
    (paths: string[]) => {
      console.log("[slomo-creator:paths]", { count: paths.length });
      const entries = paths.map((p) => ({ path: p, name: basename(p) }));
      setFileList((prev) => {
        // Deduplicate by path
        const existing = new Set(prev.map((e) => e.path));
        const added = entries.filter((e) => !existing.has(e.path));
        return [...prev, ...added];
      });
      updateSession({ droppedPaths: paths });
      setOpResults([]);
    },
    [updateSession],
  );

  const removeFile = (idx: number) => {
    setFileList((prev) => prev.filter((_, i) => i !== idx));
  };

  // HTML5 internal drag-reorder handlers
  const handleDragStart = (e: React.DragEvent, idx: number) => {
    dragIndexRef.current = idx;
    e.dataTransfer.setData("text/plain", String(idx));
    e.dataTransfer.effectAllowed = "move";
  };

  const handleDragOver = (e: React.DragEvent, _idx: number) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = "move";
  };

  const handleDrop = (e: React.DragEvent, targetIdx: number) => {
    e.preventDefault();
    const sourceIdx = dragIndexRef.current;
    if (sourceIdx === null || sourceIdx === targetIdx) return;
    setFileList((prev) => {
      const next = [...prev];
      const [moved] = next.splice(sourceIdx, 1);
      if (moved) next.splice(targetIdx, 0, moved);
      return next;
    });
    dragIndexRef.current = null;
  };

  const handleDragEnd = () => {
    dragIndexRef.current = null;
  };

  const handleCancel = async () => {
    console.log("[slomo-creator:cancel]", { jobId });
    await invokeIpc("job:cancel", { jobId });
    setIsRunning(false);
    setProgress(null);
  };

  const slomoMutation = useMutation({
    mutationFn: async () => {
      setIsRunning(true);
      setProgress(null);
      setOpResults([]);
      const filePaths = fileList.map((f) => f.path);
      const factorNum = parseFloat(factor);
      console.log("[slomo-creator:slomo:create]", { jobId, factor: factorNum, dryRun, count: filePaths.length });
      const result = await invokeIpc<{ results: FileOpResult[]; cancelled: boolean }>(
        "slomo:create",
        { jobId, files: filePaths, factor: factorNum, dryRun },
      );
      return result;
    },
    onSuccess: ({ results, cancelled }) => {
      setIsRunning(false);
      setProgress(null);
      setOpResults(results);
      if (cancelled) {
        toast.info("Operation cancelled.");
        return;
      }
      const errors = results.filter((r) => r.status === "error");
      if (dryRun) {
        toast.success("Dry run complete", { description: `${results.length} operations previewed.` });
      } else if (errors.length > 0) {
        toast.error(`${errors.length} slo-mo creation${errors.length > 1 ? "s" : ""} failed.`);
      } else {
        toast.success("Slo-Mo files created", { description: `${results.length} files created at ${factor}x speed.` });
      }
      console.log("[slomo-creator:slomo:done]", { count: results.length, errors: errors.length });
    },
    onError: (err) => {
      setIsRunning(false);
      setProgress(null);
      console.log("[slomo-creator:slomo:error]", { err });
      toast.error("Slo-Mo creation failed", { description: String(err) });
    },
  });

  const hasFiles = fileList.length > 0;

  return (
    <ToolPage title="Slo-Mo" category="convert">
      <Text variant="regular" color="secondary">
        Create slow-motion dated copies using ffmpeg. Drag files below to reorder them before processing.
      </Text>

      <DropZone
        onPaths={handlePaths}
        accept="both"
        disabled={isRunning}
        hint="Drag videos or a folder here to add to the list"
      />

      {hasFiles && (
        <>
          <div className="flex flex-col gap-3">
            <SectionLabel>Slow-Motion Factor</SectionLabel>
            <SegmentedControl
              value={factor}
              onValueChange={(v) => setFactor(v as SlomoFactor)}
              aria-label="Slow-motion factor"
            >
              <SegmentedControlItem value="0.5">0.5x (Half speed)</SegmentedControlItem>
              <SegmentedControlItem value="0.25">0.25x (Quarter speed)</SegmentedControlItem>
            </SegmentedControl>
          </div>

          <div className="flex flex-col gap-2">
            <SectionLabel>File Order ({fileList.length})</SectionLabel>
            <div className="flex flex-col gap-1 rounded-card border border-separator overflow-hidden">
              {fileList.map((entry, idx) => {
                const result = opResults.find((r) => r.from === entry.path);
                return (
                  <div
                    key={entry.path}
                    draggable
                    onDragStart={(e) => handleDragStart(e, idx)}
                    onDragOver={(e) => handleDragOver(e, idx)}
                    onDrop={(e) => handleDrop(e, idx)}
                    onDragEnd={handleDragEnd}
                    className={cn(
                      "flex items-center gap-3 px-3 py-2 select-none cursor-grab",
                      "bg-control hover:bg-control-active transition-colors duration-100",
                      idx < fileList.length - 1 && "border-b border-separator",
                    )}
                  >
                    <GripVerticalIcon className="size-4 shrink-0 text-tertiary" />
                    <Text variant="small" truncate className="flex-1 min-w-0">
                      {entry.name}
                    </Text>
                    {result && (
                      <span className={cn(
                        "text-xs tabular-nums shrink-0",
                        result.status === "ok" || result.status === "dryrun" ? "text-support-green" : "text-support-red",
                      )}>
                        {result.status === "dryrun" ? "→ dry run" : result.status === "ok" ? "→ done" : `Error: ${result.error ?? ""}`}
                      </span>
                    )}
                    <button
                      onClick={() => removeFile(idx)}
                      disabled={isRunning}
                      aria-label={`Remove ${entry.name}`}
                      className="shrink-0 text-tertiary hover:text-primary transition-colors duration-100 disabled:opacity-40"
                    >
                      <XIcon className="size-3.5" />
                    </button>
                  </div>
                );
              })}
            </div>
          </div>

          {isRunning && progress && (
            <div className="flex flex-col gap-3">
              <ProgressBar progress={progress} />
              <CancelButton onCancel={() => void handleCancel()} />
            </div>
          )}

          <div className="flex items-center gap-4 pt-2 border-t border-separator">
            <Button
              variant="accent"
              size="large"
              onClick={() => slomoMutation.mutate()}
              disabled={!hasFiles || isRunning}
            >
              <PlayIcon className="size-4" />
              {isRunning ? "Creating…" : "Create Slo-Mo"}
            </Button>
            <DryRunToggle checked={dryRun} onCheckedChange={setDryRun} />
          </div>
        </>
      )}
    </ToolPage>
  );
}
