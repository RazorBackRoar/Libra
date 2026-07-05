import { useCallback, useEffect, useId, useRef, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { Button, Input, Text, toast } from "@glaze/core/components";
import { PlayIcon } from "lucide-react";

import { ToolPage } from "../../components/tool-page";
import { DropZone } from "../../components/drop-zone";
import { ResultsTable, type SortKey, type SortDir } from "../../components/results-table";
import { CountPills, type CountPill } from "../../components/count-pills";
import { DryRunToggle } from "../../components/dry-run-toggle";
import { ProgressBar } from "../../components/progress-bar";
import { CancelButton } from "../../components/cancel-button";
import { SectionLabel } from "../../components/section-label";
import { useToolState } from "../tool-state";
import type { VideoInfo, JobProgress, FileOpResult } from "../types";

async function invokeIpc<T>(channel: string, params: unknown): Promise<T> {
  return window.glazeAPI.glaze.ipc.invoke(channel, params) as Promise<T>;
}

export function ProvidRenamer() {
  const toolId = "provid-renamer";
  const { session, updateSession } = useToolState(toolId);
  const jobId = useId();

  const [prefix, setPrefix] = useState("");
  const [dryRun, setDryRun] = useState(true);
  const [sortKey, setSortKey] = useState<SortKey>("name");
  const [sortDir, setSortDir] = useState<SortDir>("asc");
  const [progress, setProgress] = useState<JobProgress | null>(null);
  const [isScanning, setIsScanning] = useState(false);
  const [opResults, setOpResults] = useState<FileOpResult[]>([]);

  const cancelledRef = useRef(false);

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
      console.log("[provid-renamer:paths]", { count: paths.length });
      updateSession({ droppedPaths: paths, scannedFiles: [] });
      setOpResults([]);
      setProgress(null);
    },
    [updateSession],
  );

  const scanMutation = useMutation({
    mutationFn: async () => {
      cancelledRef.current = false;
      setIsScanning(true);
      setProgress(null);
      setOpResults([]);
      console.log("[provid-renamer:scan:start]", { jobId, paths: session.droppedPaths });
      const result = await invokeIpc<{ files: VideoInfo[]; cancelled: boolean }>(
        "scan:start",
        { jobId, paths: session.droppedPaths },
      );
      return result;
    },
    onSuccess: (result) => {
      setIsScanning(false);
      setProgress(null);
      updateSession({ scannedFiles: result.files, selectedPaths: new Set() });
      console.log("[provid-renamer:scan:done]", { count: result.files.length });
    },
    onError: (err) => {
      setIsScanning(false);
      setProgress(null);
      console.log("[provid-renamer:scan:error]", { err });
      toast.error("Scan failed", { description: String(err) });
    },
  });

  const handleCancel = async () => {
    cancelledRef.current = true;
    console.log("[provid-renamer:cancel]", { jobId });
    await invokeIpc("job:cancel", { jobId });
    setIsScanning(false);
    setProgress(null);
  };

  const renameMutation = useMutation({
    mutationFn: async () => {
      console.log("[provid-renamer:rename:apply]", { count: session.scannedFiles.length, prefix, dryRun });
      const result = await invokeIpc<{ results: FileOpResult[] }>("rename:apply", {
        files: session.scannedFiles,
        prefix: prefix || undefined,
        dryRun,
      });
      return result;
    },
    onSuccess: ({ results }) => {
      setOpResults(results);
      const errors = results.filter((r) => r.status === "error");
      if (dryRun) {
        toast.success("Dry run complete", { description: `${results.length} operations previewed.` });
      } else if (errors.length > 0) {
        toast.error(`${errors.length} rename${errors.length > 1 ? "s" : ""} failed.`);
      } else {
        toast.success("Rename applied", { description: `${results.length} files renamed.` });
      }
      console.log("[provid-renamer:rename:done]", { count: results.length, errors: errors.length });
    },
    onError: (err) => {
      console.log("[provid-renamer:rename:error]", { err });
      toast.error("Rename failed", { description: String(err) });
    },
  });

  const hasFiles = session.scannedFiles.length > 0;
  const hasPaths = session.droppedPaths.length > 0;

  const countPills: CountPill[] = [
    { label: "Files", count: session.scannedFiles.length, color: "primary" },
    { label: "4K", count: session.scannedFiles.filter((f) => f.resolutionClass === "4K").length, color: "green" },
    { label: "1080p", count: session.scannedFiles.filter((f) => f.resolutionClass === "1080p").length, color: "secondary" },
  ];

  // Map op results back to VideoInfo for display (show only files that have results)
  const resultFiles: VideoInfo[] = opResults.length > 0
    ? session.scannedFiles.filter((f) => opResults.some((r) => r.from === f.path))
    : session.scannedFiles;

  return (
    <ToolPage title="ProVid Renamer" category="rename">
      <Text variant="regular" color="secondary">
        Rename video files in place with an optional prefix, keeping their folder structure.
      </Text>

      <DropZone
        onPaths={handlePaths}
        accept="both"
        disabled={isScanning}
        hint="Drag videos or a folder here"
      />

      {hasPaths && !isScanning && !scanMutation.isPending && (
        <div className="flex items-center gap-3">
          <Button
            variant="accent"
            size="large"
            onClick={() => scanMutation.mutate()}
            disabled={scanMutation.isPending}
          >
            <PlayIcon className="size-4" />
            Scan
          </Button>
          <Text variant="small" color="tertiary">
            {session.droppedPaths.length} path{session.droppedPaths.length !== 1 ? "s" : ""} queued
          </Text>
        </div>
      )}

      {isScanning && progress && (
        <div className="flex flex-col gap-3">
          <ProgressBar progress={progress} />
          <CancelButton onCancel={() => void handleCancel()} />
        </div>
      )}

      {hasFiles && (
        <>
          <div className="flex flex-col gap-2">
            <SectionLabel>Scan Summary</SectionLabel>
            <CountPills pills={countPills} />
          </div>

          <div className="flex flex-col gap-3">
            <SectionLabel>Rename Options</SectionLabel>
            <Input
              placeholder="Optional prefix (e.g. 2024-)"
              value={prefix}
              onChange={(e) => setPrefix(e.target.value)}
            />
          </div>

          <div className="flex flex-col gap-2">
            <SectionLabel>Files ({session.scannedFiles.length})</SectionLabel>
            <ResultsTable
              files={resultFiles}
              selectedPaths={session.selectedPaths}
              onSelectionChange={(paths) => updateSession({ selectedPaths: paths })}
              sortKey={sortKey}
              sortDir={sortDir}
              onSortChange={(k, d) => { setSortKey(k); setSortDir(d); }}
              emptyTitle="No videos scanned"
              emptyDescription="Drop a folder or select files to get started."
            />
          </div>

          <div className="flex items-center gap-4 pt-2 border-t border-separator">
            <Button
              variant="accent"
              size="large"
              onClick={() => renameMutation.mutate()}
              disabled={!hasFiles || renameMutation.isPending}
            >
              <PlayIcon className="size-4" />
              {renameMutation.isPending ? "Renaming…" : "Rename"}
            </Button>
            <DryRunToggle checked={dryRun} onCheckedChange={setDryRun} />
          </div>
        </>
      )}
    </ToolPage>
  );
}
