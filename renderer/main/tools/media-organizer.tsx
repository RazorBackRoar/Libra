import { useCallback, useEffect, useId, useRef, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { Button, Input, Text, toast } from "@glaze/core/components";
import { PlayIcon, DownloadIcon, Trash2Icon, FolderOpenIcon } from "lucide-react";
import { cn } from "@glaze/core/utils";

import { ToolPage } from "../../components/tool-page";
import { DropZone } from "../../components/drop-zone";
import { VideoList } from "../../components/video-list";
import { CountPills, type CountPill } from "../../components/count-pills";
import { FilterPills, type FilterPillDef } from "../../components/filter-pills";
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

// ── Filter definitions ────────────────────────────────────────────────────────

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

const MODE_LABELS: Record<SortMode, string> = {
  ProVid: "Pro Vid — Prefix Rename",
  VidRes: "Vid Res — Resolution Sort",
  ProMax: "Pro Max — Resolution + Orientation",
  MaxVid: "Max Vid — Full Sort",
  KeepName: "Name Keeper — Keep Names",
};

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

  const [prefix, setPrefix] = useState("");
  const [dryRun, setDryRun] = useState(false);
  const [activeFilters, setActiveFilters] = useState<Record<string, boolean>>({});
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

  // ── Derived: filtered file list ──────────────────────────────────────────
  const anyFilterActive = Object.values(activeFilters).some(Boolean);

  const filteredFiles = anyFilterActive
    ? session.scannedFiles.filter((f) => {
        if (activeFilters["4K"] && f.resolutionClass !== "4K") return false;
        if (activeFilters["1080p"] && f.resolutionClass !== "1080p") return false;
        if (activeFilters["720p"] && f.resolutionClass !== "720p") return false;
        if (activeFilters["HD"] && f.resolutionClass !== "HD") return false;
        if (activeFilters["SD"] && f.resolutionClass !== "SD") return false;
        if (activeFilters["GPS"] && !f.hasGPS) return false;
        if (activeFilters["iPhone"] && !f.isApple) return false;
        if (activeFilters["Camera"] && !f.hasCameraInfo) return false;
        return true;
      })
    : session.scannedFiles;

  // ── Count pills — 9 stats, filled left-to-right then top-to-bottom ────────
  const files = session.scannedFiles;
  const countPills: CountPill[] = [
    { label: "Videos", count: files.length },
    { label: "iPhone", count: files.filter((f) => f.isApple).length },
    { label: "GPS", count: files.filter((f) => f.hasGPS).length },
    { label: "Camera", count: files.filter((f) => f.hasCameraInfo).length },
    { label: "4K", count: files.filter((f) => f.resolutionClass === "4K").length },
    { label: "HD", count: files.filter((f) => f.resolutionClass === "HD").length },
    { label: "1080p", count: files.filter((f) => f.resolutionClass === "1080p").length },
    { label: "SD", count: files.filter((f) => f.resolutionClass === "SD").length },
    { label: "720p", count: files.filter((f) => f.resolutionClass === "720p").length },
  ];

  // ── Handle paths from drop / dialog ─────────────────────────────────────
  const handlePaths = useCallback(
    (paths: string[]) => {
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
      return invokeIpc<{ files: VideoInfo[]; cancelled: boolean }>("scan:start", {
        jobId,
        paths: session.droppedPaths,
      });
    },
    onSuccess: (result) => {
      setIsScanning(false);
      setProgress(null);
      updateSession({ scannedFiles: result.files, selectedPaths: new Set() });
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

  const listCount = hasFiles
    ? anyFilterActive
      ? `${filteredFiles.length} of ${session.scannedFiles.length} videos`
      : `${session.scannedFiles.length} videos`
    : "";

  return (
    <ToolPage title="">
      {/* Centered branded header */}
      <div className="flex flex-col items-center text-center gap-2 pt-1 pb-1">
        <h1 className="libra-title">L!bra</h1>
        <Text variant="regular" color="secondary">
          Filter, organize, review, and inspect rich video metadata.
        </Text>
        <span className="mt-1 rounded-full border border-separator bg-well px-3 py-0.5">
          <Text variant="small-strong" color="accent">
            {MODE_LABELS[mode]}
          </Text>
        </span>
      </div>

      {/* Drop zone — also the scanned-video list area once files exist */}
      <DropZone
        onPaths={handlePaths}
        accept="both"
        disabled={isScanning}
        hint={hasFiles ? "Drag videos or a folder here to add more" : "Drag videos or a folder here"}
      >
        {hasFiles ? (
          <div className="flex flex-col gap-3">
            <div className="flex items-center justify-between gap-3">
              <Text variant="small" color="secondary">
                {listCount}
              </Text>
              <div className="flex gap-2">{listActions}</div>
            </div>
            <VideoList
              files={filteredFiles}
              selectedPaths={session.selectedPaths}
              onSelectionChange={(paths) => updateSession({ selectedPaths: paths })}
            />
          </div>
        ) : null}
      </DropZone>

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

      {/* Scan Summary (left) + controls (right) */}
      <div className="grid grid-cols-1 lg:grid-cols-[248px_1fr] gap-6 items-start">
        {/* Scan Summary sidebar */}
        <aside className="flex flex-col gap-3">
          <Text variant="large-strong" color="primary">
            Scan Summary
          </Text>
          <CountPills pills={countPills} cols={2} className="gap-y-2.5" />
        </aside>

        {/* Controls */}
        <div className="flex flex-col gap-5">
          {/* Name Videos */}
          <div className="flex flex-col gap-2">
            <SectionLabel>Name Videos</SectionLabel>
            <Input
              placeholder={isKeepName ? "Name Keeper never renames files" : "Optional prefix (e.g. Trip_2024_)"}
              value={prefix}
              onChange={(e) => setPrefix(e.target.value)}
              disabled={isKeepName}
            />
            <Text variant="small" color="tertiary">
              {isKeepName
                ? "This mode keeps original filenames — the prefix is ignored."
                : "Optional. Leave blank for no prefix."}
            </Text>
          </div>

          {/* Filters */}
          <div className="flex flex-col gap-2">
            <SectionLabel>Filter</SectionLabel>
            <FilterPills
              filters={FILTER_DEFS}
              active={activeFilters}
              onToggle={(id, val) => setActiveFilters((prev) => ({ ...prev, [id]: val }))}
            />
          </div>

          {/* Destination — always the dropped folder */}
          <div className="flex flex-col gap-2">
            <SectionLabel>Destination</SectionLabel>
            <div className="flex items-center gap-3 rounded-card border border-separator bg-well px-4 py-3">
              <FolderOpenIcon className="size-5 shrink-0 text-secondary" />
              <div className="flex flex-col min-w-0 flex-1">
                <Text variant="small-strong" color="primary">
                  The dropped folder
                </Text>
                <Text variant="small" color="secondary" truncate>
                  {report?.droppedRoot ?? "Files are organized inside the folder you drop — nothing leaves it."}
                </Text>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Process bar */}
      <div className="flex items-center justify-between gap-4 pt-3 border-t border-separator">
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
    </ToolPage>
  );
}
