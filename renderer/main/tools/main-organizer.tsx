import { useCallback, useEffect, useId, useRef, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { Button, Input, Text, toast } from "@glaze/core/components";
import { PlayIcon, DownloadIcon, Trash2Icon } from "lucide-react";
import { cn } from "@glaze/core/utils";

import { ToolPage } from "../../components/tool-page";
import { DropZone } from "../../components/drop-zone";
import { ResultsTable, type SortKey, type SortDir } from "../../components/results-table";
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
  DuplicateGroup,
  FileOpResult,
  DeleteSummary,
} from "../types";

// ── Filter definitions ────────────────────────────────────────────────────────

const FILTER_DEFS: FilterPillDef[] = [
  { id: "4K", label: "4K" },
  { id: "1080p", label: "1080p" },
  { id: "720p", label: "720p" },
  { id: "SD", label: "SD" },
  { id: "GPS", label: "GPS" },
  { id: "iPhone", label: "iPhone" },
  { id: "Duplicates", label: "Duplicates" },
];

// ── IPC helpers ───────────────────────────────────────────────────────────────

async function invokeIpc<T>(channel: string, params: unknown): Promise<T> {
  return window.glazeAPI.glaze.ipc.invoke(channel, params) as Promise<T>;
}

// ── Main Organizer component ──────────────────────────────────────────────────

export function MainOrganizer() {
  const toolId = "main-organizer";
  const { session, updateSession } = useToolState(toolId);
  const jobId = useId();

  // ── Local state ──────────────────────────────────────────────────────────
  const [sortMode, setSortMode] = useState<SortMode>("VidRes");
  const [prefix, setPrefix] = useState("");
  const [dryRun, setDryRun] = useState(true);
  const [activeFilters, setActiveFilters] = useState<Record<string, boolean>>({});
  const [sortKey, setSortKey] = useState<SortKey>("name");
  const [sortDir, setSortDir] = useState<SortDir>("asc");
  const [progress, setProgress] = useState<JobProgress | null>(null);
  const [isScanning, setIsScanning] = useState(false);
  const [duplicateGroups, setDuplicateGroups] = useState<DuplicateGroup[]>([]);

  const cancelledRef = useRef(false);

  // ── Subscribe to job:progress notifications ──────────────────────────────
  useEffect(() => {
    const unsub = window.glazeAPI.glaze.ipc.onNotification(
      "job:progress",
      (payload: unknown) => {
        const p = payload as JobProgress;
        if (p.jobId === jobId) {
          setProgress(p);
          console.log("[MainOrganizer:progress]", p);
        }
      },
    );
    return () => {
      if (typeof unsub === "function") unsub();
    };
  }, [jobId]);

  // ── Derived: filtered file list ──────────────────────────────────────────
  const anyFilterActive = Object.values(activeFilters).some(Boolean);
  const duplicatePaths = new Set(
    duplicateGroups.flatMap((g) => g.files.map((f) => f.path)),
  );

  const filteredFiles = anyFilterActive
    ? session.scannedFiles.filter((f) => {
        if (activeFilters["4K"] && f.resolutionClass !== "4K") return false;
        if (activeFilters["1080p"] && f.resolutionClass !== "1080p") return false;
        if (activeFilters["720p"] && f.resolutionClass !== "720p") return false;
        if (activeFilters["SD"] && f.resolutionClass !== "SD") return false;
        if (activeFilters["GPS"] && !f.hasGPS) return false;
        if (activeFilters["iPhone"] && !f.isApple) return false;
        if (activeFilters["Duplicates"] && !duplicatePaths.has(f.path)) return false;
        return true;
      })
    : session.scannedFiles;

  // ── Count pills ──────────────────────────────────────────────────────────
  const countPills: CountPill[] = [
    { label: "Files", count: session.scannedFiles.length, color: "primary" },
    {
      label: "Duplicates",
      count: duplicatePaths.size,
      color: duplicatePaths.size > 0 ? "yellow" : "secondary",
    },
    {
      label: "GPS",
      count: session.scannedFiles.filter((f) => f.hasGPS).length,
      color: "blue",
    },
    {
      label: "iPhone",
      count: session.scannedFiles.filter((f) => f.isApple).length,
      color: "purple",
    },
    {
      label: "4K",
      count: session.scannedFiles.filter((f) => f.resolutionClass === "4K").length,
      color: "green",
    },
    {
      label: "1080p",
      count: session.scannedFiles.filter((f) => f.resolutionClass === "1080p").length,
      color: "secondary",
    },
    {
      label: "720p",
      count: session.scannedFiles.filter((f) => f.resolutionClass === "720p").length,
      color: "secondary",
    },
  ];

  // ── Handle paths from drop / dialog ─────────────────────────────────────
  const handlePaths = useCallback(
    (paths: string[]) => {
      console.log("[MainOrganizer:paths]", { count: paths.length });
      updateSession({ droppedPaths: paths, scannedFiles: [] });
      setDuplicateGroups([]);
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
      console.log("[MainOrganizer:scan:start]", { jobId, paths: session.droppedPaths });
      const result = await invokeIpc<{ files: VideoInfo[]; cancelled: boolean }>(
        "scan:start",
        { jobId, paths: session.droppedPaths },
      );
      return result;
    },
    onSuccess: async (result) => {
      setIsScanning(false);
      setProgress(null);
      updateSession({ scannedFiles: result.files, selectedPaths: new Set() });
      console.log("[MainOrganizer:scan:done]", { count: result.files.length, cancelled: result.cancelled });

      if (!result.cancelled) {
        // Auto-run duplicate detection
        console.log("[MainOrganizer:hash:start]", { jobId });
        try {
          const dupResult = await invokeIpc<{ groups: DuplicateGroup[]; cancelled: boolean }>(
            "hash:duplicates",
            { jobId, files: result.files },
          );
          setDuplicateGroups(dupResult.groups);
          console.log("[MainOrganizer:hash:done]", { groupCount: dupResult.groups.length });
        } catch (err) {
          console.log("[MainOrganizer:hash:error]", { err });
        }
      }
    },
    onError: (err) => {
      setIsScanning(false);
      setProgress(null);
      console.log("[MainOrganizer:scan:error]", { err });
      toast.error("Scan failed", { description: String(err) });
    },
  });

  // ── Cancel ───────────────────────────────────────────────────────────────
  const handleCancel = async () => {
    cancelledRef.current = true;
    console.log("[MainOrganizer:cancel]", { jobId });
    await invokeIpc("job:cancel", { jobId });
    setIsScanning(false);
    setProgress(null);
  };

  // ── Sort apply mutation ──────────────────────────────────────────────────
  const sortMutation = useMutation({
    mutationFn: async () => {
      console.log("[MainOrganizer:sort:start]", { mode: sortMode, dryRun, prefix });
      const result = await invokeIpc<{ results: FileOpResult[] }>("sort:apply", {
        mode: sortMode,
        files: filteredFiles,
        prefix: prefix || undefined,
        dryRun,
      });
      return result;
    },
    onSuccess: ({ results }) => {
      const suffixed = results.filter((r) => r.to && r.to.includes("("));
      if (suffixed.length > 0) {
        toast.info(`${suffixed.length} file${suffixed.length > 1 ? "s" : ""} renamed with auto-suffix to avoid collisions.`);
      }
      const errors = results.filter((r) => r.status === "error");
      if (errors.length > 0) {
        toast.error(`${errors.length} operation${errors.length > 1 ? "s" : ""} failed.`);
      } else if (dryRun) {
        toast.success("Dry run complete", { description: `${results.length} operations previewed.` });
      } else {
        toast.success("Sort applied", { description: `${results.length} files moved.` });
      }
      console.log("[MainOrganizer:sort:done]", { count: results.length, errors: errors.length });
    },
    onError: (err) => {
      console.log("[MainOrganizer:sort:error]", { err });
      toast.error("Sort failed", { description: String(err) });
    },
  });

  // ── Delete mutation ──────────────────────────────────────────────────────
  const deleteMutation = useMutation({
    mutationFn: async () => {
      const paths = [...session.selectedPaths];
      console.log("[MainOrganizer:delete:start]", { count: paths.length, dryRun });
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
        console.log("[MainOrganizer:delete:done]", {
          deleted: summary.deleted,
          failed: summary.failed,
        });
      }
    },
    onError: (err) => {
      console.log("[MainOrganizer:delete:error]", { err });
      toast.error("Delete failed", { description: String(err) });
    },
  });

  // ── CSV export ───────────────────────────────────────────────────────────
  const handleExportCsv = async () => {
    console.log("[MainOrganizer:csv:start]", { count: filteredFiles.length });
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
      console.log("[MainOrganizer:csv:done]");
    } catch (err) {
      console.log("[MainOrganizer:csv:error]", { err });
      toast.error("Export failed", { description: String(err) });
    }
  };

  // ── Render ───────────────────────────────────────────────────────────────

  const hasFiles = session.scannedFiles.length > 0;
  const hasPaths = session.droppedPaths.length > 0;
  const hasSelection = session.selectedPaths.size > 0;

  const tableActions = (
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

  return (
    <ToolPage title="Main Organizer" category="organize">
      <Text variant="regular" color="secondary">
        Filter, organize, review duplicates, and inspect rich video metadata.
      </Text>

      {/* Drop zone */}
      <DropZone
        onPaths={handlePaths}
        accept="both"
        disabled={isScanning}
        hint="Drag videos or a folder here"
      />

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
            Scan
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

      {/* Filters */}
      <div className="flex flex-col gap-2">
        <SectionLabel>Filter</SectionLabel>
        <FilterPills
          filters={FILTER_DEFS}
          active={activeFilters}
          onToggle={(id, val) => {
            console.log("[MainOrganizer:filter]", { id, val });
            setActiveFilters((prev) => ({ ...prev, [id]: val }));
          }}
        />
      </div>

      {/* Results table */}
      <div className="flex flex-col gap-2">
        <SectionLabel>
          Scanned Videos{" "}
          {hasFiles
            ? anyFilterActive
              ? `(${filteredFiles.length} of ${session.scannedFiles.length})`
              : `(${session.scannedFiles.length})`
            : ""}
        </SectionLabel>
        <ResultsTable
          files={filteredFiles}
          selectedPaths={session.selectedPaths}
          onSelectionChange={(paths) => updateSession({ selectedPaths: paths })}
          sortKey={sortKey}
          sortDir={sortDir}
          onSortChange={(k, d) => { setSortKey(k); setSortDir(d); }}
          emptyTitle={hasFiles ? "No videos match the current filters" : "No videos scanned yet"}
          emptyDescription={hasFiles ? "Try clearing some filters." : "Drop videos above or choose a folder to begin."}
          actions={tableActions}
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
    </ToolPage>
  );
}
