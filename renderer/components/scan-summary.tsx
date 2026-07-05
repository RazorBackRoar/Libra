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
  /**
   * Mutually-exclusive filter groups. Activating any id in a group turns every
   * other id in the same group off (e.g. GPS / No GPS, Camera / No Camera).
   */
  exclusiveGroups?: string[][];
  className?: string;
}

/**
 * Shared scan-summary pill row — also the filter system. Every pill is a dark
 * bubble with a gold count + white label; the only accent is a thin gold border
 * when selected (never a solid gold fill). Pills combine via AND logic; the
 * `totalId` pill ("Total Videos") clears every active filter, and any
 * `exclusiveGroups` enforce opposite-pair behavior.
 */
export function ScanSummary({
  pills,
  activeIds,
  onChange,
  totalId = "total",
  exclusiveGroups = [],
  className,
}: ScanSummaryProps) {
  const handlePressedChange = (id: string) => {
    if (id === totalId) {
      console.log("[ScanSummary:clearAll]");
      onChange(new Set());
      return;
    }
    const next = new Set(activeIds);
    if (next.has(id)) {
      next.delete(id);
    } else {
      // Turn off any opposite pills in the same exclusive group first.
      for (const group of exclusiveGroups) {
        if (group.includes(id)) {
          for (const other of group) if (other !== id) next.delete(other);
        }
      }
      next.add(id);
    }
    console.log("[ScanSummary:toggle]", { id, active: next.has(id) });
    onChange(next);
  };

  return (
    <div className={cn("flex flex-wrap gap-2", className)}>
      {pills.map((pill) => {
        const pressed = pill.id === totalId ? activeIds.size === 0 : activeIds.has(pill.id);
        return (
          <button
            key={pill.id}
            type="button"
            aria-pressed={pressed}
            onClick={() => handlePressedChange(pill.id)}
            className={cn(
              "flex items-center gap-1.5 rounded-full border px-3 py-1 select-none cursor-pointer",
              "bg-control hover:bg-control-active transition-colors",
              pressed ? "libra-gold-border" : "border-transparent",
            )}
          >
            <span className="text-accent text-[13px] font-semibold tabular-nums">{pill.count}</span>
            <span className="text-primary text-[13px]">{pill.label}</span>
          </button>
        );
      })}
    </div>
  );
}
