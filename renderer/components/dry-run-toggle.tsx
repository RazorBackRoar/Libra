import { Switch, Text } from "@glaze/core/components";
import { cn } from "@glaze/core/utils";

interface DryRunToggleProps {
  checked: boolean;
  onCheckedChange: (checked: boolean) => void;
  className?: string;
}

export function DryRunToggle({ checked, onCheckedChange, className }: DryRunToggleProps) {
  return (
    <div className={cn("flex items-center gap-3", className)}>
      <Text variant="small" color="secondary">
        Dry Run
      </Text>
      <Switch
        checked={checked}
        onCheckedChange={(val) => {
          console.log("[DryRunToggle:change]", { val });
          onCheckedChange(val);
        }}
      />
    </div>
  );
}
