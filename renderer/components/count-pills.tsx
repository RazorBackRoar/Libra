import { Badge, Text } from "@glaze/core/components";
import { cn } from "@glaze/core/utils";

export interface CountPill {
  label: string;
  count: number;
  /** Retained for call-site compatibility; the badge is now rendered uniformly. */
  color?: "primary" | "secondary" | "blue" | "green" | "yellow" | "orange" | "red" | "purple" | "magenta";
}

interface CountPillsProps {
  pills: CountPill[];
  className?: string;
}

/**
 * Scan-summary counts. Every count bubble uses one uniform neutral color; the
 * label carries the gold accent so the summary reads clean and evenly spaced.
 */
export function CountPills({ pills, className }: CountPillsProps) {
  return (
    <div className={cn("grid grid-cols-4 gap-x-4 gap-y-3", className)}>
      {pills.map((pill) => (
        <div key={pill.label} className="flex items-center gap-2">
          <Badge color="secondary" size="medium">
            <span className="tabular-nums">{pill.count}</span>
          </Badge>
          <Text variant="small-strong" color="accent">
            {pill.label}
          </Text>
        </div>
      ))}
    </div>
  );
}
