import { Button, Input, Text, toast } from "@electron-core/components";
import { cn } from "@electron-core/utils";
import { useMutation } from "@tanstack/react-query";
import { DownloadIcon, PlayIcon, Trash2Icon } from "lucide-react";
import { useCallback, useEffect, useId, useRef, useState } from "react";

import { CancelButton } from "../../components/cancel-button";
import { DropZone } from "../../components/drop-zone";
import { DryRunToggle } from "../../components/dry-run-toggle";
import { FilterPills, type FilterPillDef } from "../../components/filter-pills";
import { ProgressBar } from "../../components/progress-bar";
import { ResultsTable, type SortDir, type SortKey } from "../../components/results-table";
import { StatGrid } from "../../components/scan-summary";
import { SectionLabel } from "../../components/section-label";
import { ToolPage } from "../../components/tool-page";
import { useToolState } from "../tool-state";
import type {
    DeleteSummary,
    JobProgress,
    ProcessReport,
    SortMode,
    VideoInfo,
} from "../types";

// ── Title / subtitle per mode (shown as the page category) ─────────────────────

const MODE_LABELS: Record<SortMode, { title: string; subtitle: string }> = {
  ProVid: { title: "Pro Vid", subtitle: "Prefix Rename" },
  VidRes: { title: "Vid Res", subtitle: "Resolution Sort" },
  ProMax: { title: "Pro Max", subtitle: "Resolution + Orientation Sort" },
  MaxVid: { title: "Max Vid", subtitle: "Full Sort" },
  KeepName: { title: "Name Keeper", subtitle: "Resolution + Keep Names" },
};

// ── Filter set (spec §3) ───────────────────────────────────────────────────────

const FILTER_DEFS: FilterPillDef[] = [
  { id: "4K", label: "4K" },
  { id: "1080p", label: "1080p" },
  { id: "720p", label: "720p" },
  { id: "HD", label: "HD" },
  { id: "SD", label: "SD" },
  { id: "GPS", label: "GPS" },
  { id: "iPhone", label: "iPhone" },
  { id: "Camera", label: "Camera" },
];

const FILTER_PREDICATES: Record<string, (f: VideoInfo) => boolean> = {
  "4K": (f) => f.resolutionClass === "4K",
  "1080p": (f) => f.resolutionClass === "1080p",
  "720p": (f) => f.resolutionClass === "720p",
  HD: (f) => f.resolutionClass === "HD",
  SD: (f) => f.resolutionClass === "SD",
  GPS: (f) => f.hasGPS,
  iPhone: (f) => f.isApple,
  Camera: (f) => f.hasCameraInfo,
};

// ── IPC helpers ───────────────────────────────────────────────────────────────

async function invokeIpc<T>(channel: string, params: unknown): Promise<T> {
  return window.electronAPI.app.ipc.invoke(channel, params) as Promise<T>;
}

function ReportStat({ label, value }: { label: string; value: number }) {
  return (
    <div className="flex items-center gap-1.5">
      <Text variant="small-strong" color="primary" className="tabular-nums">
        {value}
      </Text>
      <Text variant="small" color="secondary">
        {label}
      </Text>
    </div>
  );
}

// ── Processing screen ──────────────────────────────────────────────────────────

export function MediaOrganizer() {
  const toolId = "media-organizer";
  const { session, updateSession } = useToolState(toolId);
  const jobId = useId();

  const presetMode = session.options.mode as SortMode | undefined;
  const mode: SortMode = presetMode ?? "MaxVid";
  const isKeepName = mode === "KeepName";
  const modeInfo = MODE_LABELS[mode];

  const [prefix, setPrefix] = useState("");
  const [dryRun, setDryRun] = useState(false);
  const [activeFilterIds, setActiveFilterIds] = useState<Set<string>>(new Set());
  const [sortKey, setSortKey] = useState<SortKey>("name");
  const [sortDir, setSortDir] = useState<SortDir>("asc");
  const [progress, setProgress] = useState<JobProgress | null>(null);
  const [isScanning, setIsScanning] = useState(false);
  const [report, setReport] = useState<ProcessReport | null>(null);

  const cancelledRef = useRef(false);

  // ── Subscribe to job:progress notifications ──────────────────────────────
  useEffect(() => {
    const unsub = window.electronAPI.app.ipc.onNotification("job:progress", (payload: unknown) => {
      const p = payload as JobProgress;
      if (p.jobId === jobId) setProgress(p);
    });
    return () => {
      if (typeof unsub === "function") unsub();
    };
  }, [jobId]);

  // ── Derived state ────────────────────────────────────────────────────────
  const files = session.scannedFiles;
  const filteredFiles =
    activeFilterIds.size > 0
      ? files.filter((f) => [...activeFilterIds].every((id) => FILTER_PREDICATES[id]?.(f)))
      : files;

  const hasFiles = files.length > 0;
  const hasSelection = session.selectedPaths.size > 0;

  // ── Handle paths from drop / dialog ─────────────────────────────────────
  const handlePaths = useCallback(
    (paths: string[]) => {
      console.log("[media-organizer:paths]", { count: paths.length });
      updateSession({ droppedPaths: paths, scannedFiles: [] });
      setReport(null);
    },
    [updateSession],
  );

  // ── Scan mutation (auto-triggered on drop) ───────────────────────────────
  const scanMutation = useMutation({
    mutationFn: async (paths: string[]) => {
      cancelledRef.current = false;
      setIsScanning(true);
      setProgress(null);
      setReport(null);
      console.log("[media-organizer:scan:start]", { jobId, paths });
      return invokeIpc<{ files: VideoInfo[]; cancelled: boolean; skippedSymlinks: string[] }>(
        "scan:start",
        { jobId, paths },
      );
    },
    onSuccess: (result) => {
      setIsScanning(false);
      setProgress(null);
      updateSession({ scannedFiles: result.files, selectedPaths: new Set() });
      setActiveFilterIds(new Set());
      console.log("[media-organizer:scan:done]", { count: result.files.length });
    },
    onError: (err) => {
      setIsScanning(false);
      setProgress(null);
      toast.error("Scan failed", { description: String(err) });
    },
  });

  const lastScannedRef = useRef<string>("");
  useEffect(() => {
    const sig = session.droppedPaths.join("\n");
    if (sig && sig !== lastScannedRef.current && !isScanning && !scanMutation.isPending) {
      lastScannedRef.current = sig;
      scanMutation.mutate(session.droppedPaths);
    }
  }, [session.droppedPaths]);

  // ── Cancel ───────────────────────────────────────────────────────────────
  const handleCancel = async () => {
    cancelledRef.current = true;
    await invokeIpc("job:cancel", { jobId });
    setIsScanning(false);
    setProgress(null);
  };

  // ── Process mutation (full pipeline) ──────────────────────────────────────
  const processMutation = useMutation({
    mutationFn: async () => {
      const organizeFiles = files.filter((f) => f.error === null);
      const unreadablePaths = files.filter((f) => f.error !== null).map((f) => f.path);
      console.log("[media-organizer:process:run]", { jobId, mode, count: organizeFiles.length, dryRun });
      return invokeIpc<ProcessReport>("process:run", {
        jobId,
        mode,
        files: organizeFiles,
        unreadablePaths,
        droppedPaths: session.droppedPaths,
        prefix: isKeepName ? undefined : prefix || undefined,
        dryRun,
      });
    },
    onSuccess: (rep) => {
      setReport(rep);
      setProgress(null);
      if (rep.stopped) {
        toast.error("Run stopped early", { description: rep.stopped.reason });
      } else if (rep.counts.errors > 0) {
        toast.error(`${rep.counts.errors} operation${rep.counts.errors > 1 ? "s" : ""} failed — see report.`);
      } else if (rep.dryRun) {
        toast.success("Dry run complete", { description: "Preview only — no files changed." });
      } else {
        toast.success("Processing complete", {
          description: `${rep.counts.organized} organized · ${rep.counts.misc + rep.counts.unreadable} moved to MISC.`,
        });
      }
    },
    onError: (err) => {
      setProgress(null);
      toast.error("Processing failed", { description: String(err) });
    },
  });

  // ── Delete mutation ──────────────────────────────────────────────────────
  const deleteMutation = useMutation({
    mutationFn: async () => {
      const paths = [...session.selectedPaths];
      return invokeIpc<DeleteSummary>("files:delete", { paths, dryRun });
    },
    onSuccess: (summary) => {
      if (dryRun) {
        toast.success("Dry run: delete preview", { description: `Would delete ${summary.deleted} files.` });
      } else {
        const msg =
          summary.failed > 0
            ? `${summary.deleted} deleted, ${summary.failed} failed`
            : `${summary.deleted} file${summary.deleted !== 1 ? "s" : ""} deleted`;
        toast.success(msg);
        const deletedPaths = new Set(summary.results.filter((r) => r.status === "ok").map((r) => r.path));
        const remaining = session.scannedFiles.filter((f) => !deletedPaths.has(f.path));
        updateSession({ scannedFiles: remaining, selectedPaths: new Set() });
      }
    },
    onError: (err) => {
      toast.error("Delete failed", { description: String(err) });
    },
  });

  // ── CSV export ───────────────────────────────────────────────────────────
  const handleExportCsv = async () => {
    const headers = ["Name", "Path", "Resolution", "Size (bytes)", "Codec", "FPS", "Duration (s)", "GPS", "iPhone", "Camera", "Edited", "Error"];
    const rows: string[][] = [
      headers,
      ...filteredFiles.map((f) => [
        f.name,
        f.path,
        f.resolutionClass,
        String(f.sizeBytes),
        f.codec ?? "",
        f.fps !== null ? String(f.fps) : "",
        f.durationSec !== null ? String(f.durationSec) : "",
        f.hasGPS ? "Yes" : "No",
        f.isApple ? "Yes" : "No",
        f.hasCameraInfo ? "Yes" : "No",
        f.isEdited ? "Yes" : "No",
        f.error ?? "",
      ]),
    ];
    try {
      await invokeIpc("csv:export", { rows, suggestedName: "libra-export.csv" });
    } catch (err) {
      toast.error("Export failed", { description: String(err) });
    }
  };

  // ── Filter toggle ────────────────────────────────────────────────────────
  const toggleFilter = useCallback((id: string) => {
    setActiveFilterIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }, []);

  // ── Render ───────────────────────────────────────────────────────────────

  const destinationPath = report?.droppedRoot ?? session.droppedPaths[0] ?? "—";

  return (
    <ToolPage title="L!bra" category={modeInfo.title}>
      {/* Header */}
      <div className="flex flex-col items-center text-center gap-1.5 pt-1 pb-1">
        <h1 className="libra-page-title">L!bra</h1>
        <Text variant="regular" color="secondary">
          Filter, organize, review, and inspect rich video metadata.
        </Text>
      </div>

      {/* Progress */}
      {(isScanning || processMutation.isPending) && progress && (
        <div className="flex flex-col gap-3">
          <ProgressBar progress={progress} />
          {isScanning && <CancelButton onCancel={() => void handleCancel()} />}
        </div>
      )}

      <div className="flex flex-col lg:flex-row gap-4">
        {/* Left sidebar — scan summary + filters */}
        <div className="w-full lg:w-64 flex flex-col gap-4">
          <div className="flex flex-col gap-3 rounded-card libra-panel p-4">
            <SectionLabel className="text-[14px]">Scan Summary</SectionLabel>
            <StatGrid files={files} />
          </div>

          <div className="flex flex-col gap-3 rounded-card libra-panel p-4">
            <SectionLabel>Filters</SectionLabel>
            <FilterPills filters={FILTER_DEFS} active={activeFilterIds} onToggle={toggleFilter} />
          </div>
        </div>

        {/* Right main area */}
        <div className="flex-1 flex flex-col gap-4">
          {/* Secondary toolbar */}
          <div className="flex items-center gap-2 flex-wrap">
            <Button variant="filled" size="small" onClick={() => void handleExportCsv()} disabled={!hasFiles}>
              <DownloadIcon className="size-4" />
              Export CSV
            </Button>
            <Button
              variant="filled"
              size="small"
              onClick={() => deleteMutation.mutate()}
              disabled={!hasSelection || deleteMutation.isPending}
              className={cn(hasSelection ? "text-support-red" : "")}
            >
              <Trash2Icon className="size-4" />
              Delete Selected ({session.selectedPaths.size})
            </Button>
            <DryRunToggle checked={dryRun} onCheckedChange={setDryRun} />
          </div>

          {/* Drop zone / results */}
          <DropZone
            onPaths={handlePaths}
            accept="both"
            disabled={isScanning}
            className="min-h-[320px]"
            hint={hasFiles ? "Drag more videos or a folder here" : "Drag videos or a folder here"}
          >
            {(hasFiles || report) ? (
              <div className="flex flex-col gap-3">
                {report && (
                  <div className="flex flex-col gap-2 rounded-card border libra-gold-border libra-drop-bg px-4 py-3">
                    <Text variant="small-strong" color="primary">
                      {report.stopped
                        ? `Stopped early — ${report.stopped.reason}`
                        : report.dryRun
                          ? "Dry run — no files were changed."
                          : report.noVideos
                            ? "No videos to organize; non-video files moved to MISC where present."
                            : "Processing complete."}
                    </Text>
                    <Text variant="small" color="tertiary" truncate>
                      {report.droppedRoot}
                    </Text>
                    <div className="grid grid-cols-2 sm:grid-cols-3 gap-x-5 gap-y-1">
                      <ReportStat label="organized" value={report.counts.organized} />
                      <ReportStat label="duplicates" value={report.counts.duplicates} />
                      <ReportStat label="to MISC" value={report.counts.misc + report.counts.unreadable} />
                      <ReportStat label="unreadable" value={report.counts.unreadable} />
                      <ReportStat label="skipped" value={report.counts.skipped} />
                      <ReportStat label="errors" value={report.counts.errors} />
                    </div>
                  </div>
                )}
                {hasFiles && (
                  <div className="flex flex-col gap-2">
                    <SectionLabel>Results ({filteredFiles.length})</SectionLabel>
                    <ResultsTable
                      files={filteredFiles}
                      selectedPaths={session.selectedPaths}
                      onSelectionChange={(paths) => updateSession({ selectedPaths: paths })}
                      sortKey={sortKey}
                      sortDir={sortDir}
                      onSortChange={(k, d) => { setSortKey(k); setSortDir(d); }}
                      emptyTitle="No videos match the active filters"
                      emptyDescription="Clear filters to see all scanned videos."
                    />
                  </div>
                )}
              </div>
            ) : null}
          </DropZone>

          {/* Bottom action bar — destination + rename + process */}
          {hasFiles && (
            <div className="flex items-end gap-3 flex-wrap justify-end">
              <div className="flex flex-col gap-1 flex-1 min-w-[200px]">
                <SectionLabel>Destination</SectionLabel>
                <Text variant="small" color="secondary" truncate>
                  {destinationPath}
                </Text>
              </div>
              <Input
                className="flex-1 min-w-[160px]"
                placeholder={isKeepName ? "Renaming disabled" : "Name Videos"}
                value={prefix}
                onChange={(e) => setPrefix(e.target.value)}
                disabled={isKeepName}
              />
              <Button
                variant="accent"
                size="large"
                onClick={() => processMutation.mutate()}
                disabled={!hasFiles || processMutation.isPending}
              >
                <PlayIcon className="size-4" />
                {processMutation.isPending ? "Processing…" : "Process"}
              </Button>
            </div>
          )}
        </div>
      </div>
    </ToolPage>
  );
}
