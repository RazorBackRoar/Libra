import { cn } from "@electron-core/utils";

export interface FilterPillDef {
  id: string;
  label: string;
}

interface FilterPillsProps {
  filters: FilterPillDef[];
  active: Set<string>;
  onToggle: (id: string) => void;
  className?: string;
}

export function FilterPills({ filters, active, onToggle, className }: FilterPillsProps) {
  return (
    <div className={cn("flex flex-wrap gap-3", className)}>
      {filters.map((f) => {
        const pressed = active.has(f.id);
        return (
          <button
            key={f.id}
            type="button"
            aria-pressed={pressed}
            onClick={() => onToggle(f.id)}
            className={cn(
              "rounded-full border px-3 py-1.5 select-none cursor-pointer transition-colors",
              "text-[15px] font-medium text-primary",
              "bg-control hover:bg-control-active",
              pressed ? "libra-gold-border bg-control-active" : "border-transparent",
            )}
          >
            {f.label}
          </button>
        );
      })}
    </div>
  );
}
