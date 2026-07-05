import { Button } from "@glaze/core/components";
import { XIcon } from "lucide-react";
import { cn } from "@glaze/core/utils";

interface CancelButtonProps {
  onCancel: () => void;
  disabled?: boolean;
  className?: string;
}

export function CancelButton({ onCancel, disabled, className }: CancelButtonProps) {
  return (
    <Button
      variant="filled"
      size="medium"
      onClick={() => {
        console.log("[CancelButton:cancel]");
        onCancel();
      }}
      disabled={disabled}
      className={cn(className)}
    >
      <XIcon className="size-4" />
      Cancel
    </Button>
  );
}
