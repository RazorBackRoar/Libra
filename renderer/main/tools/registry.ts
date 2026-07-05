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

/** The five Media Organizer sort modes, shown as cards inside the Media box. */
export interface MediaMode {
  mode: SortMode;
  title: string;
  description: string;
  icon: ComponentType<{ className?: string }>;
}

export const MEDIA_MODES: MediaMode[] = [
  { mode: "ProVid", title: "Pro Vid", description: "Rename in place with a custom prefix.", icon: TagIcon },
  { mode: "VidRes", title: "Vid Res", description: "Sort into resolution folders (4K, 1080p, 720p, HD, SD).", icon: MonitorIcon },
  { mode: "ProMax", title: "Pro Max", description: "Sort into resolution + orientation subfolders.", icon: LayersIcon },
  { mode: "MaxVid", title: "Max Vid", description: "Sort into resolution + orientation + FPS subfolders.", icon: MaximizeIcon },
  { mode: "KeepName", title: "Name Keeper", description: "Sort into resolution folders, keep original filenames.", icon: BookmarkIcon },
];

/** The Media Organizer workflow tool (single page; modes above select its behavior). */
export const MEDIA_ORGANIZER: ToolDefinition = {
  id: "media-organizer",
  title: "Video Organizer",
  description: "Scan, filter, and organize videos by resolution.",
  icon: FolderSyncIcon,
  category: "organize",
};

/** Remaining smaller tools shown inside the Misc Organizer box. */
export const MISC_TOOLS: ToolDefinition[] = [
  {
    id: "slomo-creator",
    title: "Slo-Mo",
    description: "Create slow-motion copies at 0.5x or 0.25x speed.",
    icon: FastForwardIcon,
    category: "convert",
  },
  {
    id: "onemin-adjust",
    title: "Time Sequencer",
    description: "Re-stamp videos with sequential timestamps one minute apart.",
    icon: ClockIcon,
    category: "convert",
  },
  {
    id: "gps-sorter",
    title: "GPS Sorter",
    description: "Sort videos into GPS / No-GPS folders from location metadata.",
    icon: MapPinIcon,
    category: "organize",
  },
];

/** All routable tools (for the /tool/$toolId dispatcher and title lookups). */
export const TOOL_REGISTRY: ToolDefinition[] = [MEDIA_ORGANIZER, ...MISC_TOOLS];

export function getToolById(id: string): ToolDefinition | undefined {
  return TOOL_REGISTRY.find((t) => t.id === id);
}
