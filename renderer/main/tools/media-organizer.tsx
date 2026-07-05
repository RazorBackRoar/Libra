import { useCallback, useEffect, useId, useRef, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { Button, Input, Text, toast } from "@glaze/core/components";
import { PlayIcon, DownloadIcon, Trash2Icon } from "lucide-react";
import { cn } from "@glaze/core/utils";

import { ToolPage } from "../../components/tool-page";
import { DropZone } from "../../components/drop-zone";
import { ResultsTable, type SortKey, type SortDir } from "../../components/results-table";
import { ScanSummary, type ScanSummaryPill } from "../../components/scan-summary";
import { DryRunToggle } from "../../components/dry-run-toggle";
import { ProgressBar } from "../../components/progress-bar";
import { CancelButton } from "../../components/cancel-button";
import { SectionLabel } from "../../components/section-label";
import { useToolState } from "../tool-state";
import type {
  VideoInfo,
  SortMode,
  JobProgress,
  DeleteSummary,
  ProcessReport,
} from "../types";

// ── Title / subtitle per mode (shown centered at the top of the page) ──────────

const MODE_LABELS: Record<SortMode, { title: string; subtitle: string }> = {
  ProVid: { title: "Pro Vid", subtitle: "Prefix Rename Videos" },
  VidRes: { title: "Vid Res", subtitle: "Sort by Resolution" },
  ProMax: { title: "Pro Max", subtitle: "Resolution + Orientation" },
  MaxVid: { title: "Max Vid", subtitle: "Resolution + Orientation + FPS" },
  KeepName: { title: "Name Keeper", subtitle: "Sort by Resolution, Keep Names" },
  SlowMotion: { title: "Slow Motion", subtitle: "Detect and Sort Slow-Motion Clips" },
};

// ── Scan Summary — 18 categories (CONTRACT.md §5), AND-combinable ──────────────

/** Frame-rate bucket used for the 30fps/60fps scan-summary pills. */
function frameRateLabel(fps: number | null): 30 | 60 {
  return fps !== null && fps > 45 ? 60 : 30;
}

interface ScanSummaryDef {
  id: string;
  label: string;
  predicate: (f: VideoInfo) => boolean;
}

const SCAN_SUMMARY_DEFS: ScanSummaryDef[] = [
  { id: "GPS", label: "GPS", predicate: (f) => f.hasGPS },
  { id: "NoGPS", label: "No GPS", predicate: (f) => !f.hasGPS },
  { id: "4K", label: "4K", predicate: (f) => f.resolutionClass === "4K" },
  { id: "FHD", label: "FHD", predicate: (f) => f.resolutionClass === "FHD" },
  { id: "1080p", label: "1080p", predicate: (f) => f.resolutionClass === "1080p" },
  { id: "HD", label: "HD", predicate: (f) => f.resolutionClass === "HD" },
  { id: "720p", label: "720p", predicate: (f) => f.resolutionClass === "720p" },
  { id: "SD", label: "SD", predicate: (f) => f.resolutionClass === "SD" },
  { id: "30fps", label: "30fps", predicate: (f) => frameRateLabel(f.fps) === 30 },
  { id: "60fps", label: "60fps", predicate: (f) => frameRateLabel(f.fps) === 60 },
  { id: "iPhone", label: "iPhone", predicate: (f) => f.isApple },
  { id: "MiscPhone", label: "Misc Phone", predicate: (f) => f.hasCameraInfo && !f.isApple },
  { id: "Camera", label: "Camera", predicate: (f) => f.cameraFront || f.cameraBack },
  { id: "FrontCamera", label: "Front Camera", predicate: (f) => f.cameraFront },
  { id: "BackCamera", label: "Back Camera", predicate: (f) => f.cameraBack },
  { id: "NoCamera", label: "No Camera", predicate: (f) => !f.cameraFront && !f.cameraBack },
  { id: "ScreenRec", label: "Screen REC", predicate: (f) => f.isScreenRecording },
];

// ── IPC helpers ───────────────────────────────────────────────────────────────

async function invokeIpc<T>(channel: string, params: unknown): Promise<T> {
  return window.glazeAPI.glaze.ipc.invoke(channel, params) as Promise<T>;
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

  // Mode is chosen on the mode-selection screen; default to Max Vid.
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
    const unsub = window.glazeAPI.glaze.ipc.onNotification("job:progress", (payload: unknown) => {
      const p = payload as JobProgress;
      if (p.jobId === jobId) setProgress(p);
    });
    return () => {
      if (typeof unsub === "function") unsub();
    };
  }, [jobId]);

  // ── Derived: scan summary pills + AND-filtered file list ──────────────────
  const files = session.scannedFiles;

  const scanSummaryPills: ScanSummaryPill[] = [
    { id: "total", label: "Total Videos", count: files.length },
    ...SCAN_SUMMARY_DEFS.map((d) => ({ id: d.id, label: d.label, count: files.filter(d.predicate).length })),
  ];

  const activeDefs = SCAN_SUMMARY_DEFS.filter((d) => activeFilterIds.has(d.id));
  const filteredFiles = activeDefs.length > 0 ? files.filter((f) => activeDefs.every((d) => d.predicate(f))) : files;

  // ── Handle paths from drop / dialog ─────────────────────────────────────
  const handlePaths = useCallback(
    (paths: string[]) => {
      console.log("[media-organizer:paths]", { count: paths.length });
      updateSession({ droppedPaths: paths, scannedFiles: [] });
      setProgress(null);
      setReport(null);
    },
    [updateSession],
  );

  // ── Scan mutation ────────────────────────────────────────────────────────
  const scanMutation = useMutation({
    mutationFn: async () => {
      cancelledRef.current = false;
      setIsScanning(true);
      setProgress(null);
      setReport(null);
      console.log("[media-organizer:scan:start]", { jobId, paths: session.droppedPaths });
      return invokeIpc<{ files: VideoInfo[]; cancelled: boolean }>("scan:start", {
        jobId,
        paths: session.droppedPaths,
      });
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
      const organizeFiles = filteredFiles.filter((f) => f.error === null);
      const unreadablePaths = session.scannedFiles.filter((f) => f.error !== null).map((f) => f.path);
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

  // ── Render ───────────────────────────────────────────────────────────────

  const hasFiles = session.scannedFiles.length > 0;
  const hasPaths = session.droppedPaths.length > 0;
  const hasSelection = session.selectedPaths.size > 0;
  const scannedEmpty = scanMutation.isSuccess && !isScanning && hasPaths && !hasFiles;

  const listActions = (
    <>
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
    </>
  );

  return (
    <ToolPage title={modeInfo.title}>
      {/* Centered mode title + subtitle (never the "L!bra" hero — that's home-only) */}
      <div className="flex flex-col items-center text-center gap-1.5 pt-1 pb-1">
        <h1 className="libra-page-title">{modeInfo.title}</h1>
        <Text variant="regular" color="secondary">
          {modeInfo.subtitle}
        </Text>
      </div>

      {/* Scan controls */}
      {hasPaths && !isScanning && (
        <div className="flex items-center gap-3">
          <Button variant="filled" size="large" onClick={() => scanMutation.mutate()} disabled={scanMutation.isPending}>
            <PlayIcon className="size-4" />
            {hasFiles ? "Rescan" : "Scan"}
          </Button>
          <Text variant="small" color="tertiary">
            {session.droppedPaths.length} path{session.droppedPaths.length !== 1 ? "s" : ""} queued
          </Text>
        </div>
      )}

      {/* Progress */}
      {(isScanning || processMutation.isPending) && progress && (
        <div className="flex flex-col gap-3">
          <ProgressBar progress={progress} />
          {isScanning && <CancelButton onCancel={() => void handleCancel()} />}
        </div>
      )}

      {/* Empty-result state */}
      {scannedEmpty && (
        <div className="rounded-card border border-separator bg-well px-4 py-6 text-center">
          <Text variant="regular" color="secondary">
            No recognized videos found in the dropped folder.
          </Text>
        </div>
      )}

      {hasFiles && (
        <>
          {/* Scan Summary */}
          <div className="flex flex-col gap-2">
            <SectionLabel>Scan Summary</SectionLabel>
            <ScanSummary pills={scanSummaryPills} activeIds={activeFilterIds} onChange={setActiveFilterIds} />
          </div>

          {/* Results table */}
          <div className="flex flex-col gap-2">
            <div className="flex items-center justify-between gap-3">
              <SectionLabel>Files ({filteredFiles.length})</SectionLabel>
              <div className="flex gap-2">{listActions}</div>
            </div>
            <ResultsTable
              files={filteredFiles}
              selectedPaths={session.selectedPaths}
              onSelectionChange={(paths) => updateSession({ selectedPaths: paths })}
              sortKey={sortKey}
              sortDir={sortDir}
              onSortChange={(k, d) => { setSortKey(k); setSortDir(d); }}
              emptyTitle="No videos scanned"
              emptyDescription="Drop a folder or select files to get started."
            />
          </div>

          {/* Name Videos prefix (left) + Process button (right), just above the drop zone */}
          <div className="flex items-end gap-4 pt-2 border-t border-separator">
            <div className="flex flex-col gap-2 flex-1 min-w-0">
              <SectionLabel>Name Videos</SectionLabel>
              <Input
                placeholder={isKeepName ? "Name Keeper never renames files" : "Optional prefix (e.g. Trip_2024_)"}
                value={prefix}
                onChange={(e) => setPrefix(e.target.value)}
                disabled={isKeepName}
              />
            </div>
            <div className="flex items-center gap-4 shrink-0">
              <DryRunToggle checked={dryRun} onCheckedChange={setDryRun} />
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
          </div>

          {/* Final report */}
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
                <ReportStat label="to MISC" value={report.counts.misc} />
                <ReportStat label="unreadable" value={report.counts.unreadable} />
                <ReportStat label="skipped" value={report.counts.skipped} />
                <ReportStat label="errors" value={report.counts.errors} />
              </div>
            </div>
          )}
        </>
      )}

      {/* Drop zone — always at the very bottom of the page */}
      <DropZone
        onPaths={handlePaths}
        accept="both"
        disabled={isScanning}
        hint={hasFiles ? "Drag videos or a folder here to add more" : "Drag videos or a folder here"}
      />
    </ToolPage>
  );
}
