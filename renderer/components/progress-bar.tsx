import { Text } from "@glaze/core/components";
import { cn } from "@glaze/core/utils";
import type { JobProgress } from "../main/types";

interface ProgressBarProps {
  progress: JobProgress;
  className?: string;
}

export function ProgressBar({ progress, className }: ProgressBarProps) {
  const percent = progress.total > 0 ? Math.round((progress.done / progress.total) * 100) : 0;

  return (
    <div className={cn("flex flex-col gap-1.5", className)}>
      <div className="flex items-center justify-between">
        <Text variant="small" color="secondary" className="capitalize">
          {progress.phase}…
        </Text>
        <Text variant="small" color="tertiary" className="tabular-nums">
          {progress.done} / {progress.total}
        </Text>
      </div>
      <div className="h-1.5 rounded-full bg-well overflow-hidden">
        <div
          className="h-full rounded-full bg-accent transition-all duration-200"
          style={{ width: `${percent}%` }}
        />
      </div>
    </div>
  );
}
