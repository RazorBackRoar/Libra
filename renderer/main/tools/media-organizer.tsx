import { Button, Input, Text, toast } from "@electron-core/components";
import { cn } from "@electron-core/utils";
import { useMutation } from "@tanstack/react-query";
import { DownloadIcon, PlayIcon, Trash2Icon } from "lucide-react";
import { useCallback, useEffect, useId, useRef, useState } from "react";

import { CancelButton } from "../../components/cancel-button";
import { DropZone } from "../../components/drop-zone";
import { DryRunToggle } from "../../components/dry-run-toggle";
import { ProgressBar } from "../../components/progress-bar";
import { ResultsTable, type SortDir, type SortKey } from "../../components/results-table";
import { ScanSummary, type ScanSummaryPill } from "../../components/scan-summary";
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
import { fpsBucket } from "../types";

// ── Title / subtitle per mode (shown centered at the top of the page) ──────────

const MODE_LABELS: Record<SortMode, { title: string; subtitle: string }> = {
  ProVid: { title: "Pro Vid", subtitle: "Prefix Rename Videos" },
  VidRes: { title: "Vid Res", subtitle: "Sort by Resolution" },
  ProMax: { title: "Pro Max", subtitle: "Resolution + Orientation" },
  MaxVid: { title: "Max Vid", subtitle: "Resolution + Orientation + FPS" },
  KeepName: { title: "Name Keeper", subtitle: "Sort by Resolution, Keep Names" },
  SlowMotion: { title: "Slo-Mo", subtitle: "Slow Down Videos" },
};

// ── Scan Summary — the filter system (spec §4/§5), AND-combinable ─────────────

interface ScanSummaryDef {
  id: string;
  label: string;
  predicate: (f: VideoInfo) => boolean;
}

/** Scan Summary filters in three fixed rows (spec). Every bubble is a
 *  combinable AND filter; "Total Videos" is a separate count-only element. */
const SCAN_SUMMARY_ROWS: ScanSummaryDef[][] = [
  [
    { id: "4K", label: "4K", predicate: (f) => f.resolutionClass === "4K" },
    { id: "FHD", label: "FHD", predicate: (f) => f.resolutionClass === "FHD" },
    { id: "1080p", label: "1080p", predicate: (f) => f.resolutionClass === "1080p" },
    { id: "HD", label: "HD", predicate: (f) => f.resolutionClass === "HD" },
    { id: "720p", label: "720p", predicate: (f) => f.resolutionClass === "720p" },
    { id: "SD", label: "SD", predicate: (f) => f.resolutionClass === "SD" },
    { id: "iPhone", label: "iPhone", predicate: (f) => f.isApple },
    { id: "OtherDevice", label: "Other Device", predicate: (f) => !f.isApple },
  ],
  [
    { id: "V", label: "V", predicate: (f) => f.orientation === "portrait" },
    { id: "W", label: "W", predicate: (f) => f.orientation !== "portrait" },
    { id: "GPS", label: "GPS", predicate: (f) => f.hasGPS },
    { id: "NoGPS", label: "No GPS", predicate: (f) => !f.hasGPS },
    { id: "30fps", label: "30fps", predicate: (f) => fpsBucket(f.fps) === "30" },
    { id: "60fps", label: "60fps", predicate: (f) => fpsBucket(f.fps) === "60" },
    { id: "120fps", label: "120fps", predicate: (f) => fpsBucket(f.fps) === "120" },
    { id: "SubFPS", label: "Sub FPS", predicate: (f) => fpsBucket(f.fps) === "Sub" },
  ],
  [
    { id: "Camera", label: "Camera", predicate: (f) => f.hasCameraInfo },
    { id: "NoCamera", label: "No Camera", predicate: (f) => !f.hasCameraInfo },
    { id: "FrontCamera", label: "Front Camera", predicate: (f) => f.cameraFront },
    { id: "BackCamera", label: "Back Camera", predicate: (f) => f.cameraBack },
    { id: "ScreenRec", label: "Screen Recording", predicate: (f) => f.isScreenRecording },
  ],
];

const SCAN_SUMMARY_DEFS: ScanSummaryDef[] = SCAN_SUMMARY_ROWS.flat();

/** Opposite pairs — selecting one turns the other off (spec §7). */
const EXCLUSIVE_GROUPS: string[][] = [
  ["GPS", "NoGPS"],
  ["Camera", "NoCamera"],
];

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
    const unsub = window.electronAPI.app.ipc.onNotification("job:progress", (payload: unknown) => {
      const p = payload as JobProgress;
      if (p.jobId === jobId) setProgress(p);
    });
    return () => {
      if (typeof unsub === "function") unsub();
    };
  }, [jobId]);

  // ── Derived: scan summary pills + AND-filtered file list ──────────────────
  const files = session.scannedFiles;

  const pillsFor = (defs: ScanSummaryDef[]): ScanSummaryPill[] =>
    defs.map((d) => ({ id: d.id, label: d.label, count: files.filter(d.predicate).length }));

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

  // ── Scan mutation (auto-triggered on drop / mount) ────────────────────────
  const scanMutation = useMutation({
    mutationFn: async (paths: string[]) => {
      cancelledRef.current = false;
      setIsScanning(true);
      setProgress(null);
      setReport(null);
      console.log("[media-organizer:scan:start]", { jobId, paths });
      return invokeIpc<{ files: VideoInfo[]; cancelled: boolean }>("scan:start", {
        jobId,
        paths,
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

  // ── Auto-scan whenever the dropped paths change (drop or preload). ─────────
  const lastScannedRef = useRef<string>("");
  useEffect(() => {
    const sig = session.droppedPaths.join("\n");
    if (sig && sig !== lastScannedRef.current && !isScanning && !scanMutation.isPending) {
      lastScannedRef.current = sig;
      scanMutation.mutate(session.droppedPaths);
    }
  }, [session.droppedPaths]);

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
  const hasSelection = session.selectedPaths.size > 0;

  return (
    <ToolPage title={modeInfo.title}>
      {/* Centered mode title + subtitle (never the "L!bra" hero — that's home-only) */}
      <div className="flex flex-col items-center text-center gap-1.5 pt-1 pb-1">
        <h1 className="libra-page-title">{modeInfo.title}</h1>
        <Text variant="regular" color="secondary">
          {modeInfo.subtitle}
        </Text>
      </div>

      {/* Progress (scanning or processing) */}
      {(isScanning || processMutation.isPending) && progress && (
        <div className="flex flex-col gap-3">
          <ProgressBar progress={progress} />
          {isScanning && <CancelButton onCancel={() => void handleCancel()} />}
        </div>
      )}

      {/* ── Scan Summary box: filters + Rename Videos + actions + Process ── */}
      <div className="flex flex-col gap-4 rounded-card libra-panel p-4">
        <div className="flex flex-col gap-2">
          <SectionLabel>Scan Summary</SectionLabel>
          {SCAN_SUMMARY_ROWS.map((row, i) => (
            <ScanSummary
              key={i}
              pills={pillsFor(row)}
              activeIds={activeFilterIds}
              onChange={setActiveFilterIds}
              exclusiveGroups={EXCLUSIVE_GROUPS}
            />
          ))}
        </div>

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
          <Input
            className="flex-1 min-w-[160px]"
            placeholder={isKeepName ? "Renaming disabled" : "Rename Videos"}
            value={prefix}
            onChange={(e) => setPrefix(e.target.value)}
            disabled={isKeepName}
          />
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

        {/* Total Videos — count only, centered at the bottom (not a filter) */}
        <div className="flex justify-center">
          <span className="flex items-center gap-1.5 rounded-full bg-control px-3 py-1">
            <span className="text-accent text-[13px] font-semibold tabular-nums">{files.length}</span>
            <span className="text-primary text-[13px]">Total Videos</span>
          </span>
        </div>
      </div>

      {/* ── Main workspace: the drop area doubles as the results / finished-changes window ── */}
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
                  <ReportStat label="to MISC" value={report.counts.misc} />
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
                  emptyTitle="No videos scanned"
                  emptyDescription="Drop a folder or select files to get started."
                />
              </div>
            )}
          </div>
        ) : null}
      </DropZone>
    </ToolPage>
  );
}
