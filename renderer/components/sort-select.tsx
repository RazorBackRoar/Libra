import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from "@glaze/core/components";
import type { SortMode } from "../main/types";

interface SortSelectProps {
  value: SortMode;
  onValueChange: (value: SortMode) => void;
  className?: string;
}

const SORT_MODES: { value: SortMode; label: string; sublabel: string }[] = [
  { value: "ProVid", label: "ProVid", sublabel: "Rename in place with prefix" },
  { value: "VidRes", label: "VidRes", sublabel: "Sort into resolution folders" },
  { value: "ProMax", label: "ProMax", sublabel: "Resolution + orientation subfolders" },
  { value: "MaxVid", label: "MaxVid", sublabel: "Resolution + orientation + FPS subfolders" },
  { value: "KeepName", label: "KeepName", sublabel: "Sort into folders, keep filename" },
];

export function SortSelect({ value, onValueChange, className }: SortSelectProps) {
  return (
    <Select value={value} onValueChange={(v) => onValueChange(v as SortMode)}>
      <SelectTrigger variant="default" size="medium" className={className}>
        <SelectValue placeholder="Select sort mode" />
      </SelectTrigger>
      <SelectContent>
        {SORT_MODES.map((m) => (
          <SelectItem key={m.value} value={m.value} sublabel={m.sublabel}>
            {m.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
