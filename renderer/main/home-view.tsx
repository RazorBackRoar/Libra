import React, { useCallback, useRef, useState } from "react";
import { useNavigate } from "@tanstack/react-router";
import { ScrollArea, Toolbar, ToolbarContent, ToolbarTitle, Text } from "@glaze/core/components";
import { cn } from "@glaze/core/utils";
import { useToolStateContext } from "./tool-state";
import { TOOL_REGISTRY, type ToolDefinition } from "./tools/registry";

declare const __APP_DISPLAY_NAME__: string | undefined;

// ── Tool card component ───────────────────────────────────────────────────────

interface ToolCardProps {
  tool: ToolDefinition;
  onNavigate: (toolId: string, paths: string[]) => void;
}

function ToolCard({ tool, onNavigate }: ToolCardProps) {
  const [isDragOver, setIsDragOver] = useState(false);
  const dragCounter = useRef(0);
  const Icon = tool.icon;

  const handleDragEnter = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    dragCounter.current++;
    if (dragCounter.current === 1) setIsDragOver(true);
  };

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    dragCounter.current--;
    if (dragCounter.current === 0) setIsDragOver(false);
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    dragCounter.current = 0;
    setIsDragOver(false);

    const paths: string[] = [];
    for (let i = 0; i < e.dataTransfer.files.length; i++) {
      const file = e.dataTransfer.files[i];
      if (file) {
        const p = window.glazeAPI.webUtils.getPathForFile(file);
        if (p) paths.push(p);
      }
    }
    console.log("[HomeView:cardDrop]", { toolId: tool.id, pathCount: paths.length });
    onNavigate(tool.id, paths);
  };

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={() => onNavigate(tool.id, [])}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") onNavigate(tool.id, []);
      }}
      onDragEnter={handleDragEnter}
      onDragLeave={handleDragLeave}
      onDragOver={handleDragOver}
      onDrop={handleDrop}
      className={cn(
        "group flex flex-col gap-3 p-5 rounded-card border border-separator cursor-pointer",
        "bg-well transition-all duration-150 select-none",
        "hover:border-separator hover:bg-control-subtle",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent",
        isDragOver
          ? "libra-gold-border libra-gold-glow libra-drop-bg"
          : "",
      )}
    >
      <div
        className={cn(
          "size-10 rounded-control flex items-center justify-center",
          "bg-control transition-colors",
          isDragOver ? "bg-accent/20" : "group-hover:bg-control-active",
        )}
      >
        <Icon
          className={cn(
            "size-5 transition-colors",
            isDragOver ? "text-accent" : "text-secondary group-hover:text-primary",
          )}
        />
      </div>

      <div className="flex flex-col gap-1 min-w-0">
        <Text variant="strong" color={isDragOver ? "accent" : "primary"} truncate>
          {isDragOver ? "Drop files here" : tool.title}
        </Text>
        <Text variant="small" color="secondary" className="line-clamp-2">
          {isDragOver ? "Files will be pre-loaded into this tool." : tool.description}
        </Text>
      </div>
    </div>
  );
}

// ── Home view ─────────────────────────────────────────────────────────────────

export function HomeView() {
  const navigate = useNavigate();
  const { preloadPaths } = useToolStateContext();
  const [windowDragOver, setWindowDragOver] = useState(false);
  const windowDragCounter = useRef(0);

  const handleNavigate = useCallback(
    (toolId: string, paths: string[]) => {
      console.log("[HomeView:navigate]", { toolId, pathCount: paths.length });
      if (paths.length > 0) {
        preloadPaths(toolId, paths);
      }
      void navigate({ to: "/tool/$toolId", params: { toolId } });
    },
    [navigate, preloadPaths],
  );

  // Whole-window drag-over affordance
  const handleWindowDragEnter = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    windowDragCounter.current++;
    if (windowDragCounter.current === 1) setWindowDragOver(true);
  }, []);

  const handleWindowDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    windowDragCounter.current--;
    if (windowDragCounter.current === 0) setWindowDragOver(false);
  }, []);

  const handleWindowDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
  }, []);

  const handleWindowDrop = useCallback((e: React.DragEvent) => {
    // If drop lands on a card, that card's handler fires first (stopPropagation)
    // This is the fallback for drops on the background
    e.preventDefault();
    windowDragCounter.current = 0;
    setWindowDragOver(false);
  }, []);

  return (
    <div
      className="h-full flex flex-col"
      onDragEnter={handleWindowDragEnter}
      onDragLeave={handleWindowDragLeave}
      onDragOver={handleWindowDragOver}
      onDrop={handleWindowDrop}
    >
      {/* Whole-window drag overlay */}
      {windowDragOver && (
        <div className="fixed inset-0 z-40 pointer-events-none border-2 libra-gold-border rounded-dialog m-1 libra-drop-bg" />
      )}

      <ScrollArea
        className="h-full"
        toolbar={
          <Toolbar>
            <ToolbarContent>
              <ToolbarTitle>{__APP_DISPLAY_NAME__ ?? "L!bra"}</ToolbarTitle>
            </ToolbarContent>
          </Toolbar>
        }
      >
        <div className="px-6 py-6 flex flex-col gap-6">
          <div className="flex flex-col gap-1">
            <Text variant="heading2">Video Toolkit</Text>
            <Text variant="regular" color="secondary">
              Drop videos or folders directly onto a tool card to get started instantly.
            </Text>
          </div>

          <div className="grid grid-cols-3 gap-4">
            {TOOL_REGISTRY.map((tool) => (
              <ToolCard key={tool.id} tool={tool} onNavigate={handleNavigate} />
            ))}
          </div>
        </div>
      </ScrollArea>
    </div>
  );
}
