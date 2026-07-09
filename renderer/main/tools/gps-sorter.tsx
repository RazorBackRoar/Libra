import { useCallback, useEffect, useId, useRef, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { Button, Text, toast } from "@electron-core/components";
import { PlayIcon } from "lucide-react";

import { ToolPage } from "../../components/tool-page";
import { DropZone } from "../../components/drop-zone";
import { ResultsTable, type SortKey, type SortDir } from "../../components/results-table";
import { ScanSummary, type ScanSummaryPill } from "../../components/scan-summary";
import { DryRunToggle } from "../../components/dry-run-toggle";
import { ProgressBar } from "../../components/progress-bar";
import { CancelButton } from "../../components/cancel-button";
import { SectionLabel } from "../../components/section-label";
import { useToolState } from "../tool-state";
import type { VideoInfo, JobProgress, FileOpResult } from "../types";

async function invokeIpc<T>(channel: string, params: unknown): Promise<T> {
  return window.electronAPI.app.ipc.invoke(channel, params) as Promise<T>;
}

export function GpsSorter() {
  const toolId = "gps-sorter";
  const { session, updateSession } = useToolState(toolId);
  const jobId = useId();

  const [dryRun, setDryRun] = useState(true);
  const [activeFilterIds, setActiveFilterIds] = useState<Set<string>>(new Set());
  const [sortKey, setSortKey] = useState<SortKey>("name");
  const [sortDir, setSortDir] = useState<SortDir>("asc");
  const [progress, setProgress] = useState<JobProgress | null>(null);
  const [isScanning, setIsScanning] = useState(false);
  const [opResults, setOpResults] = useState<FileOpResult[]>([]);

  const cancelledRef = useRef(false);

  useEffect(() => {
    const unsub = window.electronAPI.app.ipc.onNotification(
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
      console.log("[gps-sorter:paths]", { count: paths.length });
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
      console.log("[gps-sorter:scan:start]", { jobId, paths: session.droppedPaths });
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
      setActiveFilterIds(new Set());
      console.log("[gps-sorter:scan:done]", { count: result.files.length });
    },
    onError: (err) => {
      setIsScanning(false);
      setProgress(null);
      console.log("[gps-sorter:scan:error]", { err });
      toast.error("Scan failed", { description: String(err) });
    },
  });

  const handleCancel = async () => {
    cancelledRef.current = true;
    console.log("[gps-sorter:cancel]", { jobId });
    await invokeIpc("job:cancel", { jobId });
    setIsScanning(false);
    setProgress(null);
  };

  const sortMutation = useMutation({
    mutationFn: async () => {
      const moves = session.scannedFiles
        .filter((f) => f.error === null)
        .map((f) => ({
          from: f.path,
          toDir: `${f.dir}/${f.hasGPS ? "GPS" : "No GPS"}`,
        }));
      console.log("[gps-sorter:files:move]", { count: moves.length, dryRun });
      const result = await invokeIpc<{ results: FileOpResult[] }>("files:move", {
        moves,
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
        toast.error(`${errors.length} move${errors.length > 1 ? "s" : ""} failed.`);
      } else {
        const gpsCount = session.scannedFiles.filter((f) => f.hasGPS && f.error === null).length;
        const noGpsCount = session.scannedFiles.filter((f) => !f.hasGPS && f.error === null).length;
        toast.success("Sort complete", {
          description: `${gpsCount} → GPS, ${noGpsCount} → No GPS.`,
        });
      }
      console.log("[gps-sorter:sort:done]", { count: results.length, errors: errors.length });
    },
    onError: (err) => {
      console.log("[gps-sorter:sort:error]", { err });
      toast.error("Sort failed", { description: String(err) });
    },
  });

  const hasFiles = session.scannedFiles.length > 0;
  const hasPaths = session.droppedPaths.length > 0;

  const files = session.scannedFiles;
  const gpsCount = files.filter((f) => f.hasGPS).length;
  const noGpsCount = files.filter((f) => !f.hasGPS).length;

  const scanSummaryPills: ScanSummaryPill[] = [
    { id: "total", label: "Total Videos", count: files.length },
    { id: "GPS", label: "GPS", count: gpsCount },
    { id: "NoGPS", label: "No GPS", count: noGpsCount },
  ];

  const activeDefs = [
    activeFilterIds.has("GPS") ? (f: VideoInfo) => f.hasGPS : null,
    activeFilterIds.has("NoGPS") ? (f: VideoInfo) => !f.hasGPS : null,
  ].filter((p): p is (f: VideoInfo) => boolean => p !== null);

  const filteredFiles = activeDefs.length > 0 ? files.filter((f) => activeDefs.every((p) => p(f))) : files;

  const displayFiles = opResults.length > 0
    ? filteredFiles.filter((f) => opResults.some((r) => r.from === f.path))
    : filteredFiles;

  return (
    <ToolPage title="GPS Hunter">
      {/* Centered title + subtitle */}
      <div className="flex flex-col items-center text-center gap-1.5 pt-1 pb-1">
        <h1 className="libra-page-title">GPS Hunter</h1>
        <Text variant="regular" color="secondary">
          Location Off or On Hunter
        </Text>
      </div>

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
          <div className="flex flex-col gap-2 rounded-card libra-panel p-3">
            <SectionLabel>Scan Summary</SectionLabel>
            <ScanSummary pills={scanSummaryPills} activeIds={activeFilterIds} onChange={setActiveFilterIds} />
          </div>

          <div className="flex flex-col gap-2">
            <SectionLabel>Files ({filteredFiles.length})</SectionLabel>
            <ResultsTable
              files={displayFiles}
              selectedPaths={session.selectedPaths}
              onSelectionChange={(paths) => updateSession({ selectedPaths: paths })}
              sortKey={sortKey}
              sortDir={sortDir}
              onSortChange={(k, d) => { setSortKey(k); setSortDir(d); }}
              emptyTitle="No videos scanned"
              emptyDescription="Drop a folder or select files to get started."
            />
          </div>

          <div className="flex items-center gap-4 pt-2 border-t libra-faint-border">
            <Button
              variant="accent"
              size="large"
              onClick={() => sortMutation.mutate()}
              disabled={!hasFiles || sortMutation.isPending}
            >
              <PlayIcon className="size-4" />
              {sortMutation.isPending ? "Sorting…" : "Sort into GPS Folders"}
            </Button>
            <DryRunToggle checked={dryRun} onCheckedChange={setDryRun} />
          </div>
        </>
      )}

      {/* Drop zone — always at the very bottom of the page */}
      <DropZone
        onPaths={handlePaths}
        accept="both"
        disabled={isScanning}
        hint="Drag videos or a folder here"
      />
    </ToolPage>
  );
}
