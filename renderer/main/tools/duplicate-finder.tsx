import { useCallback, useEffect, useId, useRef, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import {
  Button,
  Text,
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
  Badge,
  EmptyState,
  toast,
} from "@glaze/core/components";
import { PlayIcon, Trash2Icon } from "lucide-react";
import { cn } from "@glaze/core/utils";

import { ToolPage } from "../../components/tool-page";
import { DropZone } from "../../components/drop-zone";
import { CountPills, type CountPill } from "../../components/count-pills";
import { ProgressBar } from "../../components/progress-bar";
import { CancelButton } from "../../components/cancel-button";
import { SectionLabel } from "../../components/section-label";
import { useToolState } from "../tool-state";
import type { VideoInfo, DuplicateGroup, JobProgress, DeleteSummary } from "../types";

async function invokeIpc<T>(channel: string, params: unknown): Promise<T> {
  return window.glazeAPI.glaze.ipc.invoke(channel, params) as Promise<T>;
}

function formatSize(bytes: number): string {
  if (bytes >= 1_073_741_824) return `${(bytes / 1_073_741_824).toFixed(1)} GB`;
  if (bytes >= 1_048_576) return `${(bytes / 1_048_576).toFixed(1)} MB`;
  return `${(bytes / 1024).toFixed(0)} KB`;
}

export function DuplicateFinder() {
  const toolId = "duplicate-finder";
  const { session, updateSession } = useToolState(toolId);
  const jobId = useId();

  const [groups, setGroups] = useState<DuplicateGroup[]>([]);
  const [selectedPaths, setSelectedPaths] = useState<Set<string>>(new Set());
  const [progress, setProgress] = useState<JobProgress | null>(null);
  const [isRunning, setIsRunning] = useState(false);

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
      console.log("[duplicate-finder:paths]", { count: paths.length });
      updateSession({ droppedPaths: paths, scannedFiles: [] });
      setGroups([]);
      setSelectedPaths(new Set());
      setProgress(null);
    },
    [updateSession],
  );

  const findMutation = useMutation({
    mutationFn: async () => {
      cancelledRef.current = false;
      setIsRunning(true);
      setProgress(null);
      setGroups([]);
      setSelectedPaths(new Set());
      console.log("[duplicate-finder:hash:duplicates]", { jobId, paths: session.droppedPaths });
      const result = await invokeIpc<{ groups: DuplicateGroup[]; cancelled: boolean }>(
        "hash:duplicates",
        { jobId, paths: session.droppedPaths },
      );
      return result;
    },
    onSuccess: ({ groups: foundGroups, cancelled }) => {
      setIsRunning(false);
      setProgress(null);
      setGroups(foundGroups);
      if (cancelled) {
        toast.info("Operation cancelled.");
        return;
      }
      const totalDups = foundGroups.reduce((sum, g) => sum + g.files.length, 0);
      console.log("[duplicate-finder:hash:done]", { groups: foundGroups.length, totalDups });
      if (foundGroups.length === 0) {
        toast.success("No duplicates found", { description: "All files are unique." });
      } else {
        toast.info(`Found ${foundGroups.length} duplicate group${foundGroups.length > 1 ? "s" : ""}`, {
          description: `${totalDups} total duplicate files.`,
        });
      }
    },
    onError: (err) => {
      setIsRunning(false);
      setProgress(null);
      console.log("[duplicate-finder:hash:error]", { err });
      toast.error("Duplicate detection failed", { description: String(err) });
    },
  });

  const handleCancel = async () => {
    cancelledRef.current = true;
    console.log("[duplicate-finder:cancel]", { jobId });
    await invokeIpc("job:cancel", { jobId });
    setIsRunning(false);
    setProgress(null);
  };

  const deleteMutation = useMutation({
    mutationFn: async () => {
      const paths = [...selectedPaths];
      console.log("[duplicate-finder:files:delete]", { count: paths.length });
      const result = await invokeIpc<DeleteSummary>("files:delete", { paths, dryRun: false });
      return result;
    },
    onSuccess: (summary) => {
      const msg = summary.failed > 0
        ? `${summary.deleted} deleted, ${summary.failed} failed — view details`
        : `${summary.deleted} file${summary.deleted !== 1 ? "s" : ""} deleted`;
      if (summary.failed > 0) {
        toast.error(msg);
      } else {
        toast.success(msg);
      }
      // Remove deleted files from groups
      const deletedPaths = new Set(
        summary.results.filter((r) => r.status === "ok").map((r) => r.path),
      );
      setGroups((prev) =>
        prev
          .map((g) => ({ ...g, files: g.files.filter((f) => !deletedPaths.has(f.path)) }))
          .filter((g) => g.files.length >= 2),
      );
      setSelectedPaths(new Set());
      console.log("[duplicate-finder:delete:done]", { deleted: summary.deleted, failed: summary.failed });
    },
    onError: (err) => {
      console.log("[duplicate-finder:delete:error]", { err });
      toast.error("Delete failed", { description: String(err) });
    },
  });

  const toggleSelect = (path: string) => {
    setSelectedPaths((prev) => {
      const next = new Set(prev);
      if (next.has(path)) next.delete(path);
      else next.add(path);
      return next;
    });
  };

  const toggleGroupSelect = (files: VideoInfo[]) => {
    const allSelected = files.every((f) => selectedPaths.has(f.path));
    setSelectedPaths((prev) => {
      const next = new Set(prev);
      if (allSelected) {
        files.forEach((f) => next.delete(f.path));
      } else {
        files.forEach((f) => next.add(f.path));
      }
      return next;
    });
  };

  const hasPaths = session.droppedPaths.length > 0;
  const hasGroups = groups.length > 0;
  const totalDuplicates = groups.reduce((sum, g) => sum + g.files.length, 0);
  const hasSelection = selectedPaths.size > 0;

  const countPills: CountPill[] = [
    { label: "Duplicate groups", count: groups.length, color: groups.length > 0 ? "yellow" : "secondary" },
    { label: "Duplicate files", count: totalDuplicates, color: totalDuplicates > 0 ? "orange" : "secondary" },
  ];

  return (
    <ToolPage title="Duplicate Finder" category="analyze">
      <Text variant="regular" color="secondary">
        Detect exact duplicate videos by MD5 hash. Drop folders, then find duplicates, select files to delete.
      </Text>

      <DropZone
        onPaths={handlePaths}
        accept="folders"
        disabled={isRunning}
        hint="Drag folders here to scan for duplicates"
      />

      {hasPaths && !isRunning && (
        <div className="flex items-center gap-3">
          <Button
            variant="accent"
            size="large"
            onClick={() => findMutation.mutate()}
            disabled={findMutation.isPending}
          >
            <PlayIcon className="size-4" />
            Find Duplicates
          </Button>
          <Text variant="small" color="tertiary">
            {session.droppedPaths.length} folder{session.droppedPaths.length !== 1 ? "s" : ""} queued
          </Text>
        </div>
      )}

      {isRunning && progress && (
        <div className="flex flex-col gap-3">
          <ProgressBar progress={progress} />
          <CancelButton onCancel={() => void handleCancel()} />
        </div>
      )}

      {(hasGroups || findMutation.isSuccess) && (
        <>
          <div className="flex flex-col gap-2">
            <SectionLabel>Results</SectionLabel>
            <CountPills pills={countPills} />
          </div>

          {hasGroups ? (
            <>
              <div className="flex flex-col gap-4">
                {groups.map((group, gi) => (
                  <div key={group.hash} className="flex flex-col gap-1">
                    <div className="flex items-center gap-2">
                      <Badge color="yellow" size="small">Exact MD5</Badge>
                      <Text variant="small" color="tertiary" className="font-mono">{group.hash.slice(0, 12)}…</Text>
                      <Text variant="small" color="tertiary">({group.files.length} files)</Text>
                    </div>
                    <Table>
                      <TableHeader>
                        <TableRow>
                          <TableHead className="w-8">
                            <input
                              type="checkbox"
                              aria-label={`Select all in group ${gi + 1}`}
                              checked={group.files.every((f) => selectedPaths.has(f.path))}
                              onChange={() => toggleGroupSelect(group.files)}
                              className="accent-[var(--theme-accent)]"
                            />
                          </TableHead>
                          <TableHead>Name</TableHead>
                          <TableHead>Path</TableHead>
                          <TableHead>Size</TableHead>
                          <TableHead>Resolution</TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {group.files.map((file) => {
                          const isSelected = selectedPaths.has(file.path);
                          return (
                            <TableRow
                              key={file.path}
                              onClick={() => toggleSelect(file.path)}
                              className={cn("cursor-pointer", isSelected && "bg-accent/10")}
                            >
                              <TableCell>
                                <input
                                  type="checkbox"
                                  aria-label={`Select ${file.name}`}
                                  checked={isSelected}
                                  onChange={() => toggleSelect(file.path)}
                                  onClick={(e) => e.stopPropagation()}
                                  className="accent-[var(--theme-accent)]"
                                />
                              </TableCell>
                              <TableCell>
                                <Text variant="small" truncate className="max-w-[200px]">{file.name}</Text>
                              </TableCell>
                              <TableCell>
                                <Text variant="small" color="tertiary" truncate className="max-w-[240px]">{file.dir}</Text>
                              </TableCell>
                              <TableCell className="tabular-nums">
                                <Text variant="small" color="secondary">{formatSize(file.sizeBytes)}</Text>
                              </TableCell>
                              <TableCell>
                                <Text variant="small" color="secondary">{file.resolutionClass}</Text>
                              </TableCell>
                            </TableRow>
                          );
                        })}
                      </TableBody>
                    </Table>
                  </div>
                ))}
              </div>

              <div className="flex items-center gap-4 pt-2 border-t border-separator">
                <Button
                  variant="filled"
                  size="large"
                  onClick={() => deleteMutation.mutate()}
                  disabled={!hasSelection || deleteMutation.isPending}
                  className={cn(hasSelection ? "text-support-red" : "")}
                >
                  <Trash2Icon className="size-4" />
                  {deleteMutation.isPending ? "Deleting…" : `Delete Selected (${selectedPaths.size})`}
                </Button>
              </div>
            </>
          ) : (
            <EmptyState
              placement="inline"
              title="No duplicates found"
              description="All scanned files are unique."
            />
          )}
        </>
      )}
    </ToolPage>
  );
}
