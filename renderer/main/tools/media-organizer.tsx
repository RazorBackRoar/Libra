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
import { SortSelect } from "../../components/sort-select";
import { DryRunToggle } from "../../components/dry-run-toggle";
import { ProgressBar } from "../../components/progress-bar";
import { CancelButton } from "../../components/cancel-button";
import { SectionLabel } from "../../components/section-label";
import { useToolState } from "../tool-state";
import type {
  VideoInfo,
  SortMode,
  JobProgress,
  FileOpResult,
  DeleteSummary,
  Settings,
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
];

// ── IPC helpers ───────────────────────────────────────────────────────────────

async function invokeIpc<T>(channel: string, params: unknown): Promise<T> {
  return window.glazeAPI.glaze.ipc.invoke(channel, params) as Promise<T>;
}

// ── Video Organizer component ─────────────────────────────────────────────────

export function MediaOrganizer() {
  const toolId = "media-organizer";
  const { session, updateSession } = useToolState(toolId);
  const jobId = useId();

  // ── Local state ──────────────────────────────────────────────────────────
  const presetMode = session.options.mode as SortMode | undefined;
  const [sortMode, setSortMode] = useState<SortMode>(presetMode ?? "ProVid");
  const [prefix, setPrefix] = useState("");
  const [dryRun, setDryRun] = useState(true);
  const [activeFilters, setActiveFilters] = useState<Record<string, boolean>>({});
  const [progress, setProgress] = useState<JobProgress | null>(null);
  const [isScanning, setIsScanning] = useState(false);
  const [outputFolder, setOutputFolder] = useState<string>("");
  const [lastRun, setLastRun] = useState<{ moved: number; failed: number; dryRun: boolean; destination: string } | null>(null);

  const cancelledRef = useRef(false);

  // ── Load persisted output folder ─────────────────────────────────────────
  useEffect(() => {
    invokeIpc<Settings>("settings:get", {})
      .then((s) => setOutputFolder(s.outputFolder))
      .catch((err) => console.log("[MediaOrganizer:settings:error]", { err }));
  }, []);

  // ── Apply a preset sort mode selected on the home screen ─────────────────
  useEffect(() => {
    if (presetMode) setSortMode(presetMode);
  }, [presetMode]);

  // ── Subscribe to job:progress notifications ──────────────────────────────
  useEffect(() => {
    const unsub = window.glazeAPI.glaze.ipc.onNotification(
      "job:progress",
      (payload: unknown) => {
        const p = payload as JobProgress;
        if (p.jobId === jobId) {
          setProgress(p);
          console.log("[MediaOrganizer:progress]", p);
        }
      },
    );
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
        return true;
      })
    : session.scannedFiles;

  // ── Count pills — useful video metadata only ─────────────────────────────
  const files = session.scannedFiles;
  const countPills: CountPill[] = [
    { label: "Files", count: files.length },
    { label: "GPS", count: files.filter((f) => f.hasGPS).length },
    { label: "iPhone", count: files.filter((f) => f.isApple).length },
    { label: "4K", count: files.filter((f) => f.resolutionClass === "4K").length },
    { label: "1080p", count: files.filter((f) => f.resolutionClass === "1080p").length },
    { label: "720p", count: files.filter((f) => f.resolutionClass === "720p").length },
    { label: "HD", count: files.filter((f) => f.resolutionClass === "HD").length },
    { label: "SD", count: files.filter((f) => f.resolutionClass === "SD").length },
  ];

  // ── Handle paths from drop / dialog ─────────────────────────────────────
  const handlePaths = useCallback(
    (paths: string[]) => {
      console.log("[MediaOrganizer:paths]", { count: paths.length });
      updateSession({ droppedPaths: paths, scannedFiles: [] });
      setProgress(null);
    },
    [updateSession],
  );

  // ── Scan mutation ────────────────────────────────────────────────────────
  const scanMutation = useMutation({
    mutationFn: async () => {
      cancelledRef.current = false;
      setIsScanning(true);
      setProgress(null);
      console.log("[MediaOrganizer:scan:start]", { jobId, paths: session.droppedPaths });
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
      console.log("[MediaOrganizer:scan:done]", { count: result.files.length, cancelled: result.cancelled });
    },
    onError: (err) => {
      setIsScanning(false);
      setProgress(null);
      console.log("[MediaOrganizer:scan:error]", { err });
      toast.error("Scan failed", { description: String(err) });
    },
  });

  // ── Cancel ───────────────────────────────────────────────────────────────
  const handleCancel = async () => {
    cancelledRef.current = true;
    console.log("[MediaOrganizer:cancel]", { jobId });
    await invokeIpc("job:cancel", { jobId });
    setIsScanning(false);
    setProgress(null);
  };

  // ── Sort apply mutation ──────────────────────────────────────────────────
  // ProVid renames in place; every other mode moves into the output folder.
  const sortsInPlace = sortMode === "ProVid";

  const sortMutation = useMutation({
    mutationFn: async () => {
      console.log("[MediaOrganizer:sort:start]", { mode: sortMode, dryRun, prefix, destRoot: sortsInPlace ? null : outputFolder });
      const result = await invokeIpc<{ results: FileOpResult[] }>("sort:apply", {
        mode: sortMode,
        files: filteredFiles,
        prefix: prefix || undefined,
        dryRun,
        destRoot: sortsInPlace ? undefined : outputFolder || undefined,
      });
      return result;
    },
    onSuccess: ({ results }) => {
      const suffixed = results.filter((r) => r.to && / \(\d+\)\./.test(r.to));
      if (suffixed.length > 0) {
        toast.info(`${suffixed.length} file${suffixed.length > 1 ? "s" : ""} auto-suffixed (1), (2)… to avoid overwriting.`);
      }
      const errors = results.filter((r) => r.status === "error");
      const moved = results.filter((r) => r.status === "ok" || r.status === "dryrun").length;
      setLastRun({
        moved,
        failed: errors.length,
        dryRun,
        destination: sortsInPlace ? "their original folders" : outputFolder,
      });
      if (errors.length > 0) {
        toast.error(`${errors.length} operation${errors.length > 1 ? "s" : ""} failed — see error rows.`);
      } else if (dryRun) {
        toast.success("Dry run complete", { description: `${results.length} operations previewed.` });
      } else {
        toast.success("Videos organized", {
          description: sortsInPlace ? `${moved} files renamed in place.` : `${moved} files moved to ${outputFolder}.`,
        });
      }
      console.log("[MediaOrganizer:sort:done]", { count: results.length, errors: errors.length });
    },
    onError: (err) => {
      console.log("[MediaOrganizer:sort:error]", { err });
      toast.error("Sort failed", { description: String(err) });
    },
  });

  // ── Delete mutation ──────────────────────────────────────────────────────
  const deleteMutation = useMutation({
    mutationFn: async () => {
      const paths = [...session.selectedPaths];
      console.log("[MediaOrganizer:delete:start]", { count: paths.length, dryRun });
      const result = await invokeIpc<DeleteSummary>("files:delete", { paths, dryRun });
      return result;
    },
    onSuccess: (summary) => {
      if (dryRun) {
        toast.success("Dry run: delete preview", {
          description: `Would delete ${summary.deleted} files.`,
        });
      } else {
        const msg =
          summary.failed > 0
            ? `${summary.deleted} deleted, ${summary.failed} failed`
            : `${summary.deleted} file${summary.deleted !== 1 ? "s" : ""} deleted`;
        toast.success(msg);
        // Remove deleted files from scan results
        const deletedPaths = new Set(
          summary.results.filter((r) => r.status === "ok").map((r) => r.path),
        );
        const remaining = session.scannedFiles.filter((f) => !deletedPaths.has(f.path));
        updateSession({ scannedFiles: remaining, selectedPaths: new Set() });
        console.log("[MediaOrganizer:delete:done]", {
          deleted: summary.deleted,
          failed: summary.failed,
        });
      }
    },
    onError: (err) => {
      console.log("[MediaOrganizer:delete:error]", { err });
      toast.error("Delete failed", { description: String(err) });
    },
  });

  // ── CSV export ───────────────────────────────────────────────────────────
  const handleExportCsv = async () => {
    console.log("[MediaOrganizer:csv:start]", { count: filteredFiles.length });
    const headers = ["Name", "Path", "Resolution", "Size (bytes)", "Codec", "FPS", "Duration (s)", "GPS", "iPhone", "Error"];
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
        f.error ?? "",
      ]),
    ];
    try {
      await invokeIpc("csv:export", { rows, suggestedName: "libra-organizer-export.csv" });
      console.log("[MediaOrganizer:csv:done]");
    } catch (err) {
      console.log("[MediaOrganizer:csv:error]", { err });
      toast.error("Export failed", { description: String(err) });
    }
  };

  // ── Change output folder ─────────────────────────────────────────────────
  const handleChangeOutputFolder = async () => {
    const res = await window.glazeAPI.dialog.showOpenDialog({
      properties: ["openDirectory", "createDirectory"],
      title: "Choose output folder",
    });
    if (res.canceled || res.filePaths.length === 0) return;
    const folder = res.filePaths[0];
    setOutputFolder(folder);
    await invokeIpc<Settings>("settings:set", { patch: { outputFolder: folder } });
    console.log("[MediaOrganizer:outputFolder]", { folder });
  };

  // ── Render ───────────────────────────────────────────────────────────────

  const hasFiles = session.scannedFiles.length > 0;
  const hasPaths = session.droppedPaths.length > 0;
  const hasSelection = session.selectedPaths.size > 0;

  const listActions = (
    <>
      <Button
        variant="filled"
        size="small"
        onClick={() => void handleExportCsv()}
        disabled={!hasFiles}
      >
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
              <Text variant="small" color="secondary">{listCount}</Text>
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
          <Button
            variant="accent"
            size="large"
            onClick={() => scanMutation.mutate()}
            disabled={scanMutation.isPending}
          >
            <PlayIcon className="size-4" />
            {hasFiles ? "Rescan" : "Scan"}
          </Button>
          <Text variant="small" color="tertiary">
            {session.droppedPaths.length} path{session.droppedPaths.length !== 1 ? "s" : ""} queued
          </Text>
        </div>
      )}

      {/* Progress during scan */}
      {isScanning && progress && (
        <div className="flex flex-col gap-3">
          <ProgressBar progress={progress} />
          <CancelButton onCancel={() => void handleCancel()} />
        </div>
      )}

      {/* Scan summary */}
      <div className="flex flex-col gap-2">
        <SectionLabel>Scan Summary</SectionLabel>
        <CountPills pills={countPills} />
      </div>

      {/* Sort mode + prefix */}
      <div className="flex flex-col gap-3">
        <SectionLabel>Sort Mode</SectionLabel>
        <SortSelect value={sortMode} onValueChange={setSortMode} />
        <Input
          placeholder="Optional prefix (e.g. Trip_2024_)"
          value={prefix}
          onChange={(e) => setPrefix(e.target.value)}
        />
      </div>

      {/* Destination — where processed files will go */}
      <div className="flex flex-col gap-2">
        <SectionLabel>Destination</SectionLabel>
        <div className="flex items-center gap-3 rounded-card border border-separator bg-well px-4 py-3">
          <FolderOpenIcon className="size-5 shrink-0 text-accent" />
          <div className="flex flex-col min-w-0 flex-1">
            {sortsInPlace ? (
              <>
                <Text variant="small-strong" color="primary">Renamed in place</Text>
                <Text variant="small" color="secondary" truncate>
                  Files stay in their original folders — only names change.
                </Text>
              </>
            ) : (
              <>
                <Text variant="small-strong" color="primary">Sorted into this folder</Text>
                <Text variant="small" color="secondary" truncate>
                  {outputFolder || "Resolving default output folder…"}
                </Text>
              </>
            )}
          </div>
          {!sortsInPlace && (
            <Button variant="filled" size="small" onClick={() => void handleChangeOutputFolder()}>
              Change…
            </Button>
          )}
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-col gap-2">
        <SectionLabel>Filter</SectionLabel>
        <FilterPills
          filters={FILTER_DEFS}
          active={activeFilters}
          onToggle={(id, val) => {
            console.log("[MediaOrganizer:filter]", { id, val });
            setActiveFilters((prev) => ({ ...prev, [id]: val }));
          }}
        />
      </div>

      {/* Bottom action bar */}
      <div className="flex items-center gap-4 pt-2 border-t border-separator">
        <Button
          variant="accent"
          size="large"
          onClick={() => sortMutation.mutate()}
          disabled={!hasFiles || sortMutation.isPending}
        >
          <PlayIcon className="size-4" />
          {sortMutation.isPending ? "Applying…" : "Apply Sort"}
        </Button>

        <DryRunToggle checked={dryRun} onCheckedChange={setDryRun} />

        {sortMutation.isPending && (
          <Text variant="small" color="tertiary">
            Processing…
          </Text>
        )}
      </div>

      {/* Post-processing result summary — restates the destination */}
      {lastRun && (
        <div className="flex flex-col gap-1 rounded-card border libra-gold-border libra-drop-bg px-4 py-3">
          <Text variant="small-strong" color="primary">
            {lastRun.dryRun
              ? `Dry run — ${lastRun.moved} operation${lastRun.moved !== 1 ? "s" : ""} previewed, no files changed.`
              : `${lastRun.moved} file${lastRun.moved !== 1 ? "s" : ""} organized${lastRun.failed > 0 ? `, ${lastRun.failed} failed` : ""}.`}
          </Text>
          <Text variant="small" color="secondary" truncate>
            {lastRun.dryRun ? "Would be placed in: " : "Location: "}
            {lastRun.destination}
          </Text>
        </div>
      )}
    </ToolPage>
  );
}
