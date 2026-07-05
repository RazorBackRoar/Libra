import React, { useCallback, useRef, useState } from "react";
import { Button, Text } from "@glaze/core/components";
import { UploadCloudIcon, FolderOpenIcon } from "lucide-react";
import { cn } from "@glaze/core/utils";

interface DropZoneProps {
  onPaths: (paths: string[]) => void;
  /** Whether to accept folders (openDirectory) or files, or both */
  accept?: "files" | "folders" | "both";
  disabled?: boolean;
  hint?: string;
  className?: string;
  /**
   * When provided, the panel switches to its populated state: a compact header
   * (drop hint + import buttons) sits above the children (e.g. the scanned
   * video list). The whole panel stays a live drop target.
   */
  children?: React.ReactNode;
}

export function DropZone({ onPaths, accept = "both", disabled = false, hint, className, children }: DropZoneProps) {
  const [isDragOver, setIsDragOver] = useState(false);
  const dragCounter = useRef(0);
  // toArray filters out null/false/undefined so an empty conditional child still
  // renders the large empty drop state.
  const hasContent = React.Children.toArray(children).length > 0;

  const resolvePaths = useCallback((files: FileList): string[] => {
    const paths: string[] = [];
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      if (file) {
        const p = window.glazeAPI.webUtils.getPathForFile(file);
        if (p) paths.push(p);
      }
    }
    return paths;
  }, []);

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
    if (disabled) return;
    const paths = resolvePaths(e.dataTransfer.files);
    if (paths.length > 0) {
      console.log("[DropZone:drop]", { count: paths.length });
      onPaths(paths);
    }
  };

  const handleOpenFolder = async () => {
    console.log("[DropZone:openFolder]");
    const result = await window.glazeAPI.dialog.showOpenDialog({
      properties: ["openDirectory", "multiSelections"],
    });
    if (!result.canceled && result.filePaths.length > 0) {
      onPaths(result.filePaths);
    }
  };

  const handleSelectFiles = async () => {
    console.log("[DropZone:selectFiles]");
    const result = await window.glazeAPI.dialog.showOpenDialog({
      properties: ["openFile", "multiSelections"],
      filters: [
        {
          name: "Video Files",
          extensions: ["mp4", "mov", "m4v", "avi", "mkv", "webm", "mpg", "mpeg", "wmv", "flv", "3gp", "m2ts", "mts"],
        },
      ],
    });
    if (!result.canceled && result.filePaths.length > 0) {
      onPaths(result.filePaths);
    }
  };

  const importButtons = (size: "small" | "medium") => (
    <div className="flex gap-2">
      {(accept === "folders" || accept === "both") && (
        <Button variant="accent" size={size} onClick={() => void handleOpenFolder()}>
          <FolderOpenIcon className="size-4" />
          Open Folder…
        </Button>
      )}
      {(accept === "files" || accept === "both") && (
        <Button variant="filled" size={size} onClick={() => void handleSelectFiles()}>
          Select Files
        </Button>
      )}
    </div>
  );

  return (
    <div
      onDragEnter={handleDragEnter}
      onDragLeave={handleDragLeave}
      onDragOver={handleDragOver}
      onDrop={handleDrop}
      className={cn(
        "rounded-card border-2 transition-all duration-150",
        isDragOver
          ? "libra-gold-border libra-gold-glow libra-drop-bg border-solid"
          : hasContent
            ? "border-solid libra-faint-border"
            : "border-dashed libra-faint-border",
        hasContent ? "p-4" : "flex flex-col items-center justify-center gap-3 p-6",
        disabled && "opacity-50 pointer-events-none",
        className,
      )}
    >
      {isDragOver ? (
        <div className="flex flex-col items-center justify-center gap-4 py-8">
          <UploadCloudIcon className="size-10 text-accent" />
          <Text variant="large-strong" color="accent">
            Drop files here
          </Text>
        </div>
      ) : hasContent ? (
        <div className="flex flex-col gap-4">
          <div className="flex items-center justify-between gap-3">
            <div className="flex items-center gap-2 min-w-0">
              <UploadCloudIcon className="size-4 shrink-0 text-tertiary" />
              <Text variant="small" color="tertiary" truncate>
                {hint ?? "Drag videos or a folder here to add more"}
              </Text>
            </div>
            {importButtons("small")}
          </div>
          {children}
        </div>
      ) : (
        <>
          <UploadCloudIcon className="size-7 text-tertiary" />
          <Text variant="regular" color="secondary">
            {hint ?? "Drag videos or folders here"}
          </Text>
          {importButtons("medium")}
        </>
      )}
    </div>
  );
}
