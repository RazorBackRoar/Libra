import { Badge, Text } from "@glaze/core/components";
import { cn } from "@glaze/core/utils";

export interface CountPill {
  label: string;
  count: number;
  color?: "primary" | "secondary" | "blue" | "green" | "yellow" | "orange" | "red" | "purple" | "magenta";
}

interface CountPillsProps {
  pills: CountPill[];
  className?: string;
}

export function CountPills({ pills, className }: CountPillsProps) {
  return (
    <div className={cn("flex flex-wrap gap-2", className)}>
      {pills.map((pill) => (
        <div key={pill.label} className="flex items-center gap-1.5">
          <Badge color={pill.color ?? "secondary"} size="medium">
            <span className="tabular-nums">{pill.count}</span>
          </Badge>
          <Text variant="small" color="secondary">
            {pill.label}
          </Text>
        </div>
      ))}
    </div>
  );
}
