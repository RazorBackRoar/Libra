import { ToggleButton, Text } from "@glaze/core/components";
import { cn } from "@glaze/core/utils";

export interface ScanSummaryPill {
  id: string;
  label: string;
  count: number;
}

interface ScanSummaryProps {
  pills: ScanSummaryPill[];
  /** Currently active (toggled-on) filter ids. Empty set == no filters == "Total Videos" active. */
  activeIds: Set<string>;
  onChange: (next: Set<string>) => void;
  /** Id of the pill that clears all active filters (defaults to "total"). */
  totalId?: string;
  className?: string;
}

/**
 * Shared scan-summary pill grid: each pill shows a gold count + white label,
 * is independently toggleable, and combines with other active pills via AND
 * logic. The `totalId` pill ("Total Videos") clears every active filter.
 */
export function ScanSummary({ pills, activeIds, onChange, totalId = "total", className }: ScanSummaryProps) {
  const handlePressedChange = (id: string) => {
    if (id === totalId) {
      console.log("[ScanSummary:clearAll]");
      onChange(new Set());
      return;
    }
    const next = new Set(activeIds);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    console.log("[ScanSummary:toggle]", { id, active: next.has(id) });
    onChange(next);
  };

  return (
    <div className={cn("flex flex-wrap gap-2", className)}>
      {pills.map((pill) => {
        const pressed = pill.id === totalId ? activeIds.size === 0 : activeIds.has(pill.id);
        return (
          <ToggleButton
            key={pill.id}
            pressed={pressed}
            onPressedChange={() => handlePressedChange(pill.id)}
            variant="filled"
            size="medium"
            radius="full"
          >
            <span className="flex items-center gap-1.5">
              <Text variant="small-strong" color="accent" className="tabular-nums">
                {pill.count}
              </Text>
              <Text variant="small" color="primary">
                {pill.label}
              </Text>
            </span>
          </ToggleButton>
        );
      })}
    </div>
  );
}
