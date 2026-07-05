import React, { useCallback, useRef, useState, type ComponentType } from "react";
import { useNavigate } from "@tanstack/react-router";
import { ScrollArea, Text } from "@glaze/core/components";
import { cn } from "@glaze/core/utils";
import { FolderSyncIcon, SlidersHorizontalIcon, ChevronDownIcon } from "lucide-react";
import { useToolStateContext } from "./tool-state";
import { MEDIA_MODES, MISC_TOOLS } from "./tools/registry";
import type { SortMode } from "./types";

type IconType = ComponentType<{ className?: string }>;

// ── Drop-aware card (used for both media modes and misc tools) ─────────────────

interface DropCardProps {
  icon: IconType;
  title: string;
  description: string;
  onActivate: (paths: string[]) => void;
  /** Give the icon chip a permanent gold accent so primary modes stand out. */
  accent?: boolean;
}

function DropCard({ icon: Icon, title, description, onActivate, accent = false }: DropCardProps) {
  const [isDragOver, setIsDragOver] = useState(false);
  const dragCounter = useRef(0);

  const resolvePaths = (e: React.DragEvent): string[] => {
    const paths: string[] = [];
    for (let i = 0; i < e.dataTransfer.files.length; i++) {
      const file = e.dataTransfer.files[i];
      if (file) {
        const p = window.glazeAPI.webUtils.getPathForFile(file);
        if (p) paths.push(p);
      }
    }
    return paths;
  };

  const chipGold = accent || isDragOver;

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={() => onActivate([])}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") onActivate([]);
      }}
      onDragEnter={(e) => {
        e.preventDefault();
        e.stopPropagation();
        dragCounter.current++;
        if (dragCounter.current === 1) setIsDragOver(true);
      }}
      onDragLeave={(e) => {
        e.preventDefault();
        e.stopPropagation();
        dragCounter.current--;
        if (dragCounter.current === 0) setIsDragOver(false);
      }}
      onDragOver={(e) => {
        e.preventDefault();
        e.stopPropagation();
      }}
      onDrop={(e) => {
        e.preventDefault();
        e.stopPropagation();
        dragCounter.current = 0;
        setIsDragOver(false);
        const paths = resolvePaths(e);
        console.log("[HomeView:cardDrop]", { title, pathCount: paths.length });
        onActivate(paths);
      }}
      className={cn(
        "group flex items-center gap-3 rounded-card p-3.5 cursor-pointer select-none",
        "libra-mode-card",
        accent && "libra-mode-card-accent",
        isDragOver && "libra-gold-border libra-gold-glow libra-drop-bg",
      )}
    >
      <div
        className={cn(
          "size-9 shrink-0 rounded-control flex items-center justify-center transition-colors",
          chipGold ? "libra-gold-chip" : "bg-control group-hover:bg-control-active",
        )}
      >
        <Icon className={cn("size-4.5", chipGold ? "text-accent" : "text-secondary group-hover:text-primary")} />
      </div>
      <div className="flex flex-col min-w-0 flex-1">
        <Text variant="strong" color={isDragOver ? "accent" : "primary"} truncate>
          {isDragOver ? "Drop files here" : title}
        </Text>
        <Text variant="regular" color="secondary" className="line-clamp-1">
          {isDragOver ? "Files will be pre-loaded." : description}
        </Text>
      </div>
    </div>
  );
}

// ── Section box (optionally collapsible) ────────────────────────────────────────

function SectionBox({
  icon: Icon,
  title,
  subtitle,
  collapsible = false,
  defaultOpen = true,
  children,
}: {
  icon: IconType;
  title: string;
  subtitle: string;
  collapsible?: boolean;
  defaultOpen?: boolean;
  children: React.ReactNode;
}) {
  const [open, setOpen] = useState(defaultOpen);
  const expanded = collapsible ? open : true;

  const header = (
    <div className="flex items-center gap-3">
      <div className="libra-gold-chip size-10 rounded-control flex items-center justify-center shrink-0">
        <Icon className="size-5" />
      </div>
      <div className="flex flex-col min-w-0 flex-1">
        <Text variant="large-strong" color="primary">
          {title}
        </Text>
        <Text variant="small" color="secondary" truncate>
          {subtitle}
        </Text>
      </div>
      {collapsible && (
        <ChevronDownIcon
          className={cn("size-5 shrink-0 text-accent transition-transform", expanded ? "rotate-180" : "rotate-0")}
        />
      )}
    </div>
  );

  return (
    <section className="libra-box rounded-panel p-5 flex flex-col gap-4 self-start">
      {collapsible ? (
        <button
          type="button"
          onClick={() => setOpen((v) => !v)}
          aria-expanded={expanded}
          className="text-left cursor-pointer rounded-control focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/60"
        >
          {header}
        </button>
      ) : (
        header
      )}
      {expanded && <div className="flex flex-col gap-2.5">{children}</div>}
    </section>
  );
}

// ── Home view ─────────────────────────────────────────────────────────────────

export function HomeView() {
  const navigate = useNavigate();
  const { preloadPaths, updateSession } = useToolStateContext();
  const [windowDragOver, setWindowDragOver] = useState(false);
  const windowDragCounter = useRef(0);

  const openMediaMode = useCallback(
    (mode: SortMode, paths: string[]) => {
      console.log("[HomeView:openMediaMode]", { mode, pathCount: paths.length });
      updateSession("media-organizer", { options: { mode } });
      if (paths.length > 0) preloadPaths("media-organizer", paths);
      void navigate({ to: "/tool/$toolId", params: { toolId: "media-organizer" } });
    },
    [navigate, preloadPaths, updateSession],
  );

  const openTool = useCallback(
    (toolId: string, paths: string[]) => {
      console.log("[HomeView:openTool]", { toolId, pathCount: paths.length });
      if (paths.length > 0) preloadPaths(toolId, paths);
      void navigate({ to: "/tool/$toolId", params: { toolId } });
    },
    [navigate, preloadPaths],
  );

  return (
    <div
      className="h-full flex flex-col"
      onDragEnter={(e) => {
        e.preventDefault();
        windowDragCounter.current++;
        if (windowDragCounter.current === 1) setWindowDragOver(true);
      }}
      onDragLeave={(e) => {
        e.preventDefault();
        windowDragCounter.current--;
        if (windowDragCounter.current === 0) setWindowDragOver(false);
      }}
      onDragOver={(e) => e.preventDefault()}
      onDrop={(e) => {
        e.preventDefault();
        windowDragCounter.current = 0;
        setWindowDragOver(false);
      }}
    >
      {windowDragOver && (
        <div className="fixed inset-0 z-40 pointer-events-none border-2 libra-gold-border rounded-dialog m-1 libra-drop-bg" />
      )}

      <ScrollArea className="h-full">
        <div className="mx-auto w-full max-w-4xl px-8 pt-12 pb-10 flex flex-col gap-8">
          {/* Hero */}
          <div className="flex flex-col items-center text-center gap-1.5">
            <h1 className="libra-title">L!bra</h1>
            <p className="libra-subtitle">Professional Video Organizer</p>
            <Text variant="regular" color="tertiary" className="mt-2">
              Drop videos or folders onto any tool to get started instantly.
            </Text>
          </div>

          {/* Two main sections */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
            <SectionBox
              icon={FolderSyncIcon}
              title="Video Organizer"
              subtitle="Scan, organize, and sort videos by resolution."
            >
              {MEDIA_MODES.map((m) => (
                <DropCard
                  key={m.mode}
                  icon={m.icon}
                  title={m.title}
                  description={m.description}
                  accent
                  onActivate={(paths) => openMediaMode(m.mode, paths)}
                />
              ))}
            </SectionBox>

            <SectionBox
              icon={SlidersHorizontalIcon}
              title="Miscellaneous Organizer"
              subtitle="Extra utilities for timing, speed, and location."
              collapsible
              defaultOpen={false}
            >
              {MISC_TOOLS.map((t) => (
                <DropCard
                  key={t.id}
                  icon={t.icon}
                  title={t.title}
                  description={t.description}
                  onActivate={(paths) => openTool(t.id, paths)}
                />
              ))}
            </SectionBox>
          </div>
        </div>
      </ScrollArea>
    </div>
  );
}
