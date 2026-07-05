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

interface CandidateRow {
  file: VideoInfo;
  reason: string;
}

function getReencodeReason(file: VideoInfo): string | null {
  const reasons: string[] = [];
  const preferredCodecs = ["h264", "hevc"];
  const preferredExts = ["mp4", "mov"];

  if (file.codec !== null && !preferredCodecs.includes(file.codec)) {
    reasons.push(`codec "${file.codec}" (not h264/hevc)`);
  }
  if (!preferredExts.includes(file.ext)) {
    reasons.push(`container ".${file.ext}" (not mp4/mov)`);
  }
  return reasons.length > 0 ? reasons.join("; ") : null;
}

function formatSize(bytes: number): string {
  if (bytes >= 1_073_741_824) return `${(bytes / 1_073_741_824).toFixed(1)} GB`;
  if (bytes >= 1_048_576) return `${(bytes / 1_048_576).toFixed(1)} MB`;
  return `${(bytes / 1024).toFixed(0)} KB`;
}

export function ReencodeDetector() {
  const toolId = "reencode-detector";
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
      console.log("[reencode-detector:paths]", { count: paths.length });
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
      console.log("[reencode-detector:scan:start]", { jobId, paths: session.droppedPaths });
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
      console.log("[reencode-detector:scan:done]", { count: result.files.length });
    },
    onError: (err) => {
      setIsScanning(false);
      setProgress(null);
      console.log("[reencode-detector:scan:error]", { err });
      toast.error("Scan failed", { description: String(err) });
    },
  });

  const handleCancel = async () => {
    cancelledRef.current = true;
    console.log("[reencode-detector:cancel]", { jobId });
    await invokeIpc("job:cancel", { jobId });
    setIsScanning(false);
    setProgress(null);
  };

  // Client-side analysis — no backend call needed
  const candidates: CandidateRow[] = session.scannedFiles
    .filter((f) => f.error === null)
    .flatMap((f) => {
      const reason = getReencodeReason(f);
      return reason !== null ? [{ file: f, reason }] : [];
    });

  const hasFiles = session.scannedFiles.length > 0;
  const hasPaths = session.droppedPaths.length > 0;

  const countPills: CountPill[] = [
    { label: "Total", count: session.scannedFiles.length, color: "primary" },
    { label: "Candidates", count: candidates.length, color: candidates.length > 0 ? "yellow" : "secondary" },
    { label: "OK", count: session.scannedFiles.length - candidates.length, color: "green" },
  ];

  const handleExportCsv = async () => {
    console.log("[reencode-detector:csv:export]", { count: candidates.length });
    const headers = ["Name", "Path", "Codec", "Container", "Extension", "Resolution", "Size", "Reason"];
    const rows: string[][] = [
      headers,
      ...candidates.map(({ file: f, reason }) => [
        f.name,
        f.path,
        f.codec ?? "",
        f.container ?? "",
        f.ext,
        f.resolutionClass,
        formatSize(f.sizeBytes),
        reason,
      ]),
    ];
    try {
      await invokeIpc("csv:export", { rows, suggestedName: "reencode-candidates.csv" });
      console.log("[reencode-detector:csv:done]");
    } catch (err) {
      console.log("[reencode-detector:csv:error]", { err });
      toast.error("Export failed", { description: String(err) });
    }
  };

  return (
    <ToolPage title="Re-encode Detector" category="analyze">
      <Text variant="regular" color="secondary">
        Flag videos whose codec is not h264/hevc or whose container is not mp4/mov as re-encode candidates. Read-only report — no files are moved.
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
            <SectionLabel>Analysis Summary</SectionLabel>
            <CountPills pills={countPills} />
          </div>

          <div className="flex flex-col gap-2">
            <div className="flex items-center justify-between">
              <SectionLabel>Re-encode Candidates ({candidates.length})</SectionLabel>
              <Button
                variant="filled"
                size="small"
                onClick={() => void handleExportCsv()}
                disabled={candidates.length === 0}
              >
                <DownloadIcon className="size-4" />
                Export CSV
              </Button>
            </div>
            {candidates.length === 0 ? (
              <EmptyState
                placement="inline"
                title="No re-encode candidates"
                description="All scanned files use h264/hevc in mp4/mov containers."
              />
            ) : (
              <Table>
                <TableHeader sticky>
                  <TableRow>
                    <TableHead>Name</TableHead>
                    <TableHead>Codec</TableHead>
                    <TableHead>Container</TableHead>
                    <TableHead>Resolution</TableHead>
                    <TableHead>Size</TableHead>
                    <TableHead>Reason</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {candidates.map(({ file: f, reason }) => (
                    <TableRow key={f.path}>
                      <TableCell>
                        <Text variant="small" truncate className="max-w-[200px]">{f.name}</Text>
                      </TableCell>
                      <TableCell>
                        <Text variant="small" color="secondary">{f.codec ?? "—"}</Text>
                      </TableCell>
                      <TableCell>
                        <Text variant="small" color="secondary">{f.container ?? f.ext}</Text>
                      </TableCell>
                      <TableCell>
                        <Text variant="small" color="secondary">{f.resolutionClass}</Text>
                      </TableCell>
                      <TableCell className="tabular-nums">
                        <Text variant="small" color="secondary">{formatSize(f.sizeBytes)}</Text>
                      </TableCell>
                      <TableCell>
                        <Badge color="yellow" size="small">{reason}</Badge>
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
