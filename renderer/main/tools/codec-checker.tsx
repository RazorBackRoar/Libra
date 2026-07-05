import { useCallback, useEffect, useId, useRef, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import {
  Button,
  Text,
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
  Badge,
  EmptyState,
  toast,
} from "@glaze/core/components";
import { PlayIcon, DownloadIcon } from "lucide-react";

import { ToolPage } from "../../components/tool-page";
import { DropZone } from "../../components/drop-zone";
import { CountPills, type CountPill } from "../../components/count-pills";
import { ProgressBar } from "../../components/progress-bar";
import { CancelButton } from "../../components/cancel-button";
import { SectionLabel } from "../../components/section-label";
import { useToolState } from "../tool-state";
import type { VideoInfo, JobProgress } from "../types";

async function invokeIpc<T>(channel: string, params: unknown): Promise<T> {
  return window.glazeAPI.glaze.ipc.invoke(channel, params) as Promise<T>;
}

function formatSize(bytes: number): string {
  if (bytes >= 1_073_741_824) return `${(bytes / 1_073_741_824).toFixed(1)} GB`;
  if (bytes >= 1_048_576) return `${(bytes / 1_048_576).toFixed(1)} MB`;
  return `${(bytes / 1024).toFixed(0)} KB`;
}

function formatDuration(sec: number | null): string {
  if (sec === null) return "—";
  const m = Math.floor(sec / 60);
  const s = Math.floor(sec % 60);
  return `${m}:${String(s).padStart(2, "0")}`;
}

function formatResolution(file: VideoInfo): string {
  if (file.width !== null && file.height !== null) {
    return `${file.width}×${file.height}`;
  }
  return file.resolutionClass;
}

export function CodecChecker() {
  const toolId = "codec-checker";
  const { session, updateSession } = useToolState(toolId);
  const jobId = useId();

  const [progress, setProgress] = useState<JobProgress | null>(null);
  const [isScanning, setIsScanning] = useState(false);

  const cancelledRef = useRef(false);

  useEffect(() => {
    const unsub = window.glazeAPI.glaze.ipc.onNotification(
      "job:progress",
      (payload: unknown) => {
        const p = payload as JobProgress;
        if (p.jobId === jobId) setProgress(p);
      },
    );
    return () => { if (typeof unsub === "function") unsub(); };
  }, [jobId]);

  const handlePaths = useCallback(
    (paths: string[]) => {
      console.log("[codec-checker:paths]", { count: paths.length });
      updateSession({ droppedPaths: paths, scannedFiles: [] });
      setProgress(null);
    },
    [updateSession],
  );

  const scanMutation = useMutation({
    mutationFn: async () => {
      cancelledRef.current = false;
      setIsScanning(true);
      setProgress(null);
      console.log("[codec-checker:scan:start]", { jobId, paths: session.droppedPaths });
      const result = await invokeIpc<{ files: VideoInfo[]; cancelled: boolean }>(
        "scan:start",
        { jobId, paths: session.droppedPaths },
      );
      return result;
    },
    onSuccess: (result) => {
      setIsScanning(false);
      setProgress(null);
      updateSession({ scannedFiles: result.files });
      console.log("[codec-checker:scan:done]", { count: result.files.length });
    },
    onError: (err) => {
      setIsScanning(false);
      setProgress(null);
      console.log("[codec-checker:scan:error]", { err });
      toast.error("Scan failed", { description: String(err) });
    },
  });

  const handleCancel = async () => {
    cancelledRef.current = true;
    console.log("[codec-checker:cancel]", { jobId });
    await invokeIpc("job:cancel", { jobId });
    setIsScanning(false);
    setProgress(null);
  };

  const handleExportCsv = async () => {
    console.log("[codec-checker:csv:export]", { count: session.scannedFiles.length });
    const headers = ["Name", "Path", "Codec", "Container", "Resolution", "Width", "Height", "FPS", "Duration", "Size", "Error"];
    const rows: string[][] = [
      headers,
      ...session.scannedFiles.map((f) => [
        f.name,
        f.path,
        f.codec ?? "",
        f.container ?? "",
        formatResolution(f),
        f.width !== null ? String(f.width) : "",
        f.height !== null ? String(f.height) : "",
        f.fps !== null ? String(f.fps) : "",
        f.durationSec !== null ? String(f.durationSec) : "",
        formatSize(f.sizeBytes),
        f.error ?? "",
      ]),
    ];
    try {
      await invokeIpc("csv:export", { rows, suggestedName: "codec-report.csv" });
      console.log("[codec-checker:csv:done]");
    } catch (err) {
      console.log("[codec-checker:csv:error]", { err });
      toast.error("Export failed", { description: String(err) });
    }
  };

  const hasFiles = session.scannedFiles.length > 0;
  const hasPaths = session.droppedPaths.length > 0;

  // Codec distribution
  const codecCounts = session.scannedFiles.reduce<Record<string, number>>((acc, f) => {
    const key = f.codec ?? "unknown";
    acc[key] = (acc[key] ?? 0) + 1;
    return acc;
  }, {});

  const countPills: CountPill[] = [
    { label: "Total", count: session.scannedFiles.length, color: "primary" },
    ...Object.entries(codecCounts).map(([codec, count]) => ({
      label: codec,
      count,
      color: (codec === "h264" || codec === "hevc" ? "green" : "yellow") as CountPill["color"],
    })),
  ];

  return (
    <ToolPage title="Codec Checker" category="analyze">
      <Text variant="regular" color="secondary">
        Read-only ffprobe report showing codec, container, resolution, FPS, duration, and size for each video. No files are modified.
      </Text>

      <DropZone
        onPaths={handlePaths}
        accept="both"
        disabled={isScanning}
        hint="Drag videos or a folder here"
      />

      {hasPaths && !isScanning && !scanMutation.isPending && (
        <div className="flex items-center gap-3">
          <Button
            variant="accent"
            size="large"
            onClick={() => scanMutation.mutate()}
            disabled={scanMutation.isPending}
          >
            <PlayIcon className="size-4" />
            Scan
          </Button>
          <Text variant="small" color="tertiary">
            {session.droppedPaths.length} path{session.droppedPaths.length !== 1 ? "s" : ""} queued
          </Text>
        </div>
      )}

      {isScanning && progress && (
        <div className="flex flex-col gap-3">
          <ProgressBar progress={progress} />
          <CancelButton onCancel={() => void handleCancel()} />
        </div>
      )}

      {hasFiles && (
        <>
          <div className="flex flex-col gap-2">
            <SectionLabel>Codec Summary</SectionLabel>
            <CountPills pills={countPills} />
          </div>

          <div className="flex flex-col gap-2">
            <div className="flex items-center justify-between">
              <SectionLabel>Report ({session.scannedFiles.length} files)</SectionLabel>
              <Button
                variant="filled"
                size="small"
                onClick={() => void handleExportCsv()}
              >
                <DownloadIcon className="size-4" />
                Export CSV
              </Button>
            </div>
            {session.scannedFiles.length === 0 ? (
              <EmptyState
                placement="inline"
                title="No videos scanned"
                description="Drop a folder or select files to get started."
              />
            ) : (
              <Table>
                <TableHeader sticky>
                  <TableRow>
                    <TableHead>Name</TableHead>
                    <TableHead>Codec</TableHead>
                    <TableHead>Container</TableHead>
                    <TableHead>Resolution</TableHead>
                    <TableHead>FPS</TableHead>
                    <TableHead>Duration</TableHead>
                    <TableHead>Size</TableHead>
                    <TableHead>Status</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {session.scannedFiles.map((file) => (
                    <TableRow key={file.path}>
                      <TableCell>
                        <Text variant="small" truncate className="max-w-[180px]">{file.name}</Text>
                      </TableCell>
                      <TableCell>
                        <Text variant="small" color="secondary">{file.codec ?? "—"}</Text>
                      </TableCell>
                      <TableCell>
                        <Text variant="small" color="secondary">{file.container ?? file.ext}</Text>
                      </TableCell>
                      <TableCell className="tabular-nums">
                        <Text variant="small" color="secondary">{formatResolution(file)}</Text>
                      </TableCell>
                      <TableCell className="tabular-nums">
                        <Text variant="small" color="secondary">
                          {file.fps !== null ? String(file.fps) : "—"}
                        </Text>
                      </TableCell>
                      <TableCell className="tabular-nums">
                        <Text variant="small" color="secondary">{formatDuration(file.durationSec)}</Text>
                      </TableCell>
                      <TableCell className="tabular-nums">
                        <Text variant="small" color="secondary">{formatSize(file.sizeBytes)}</Text>
                      </TableCell>
                      <TableCell>
                        {file.error ? (
                          <Badge color="red" size="small">Error</Badge>
                        ) : (
                          <Badge color="green" size="small">OK</Badge>
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </div>
        </>
      )}
    </ToolPage>
  );
}
