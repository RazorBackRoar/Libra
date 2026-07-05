import React, { useState } from "react";
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
} from "@glaze/core/components";
import { ChevronDownIcon, ChevronRightIcon } from "lucide-react";
import { cn } from "@glaze/core/utils";
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
                    <TableCell colSpan={8} className="bg-well py-2 px-4">
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
