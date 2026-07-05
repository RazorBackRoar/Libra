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
  { value: "ProVid", label: "Pro Vid", sublabel: "Rename in place with prefix" },
  { value: "VidRes", label: "Vid Res", sublabel: "Sort into resolution folders (4K, 1080p, 720p, HD, SD)" },
  { value: "ProMax", label: "Pro Max", sublabel: "Resolution + orientation subfolders" },
  { value: "MaxVid", label: "Max Vid", sublabel: "Resolution + orientation + FPS subfolders" },
  { value: "KeepName", label: "Name Keeper", sublabel: "Sort into folders, keep original filename" },
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
