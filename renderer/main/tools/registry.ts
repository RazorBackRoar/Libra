import type { ComponentType } from "react";
import {
  FolderSyncIcon,
  TagIcon,
  MonitorIcon,
  LayersIcon,
  MaximizeIcon,
  BookmarkIcon,
  ClockIcon,
  FastForwardIcon,
  MapPinIcon,
} from "lucide-react";
import type { SortMode } from "../types";

export type ToolCategory = "organize" | "rename" | "analyze" | "convert";

export interface ToolDefinition {
  id: string;
  title: string;
  description: string;
  icon: ComponentType<{ className?: string }>;
  category: ToolCategory;
}

/** The six Media Organizer sort modes, shown as cards on the home page. */
export interface MediaMode {
  mode: SortMode;
  title: string;
  description: string;
  icon: ComponentType<{ className?: string }>;
}

export const MEDIA_MODES: MediaMode[] = [
  { mode: "ProVid", title: "Pro Vid", description: "Rename in place with a custom prefix.", icon: TagIcon },
  { mode: "VidRes", title: "Vid Res", description: "Sort into resolution folders (4K, FHD, 1080p, HD, 720p, SD).", icon: MonitorIcon },
  { mode: "ProMax", title: "Pro Max", description: "Sort into resolution + orientation subfolders.", icon: LayersIcon },
  { mode: "MaxVid", title: "Max Vid", description: "Sort into resolution + orientation + FPS subfolders.", icon: MaximizeIcon },
  { mode: "KeepName", title: "Name Keeper", description: "Sort into resolution folders, keep original filenames.", icon: BookmarkIcon },
  { mode: "SlowMotion", title: "Slow Motion", description: "Detect and sort slow-motion clips.", icon: FastForwardIcon },
];

/** The Media Organizer workflow tool (single page; modes above select its behavior). */
export const MEDIA_ORGANIZER: ToolDefinition = {
  id: "media-organizer",
  title: "Video Organizer",
  description: "Scan, filter, and organize videos by resolution.",
  icon: FolderSyncIcon,
  category: "organize",
};

/** Utility tools shown as plain cards below the gold divider on the home page. */
export const UTILITY_TOOLS: ToolDefinition[] = [
  {
    id: "gps-sorter",
    title: "GPS Sorter",
    description: "Sort videos into GPS / No GPS folders from location metadata.",
    icon: MapPinIcon,
    category: "organize",
  },
  {
    id: "onemin-adjust",
    title: "One Minute Adjuster",
    description: "Re-stamp videos with sequential timestamps one minute apart.",
    icon: ClockIcon,
    category: "convert",
  },
];

/** All routable tools (for the /tool/$toolId dispatcher and title lookups). */
export const TOOL_REGISTRY: ToolDefinition[] = [MEDIA_ORGANIZER, ...UTILITY_TOOLS];

export function getToolById(id: string): ToolDefinition | undefined {
  return TOOL_REGISTRY.find((t) => t.id === id);
}
