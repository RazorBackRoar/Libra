import { Badge, Text } from "@glaze/core/components";
import { cn } from "@glaze/core/utils";
import type { VideoInfo } from "../main/types";

interface VideoListProps {
  files: VideoInfo[];
  selectedPaths: Set<string>;
  onSelectionChange: (paths: Set<string>) => void;
}

/** Builds the "30 fps · Apple · iPhone 14 Pro · GPS · iPhone" metadata line. */
function metaParts(file: VideoInfo): string[] {
  const parts: string[] = [];
  if (file.fps !== null) parts.push(`${file.fps} fps`);
  if (file.make) parts.push(file.make);
  if (file.model) parts.push(file.model);
  if (file.hasGPS) parts.push("GPS");
  if (file.isApple) parts.push("iPhone");
  return parts;
}

/**
 * Clean, readable list of scanned videos rendered directly inside the drop
 * panel. Each row shows filename, resolution label, frame rate, make, model,
 * and GPS / iPhone status. Rows are selectable for Delete / CSV actions.
 */
export function VideoList({ files, selectedPaths, onSelectionChange }: VideoListProps) {
  const allSelected = files.length > 0 && selectedPaths.size === files.length;

  const toggleSelect = (path: string) => {
    const next = new Set(selectedPaths);
    if (next.has(path)) next.delete(path);
    else next.add(path);
    onSelectionChange(next);
  };

  const toggleSelectAll = () => {
    if (allSelected) onSelectionChange(new Set());
    else onSelectionChange(new Set(files.map((f) => f.path)));
  };

  return (
    <div className="flex flex-col">
      <div className="flex items-center gap-2 pb-2">
        <input
          type="checkbox"
          aria-label="Select all"
          checked={allSelected}
          onChange={toggleSelectAll}
          className="accent-[var(--theme-accent)]"
        />
        <Text variant="small" color="tertiary">
          {selectedPaths.size > 0 ? `${selectedPaths.size} selected` : "Select all"}
        </Text>
      </div>

      <div className="flex flex-col divide-y divide-separator rounded-card border border-separator bg-well overflow-hidden">
        {files.map((file) => {
          const isSelected = selectedPaths.has(file.path);
          const hasError = file.error !== null;
          const parts = metaParts(file);

          return (
            <div
              key={file.path}
              onClick={() => toggleSelect(file.path)}
              className={cn(
                "flex items-center gap-3 px-3.5 py-2.5 cursor-pointer transition-colors",
                isSelected ? "bg-accent/10" : "hover:bg-control",
              )}
            >
              <input
                type="checkbox"
                aria-label={`Select ${file.name}`}
                checked={isSelected}
                onChange={() => toggleSelect(file.path)}
                onClick={(e) => e.stopPropagation()}
                className="accent-[var(--theme-accent)] shrink-0"
              />
              <div className="flex flex-col min-w-0 flex-1">
                <Text variant="small-strong" color="primary" truncate>
                  {file.name}
                </Text>
                {hasError ? (
                  <Text variant="small" color="red" truncate>
                    {file.error}
                  </Text>
                ) : parts.length > 0 ? (
                  <Text variant="small" color="secondary" truncate>
                    {parts.join(" · ")}
                  </Text>
                ) : null}
              </div>
              {hasError ? (
                <Badge color="red" size="small">
                  Error
                </Badge>
              ) : file.resolutionClass !== "Unknown" ? (
                <span className="libra-gold-chip rounded-full px-2.5 py-0.5 text-xs font-semibold shrink-0 tabular-nums">
                  {file.resolutionClass}
                </span>
              ) : null}
            </div>
          );
        })}
      </div>
    </div>
  );
}
