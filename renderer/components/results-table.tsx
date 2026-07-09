import React, { useCallback, useEffect, useState } from "react";
import {
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
  Badge,
  EmptyState,
  Text,
} from "@electron-core/components";
import { ChevronDownIcon, ChevronRightIcon, ImageIcon } from "lucide-react";
import { cn } from "@electron-core/utils";
import type { VideoInfo } from "../main/types";

export type SortKey = "name" | "resolutionClass" | "sizeBytes" | "codec" | "fps" | "creationTime";
export type SortDir = "asc" | "desc";

interface ResultsTableProps {
  files: VideoInfo[];
  selectedPaths: Set<string>;
  onSelectionChange: (paths: Set<string>) => void;
  sortKey?: SortKey;
  sortDir?: SortDir;
  onSortChange?: (key: SortKey, dir: SortDir) => void;
  emptyTitle?: string;
  emptyDescription?: string;
  /** Additional action elements rendered above the table (e.g. Export CSV, Delete Selected) */
  actions?: React.ReactNode;
}

const TOTAL_COLUMNS = 13;

function formatSize(bytes: number): string {
  if (bytes >= 1_073_741_824) return `${(bytes / 1_073_741_824).toFixed(1)} GB`;
  if (bytes >= 1_048_576) return `${(bytes / 1_048_576).toFixed(1)} MB`;
  return `${(bytes / 1024).toFixed(0)} KB`;
}

function formatDuration(sec: number | null): string {
  if (sec === null) return "—";
  const m = Math.floor(sec / 60);
  const s = Math.floor(sec % 60);
  return `${m}:${String(s).padStart(2, "0")}`;
}

/** Device concept: iPhone when Apple, otherwise Other Device. */
function deviceLabel(file: VideoInfo): string {
  if (file.isApple) return "iPhone";
  return "Other Device";
}

/** Camera-direction concept: separate from Device, backed by cameraFront/cameraBack. */
function cameraTypeLabel(file: VideoInfo): string {
  if (file.cameraFront && file.cameraBack) return "Front & Back";
  if (file.cameraBack) return "Back Camera";
  if (file.cameraFront) return "Front Camera";
  return "No Camera";
}

function compare(a: VideoInfo, b: VideoInfo, key: SortKey, dir: SortDir): number {
  let va: number | string | null = null;
  let vb: number | string | null = null;
  switch (key) {
    case "name": va = a.name; vb = b.name; break;
    case "resolutionClass": va = a.resolutionClass; vb = b.resolutionClass; break;
    case "sizeBytes": va = a.sizeBytes; vb = b.sizeBytes; break;
    case "codec": va = a.codec; vb = b.codec; break;
    case "fps": va = a.fps; vb = b.fps; break;
    case "creationTime": va = a.creationTime; vb = b.creationTime; break;
  }
  if (va === null && vb === null) return 0;
  if (va === null) return 1;
  if (vb === null) return -1;
  const result = va < vb ? -1 : va > vb ? 1 : 0;
  return dir === "asc" ? result : -result;
}

/**
 * Thumbnail cell: lazy-fetches a thumbnail for `path` via the `thumbnail:get`
 * IPC channel on mount, reporting the resolved URL (or `null` on failure) up
 * to the shared cache in `ResultsTable`. Shows a neutral placeholder until
 * the fetch resolves or fails.
 */
function ThumbnailCell({
  path,
  cachedUrl,
  onResolved,
}: {
  path: string;
  cachedUrl: string | null | undefined;
  onResolved: (path: string, url: string | null) => void;
}) {
  useEffect(() => {
    if (cachedUrl !== undefined) return; // already fetched (resolved or failed)
    let cancelled = false;
    console.log("[ResultsTable:thumbnail:get]", { path });
    window.electronAPI.app.ipc
      .invoke<{ url: string | null }>("thumbnail:get", { path })
      .then((res) => {
        if (!cancelled) onResolved(path, res.url);
      })
      .catch((err) => {
        console.log("[ResultsTable:thumbnail:error]", { path, err });
        if (!cancelled) onResolved(path, null);
      });
    return () => {
      cancelled = true;
    };
  }, [path, cachedUrl, onResolved]);

  if (cachedUrl) {
    return (
      <img
        src={cachedUrl}
        alt=""
        className="size-10 rounded-md object-cover bg-well shrink-0"
      />
    );
  }

  return (
    <div className="size-10 rounded-md bg-well flex items-center justify-center shrink-0">
      <ImageIcon className="size-4 text-tertiary" />
    </div>
  );
}

export function ResultsTable({
  files,
  selectedPaths,
  onSelectionChange,
  sortKey = "name",
  sortDir = "asc",
  onSortChange,
  emptyTitle = "No videos scanned",
  emptyDescription = "Drop a folder or select files to get started.",
  actions,
}: ResultsTableProps) {
  const [expandedErrors, setExpandedErrors] = useState<Set<string>>(new Set());
  const [thumbUrls, setThumbUrls] = useState<Record<string, string | null | undefined>>({});

  const handleThumbResolved = useCallback((path: string, url: string | null) => {
    setThumbUrls((prev) => ({ ...prev, [path]: url }));
  }, []);

  const sorted = [...files].sort((a, b) => compare(a, b, sortKey, sortDir));

  const toggleSelect = (path: string) => {
    const next = new Set(selectedPaths);
    if (next.has(path)) next.delete(path);
    else next.add(path);
    onSelectionChange(next);
  };

  const toggleSelectAll = () => {
    if (selectedPaths.size === files.length) {
      onSelectionChange(new Set());
    } else {
      onSelectionChange(new Set(files.map((f) => f.path)));
    }
  };

  const toggleError = (path: string) => {
    setExpandedErrors((prev) => {
      const next = new Set(prev);
      if (next.has(path)) next.delete(path);
      else next.add(path);
      return next;
    });
  };

  const handleSort = (key: SortKey) => {
    if (!onSortChange) return;
    if (key === sortKey) {
      onSortChange(key, sortDir === "asc" ? "desc" : "asc");
    } else {
      onSortChange(key, "asc");
    }
  };

  const SortableHead = ({ col, label }: { col: SortKey; label: string }) => (
    <TableHead
      onClick={() => handleSort(col)}
      className={cn("cursor-pointer select-none", onSortChange && "hover:text-primary")}
    >
      <span className="flex items-center gap-1">
        {label}
        {sortKey === col && (
          <span className="text-accent text-xs">{sortDir === "asc" ? "↑" : "↓"}</span>
        )}
      </span>
    </TableHead>
  );

  if (files.length === 0) {
    return (
      <EmptyState
        placement="inline"
        title={emptyTitle}
        description={emptyDescription}
      />
    );
  }

  return (
    <div className="flex flex-col gap-3">
      {actions && <div className="flex gap-2">{actions}</div>}
      <Table>
        <TableHeader sticky>
          <TableRow>
            <TableHead className="w-12">Thumb</TableHead>
            <TableHead className="w-8">
              <input
                type="checkbox"
                aria-label="Select all"
                checked={selectedPaths.size === files.length && files.length > 0}
                onChange={toggleSelectAll}
                className="accent-[var(--theme-accent)]"
              />
            </TableHead>
            <SortableHead col="name" label="Name" />
            <SortableHead col="resolutionClass" label="Resolution" />
            <SortableHead col="sizeBytes" label="Size" />
            <SortableHead col="codec" label="Codec" />
            <SortableHead col="fps" label="FPS" />
            <TableHead>Duration</TableHead>
            <TableHead>GPS</TableHead>
            <TableHead>Device</TableHead>
            <TableHead>Camera Type</TableHead>
            <TableHead>Screen REC</TableHead>
            <TableHead>Status</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {sorted.map((file) => {
            const isSelected = selectedPaths.has(file.path);
            const hasError = file.error !== null;
            const isExpanded = expandedErrors.has(file.path);

            return (
              <>
                <TableRow
                  key={file.path}
                  onClick={() => toggleSelect(file.path)}
                  className={cn("cursor-pointer", isSelected && "bg-accent/10")}
                >
                  <TableCell>
                    <ThumbnailCell
                      path={file.path}
                      cachedUrl={thumbUrls[file.path]}
                      onResolved={handleThumbResolved}
                    />
                  </TableCell>
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
                    <Text variant="small" truncate className="max-w-[220px]">
                      {file.name}
                    </Text>
                  </TableCell>
                  <TableCell>
                    <Text variant="small" color="secondary">{file.resolutionClass}</Text>
                  </TableCell>
                  <TableCell className="text-right tabular-nums">
                    <Text variant="small" color="secondary">{formatSize(file.sizeBytes)}</Text>
                  </TableCell>
                  <TableCell>
                    <Text variant="small" color="secondary">{file.codec ?? "—"}</Text>
                  </TableCell>
                  <TableCell className="text-right tabular-nums">
                    <Text variant="small" color="secondary">
                      {file.fps !== null ? `${file.fps}` : "—"}
                    </Text>
                  </TableCell>
                  <TableCell className="tabular-nums">
                    <Text variant="small" color="secondary">{formatDuration(file.durationSec)}</Text>
                  </TableCell>
                  <TableCell>
                    <Text variant="small" color="secondary">{file.hasGPS ? "Yes" : "No"}</Text>
                  </TableCell>
                  <TableCell>
                    <Text variant="small" color="secondary">{deviceLabel(file)}</Text>
                  </TableCell>
                  <TableCell>
                    <Text variant="small" color="secondary">{cameraTypeLabel(file)}</Text>
                  </TableCell>
                  <TableCell>
                    <Text variant="small" color="secondary">{file.isScreenRecording ? "Yes" : "No"}</Text>
                  </TableCell>
                  <TableCell>
                    {hasError ? (
                      <button
                        onClick={(e) => { e.stopPropagation(); toggleError(file.path); }}
                        className="flex items-center gap-1 cursor-pointer"
                        aria-label="Show error details"
                      >
                        <Badge color="red" size="small">Error</Badge>
                        {isExpanded
                          ? <ChevronDownIcon className="size-3.5 text-secondary" />
                          : <ChevronRightIcon className="size-3.5 text-secondary" />
                        }
                      </button>
                    ) : (
                      <Badge color="green" size="small">OK</Badge>
                    )}
                  </TableCell>
                </TableRow>
                {hasError && isExpanded && (
                  <TableRow key={`${file.path}-error`}>
                    <TableCell colSpan={TOTAL_COLUMNS} className="bg-well py-2 px-4">
                      <Text variant="small" color="red">{file.error}</Text>
                    </TableCell>
                  </TableRow>
                )}
              </>
            );
          })}
        </TableBody>
      </Table>
    </div>
  );
}
