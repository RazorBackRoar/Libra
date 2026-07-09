import {
    BookmarkIcon,
    ClockIcon,
    FolderSyncIcon,
    GaugeIcon,
    LayersIcon,
    MapPinIcon,
    MaximizeIcon,
    MonitorIcon,
    TagIcon
} from "lucide-react";
import type { ComponentType } from "react";
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
  { mode: "ProVid", title: "Pro Vid", description: "Prefix Rename", icon: TagIcon },
  { mode: "VidRes", title: "Vid Res", description: "Resolution Sort", icon: MonitorIcon },
  { mode: "ProMax", title: "Pro Max", description: "Resolution + Orientation Sort", icon: LayersIcon },
  { mode: "MaxVid", title: "Max Vid", description: "Full Sort", icon: MaximizeIcon },
  { mode: "KeepName", title: "Name Keeper", description: "Resolution + Keep Names", icon: BookmarkIcon },
  { mode: "SlowMotion", title: "Slow Motion", description: "Slow Motion vs Normal Speed", icon: GaugeIcon },
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
    title: "GPS Hunter",
    description: "Location off or on hunter",
    icon: MapPinIcon,
    category: "organize",
  },
  {
    id: "onemin-adjust",
    title: "Divided by One",
    description: "Adjust videos by 1 min apart",
    icon: ClockIcon,
    category: "convert",
  },
];

/** All routable tools (for the /tool/$toolId dispatcher and title lookups). */
export const TOOL_REGISTRY: ToolDefinition[] = [MEDIA_ORGANIZER, ...UTILITY_TOOLS];

export function getToolById(id: string): ToolDefinition | undefined {
  return TOOL_REGISTRY.find((t) => t.id === id);
}
