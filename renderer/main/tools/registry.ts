import type { ComponentType } from "react";
import {
  FolderSyncIcon,
  TagIcon,
  MonitorIcon,
  LayersIcon,
  MaximizeIcon,
  BookmarkIcon,
  ScanIcon,
  ClockIcon,
  FastForwardIcon,
  CopyIcon,
  MapPinIcon,
  CodeIcon,
} from "lucide-react";

export type ToolCategory =
  | "organize"
  | "rename"
  | "analyze"
  | "convert";

export interface ToolDefinition {
  id: string;
  title: string;
  description: string;
  icon: ComponentType<{ className?: string }>;
  category: ToolCategory;
}

export const TOOL_REGISTRY: ToolDefinition[] = [
  {
    id: "main-organizer",
    title: "Main Organizer",
    description: "Filter, organize, review duplicates, and inspect rich video metadata.",
    icon: FolderSyncIcon,
    category: "organize",
  },
  {
    id: "provid-renamer",
    title: "ProVid Renamer",
    description: "Rename videos in place with a custom prefix, keeping folder structure.",
    icon: TagIcon,
    category: "rename",
  },
  {
    id: "vidres",
    title: "VidRes",
    description: "Sort videos into resolution folders (4K, 1080p, 720p, SD).",
    icon: MonitorIcon,
    category: "organize",
  },
  {
    id: "promax",
    title: "ProMax",
    description: "Sort into resolution + orientation subfolders.",
    icon: LayersIcon,
    category: "organize",
  },
  {
    id: "maxvid",
    title: "MaxVid",
    description: "Sort into resolution + orientation + FPS subfolders.",
    icon: MaximizeIcon,
    category: "organize",
  },
  {
    id: "keepname",
    title: "KeepName",
    description: "Sort into resolution folders without altering filenames.",
    icon: BookmarkIcon,
    category: "organize",
  },
  {
    id: "reencode-detector",
    title: "Re-encode Detector",
    description: "Flag videos not in preferred codec or container as re-encode candidates.",
    icon: ScanIcon,
    category: "analyze",
  },
  {
    id: "onemin-adjust",
    title: "1MinVid Adjust",
    description: "Assign sequential timestamps 60 seconds apart from a custom start time.",
    icon: ClockIcon,
    category: "convert",
  },
  {
    id: "slomo-creator",
    title: "Slo-Mo Creator",
    description: "Create slow-motion copies using ffmpeg setpts at 0.5x or 0.25x speed.",
    icon: FastForwardIcon,
    category: "convert",
  },
  {
    id: "duplicate-finder",
    title: "Duplicate Finder",
    description: "Detect exact duplicate videos by MD5 hash and manage them.",
    icon: CopyIcon,
    category: "analyze",
  },
  {
    id: "gps-sorter",
    title: "GPS Sorter",
    description: "Sort videos into GPS / No-GPS folders from embedded location metadata.",
    icon: MapPinIcon,
    category: "organize",
  },
  {
    id: "codec-checker",
    title: "Codec Checker",
    description: "Read-only ffprobe report: codec, container, resolution, fps, duration, size.",
    icon: CodeIcon,
    category: "analyze",
  },
];

export function getToolById(id: string): ToolDefinition | undefined {
  return TOOL_REGISTRY.find((t) => t.id === id);
}
