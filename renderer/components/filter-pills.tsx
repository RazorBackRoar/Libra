import { ToggleButton, Text } from "@glaze/core/components";
import { cn } from "@glaze/core/utils";

export interface FilterPillDef {
  id: string;
  label: string;
}

interface FilterPillsProps {
  filters: FilterPillDef[];
  active: Record<string, boolean>;
  onToggle: (id: string, value: boolean) => void;
  className?: string;
}

export function FilterPills({ filters, active, onToggle, className }: FilterPillsProps) {
  return (
    <div className={cn("flex flex-wrap gap-2.5", className)}>
      {filters.map((f) => (
        <ToggleButton
          key={f.id}
          pressed={active[f.id] ?? false}
          onPressedChange={(pressed) => onToggle(f.id, pressed)}
          variant="filled"
          size="medium"
          radius="full"
        >
          <Text variant="regular">{f.label}</Text>
        </ToggleButton>
      ))}
    </div>
  );
}
