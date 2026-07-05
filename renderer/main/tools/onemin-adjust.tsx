import { useCallback, useEffect, useId, useRef, useState } from "react";
import { useMutation } from "@tanstack/react-query";
import {
  Button,
  Text,
  toast,
  SegmentedControl,
  SegmentedControlItem,
  Switch,
  NativeDatePickerRoot,
  NativeDatePickerTrigger,
  NativeDatePickerValue,
} from "@glaze/core/components";
import { PlayIcon, CalendarIcon } from "lucide-react";

import { ToolPage } from "../../components/tool-page";
import { DropZone } from "../../components/drop-zone";
import { ResultsTable, type SortKey, type SortDir } from "../../components/results-table";
import { CountPills, type CountPill } from "../../components/count-pills";
import { DryRunToggle } from "../../components/dry-run-toggle";
import { ProgressBar } from "../../components/progress-bar";
import { CancelButton } from "../../components/cancel-button";
import { SectionLabel } from "../../components/section-label";
import { useToolState } from "../tool-state";
import type { VideoInfo, JobProgress, FileOpResult } from "../types";

async function invokeIpc<T>(channel: string, params: unknown): Promise<T> {
  return window.glazeAPI.glaze.ipc.invoke(channel, params) as Promise<T>;
}

type AdjustMode = "copies" | "inplace";

function toLocalDateTimeString(date: Date): string {
  // Format: yyyy-MM-dd'T'HH:mm:ss for NativeDatePicker dateAndTime type
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

export function OneminAdjust() {
  const toolId = "onemin-adjust";
  const { session, updateSession } = useToolState(toolId);
  const jobId = useId();

  const [adjustMode, setAdjustMode] = useState<AdjustMode>("copies");
  const [dryRun, setDryRun] = useState(true);
  const [useCustomStart, setUseCustomStart] = useState(false);
  const [customStartValue, setCustomStartValue] = useState("");
  const [sortKey, setSortKey] = useState<SortKey>("name");
  const [sortDir, setSortDir] = useState<SortDir>("asc");
  const [progress, setProgress] = useState<JobProgress | null>(null);
  const [isScanning, setIsScanning] = useState(false);
  const [opResults, setOpResults] = useState<FileOpResult[]>([]);

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
      console.log("[onemin-adjust:paths]", { count: paths.length });
      updateSession({ droppedPaths: paths, scannedFiles: [] });
      setOpResults([]);
      setProgress(null);
    },
    [updateSession],
  );

  const scanMutation = useMutation({
    mutationFn: async () => {
      cancelledRef.current = false;
      setIsScanning(true);
      setProgress(null);
      setOpResults([]);
      console.log("[onemin-adjust:scan:start]", { jobId, paths: session.droppedPaths });
      const result = await invokeIpc<{ files: VideoInfo[]; cancelled: boolean }>(
        "scan:start",
        { jobId, paths: session.droppedPaths },
      );
      return result;
    },
    onSuccess: (result) => {
      setIsScanning(false);
      setProgress(null);
      updateSession({ scannedFiles: result.files, selectedPaths: new Set() });
      console.log("[onemin-adjust:scan:done]", { count: result.files.length });
    },
    onError: (err) => {
      setIsScanning(false);
      setProgress(null);
      console.log("[onemin-adjust:scan:error]", { err });
      toast.error("Scan failed", { description: String(err) });
    },
  });

  const handleCancel = async () => {
    cancelledRef.current = true;
    console.log("[onemin-adjust:cancel]", { jobId });
    await invokeIpc("job:cancel", { jobId });
    setIsScanning(false);
    setProgress(null);
  };

  const applyMutation = useMutation({
    mutationFn: async () => {
      // Resolve startISO: custom value (picker uses dateAndTime format yyyy-MM-dd'T'HH:mm:ss) or now
      let startISO: string;
      if (useCustomStart && customStartValue) {
        // Convert picker value to full ISO
        startISO = new Date(customStartValue).toISOString();
      } else {
        startISO = new Date().toISOString();
      }
      const filePaths = session.scannedFiles.map((f) => f.path);
      console.log("[onemin-adjust:timeadjust:apply]", { jobId, mode: adjustMode, startISO, stepSeconds: 60, dryRun, count: filePaths.length });
      const result = await invokeIpc<{ results: FileOpResult[]; cancelled: boolean }>(
        "timeadjust:apply",
        {
          jobId,
          files: filePaths,
          startISO,
          stepSeconds: 60,
          mode: adjustMode,
          dryRun,
        },
      );
      return result;
    },
    onSuccess: ({ results, cancelled }) => {
      setOpResults(results);
      if (cancelled) {
        toast.info("Operation cancelled.");
        return;
      }
      const errors = results.filter((r) => r.status === "error");
      if (dryRun) {
        toast.success("Dry run complete", { description: `${results.length} operations previewed.` });
      } else if (errors.length > 0) {
        toast.error(`${errors.length} operation${errors.length > 1 ? "s" : ""} failed.`);
      } else {
        toast.success("Timestamps applied", { description: `${results.length} files adjusted.` });
      }
      console.log("[onemin-adjust:apply:done]", { count: results.length, errors: errors.length });
    },
    onError: (err) => {
      console.log("[onemin-adjust:apply:error]", { err });
      toast.error("Apply failed", { description: String(err) });
    },
  });

  const hasFiles = session.scannedFiles.length > 0;
  const hasPaths = session.droppedPaths.length > 0;
  const isRunning = applyMutation.isPending;

  const countPills: CountPill[] = [
    { label: "Files", count: session.scannedFiles.length, color: "primary" },
  ];

  const displayFiles = opResults.length > 0
    ? session.scannedFiles.filter((f) => opResults.some((r) => r.from === f.path))
    : session.scannedFiles;

  return (
    <ToolPage title="1MinVid Adjust" category="convert">
      <Text variant="regular" color="secondary">
        Assign sequential timestamps 60 seconds apart, starting from a custom or current time. Choose to create dated copies or update files in place.
      </Text>

      <DropZone
        onPaths={handlePaths}
        accept="both"
        disabled={isScanning || isRunning}
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
            <SectionLabel>Scan Summary</SectionLabel>
            <CountPills pills={countPills} />
          </div>

          <div className="flex flex-col gap-4">
            <SectionLabel>Options</SectionLabel>

            <div className="flex flex-col gap-2">
              <Text variant="small" color="secondary">Mode</Text>
              <SegmentedControl
                value={adjustMode}
                onValueChange={(v) => setAdjustMode(v as AdjustMode)}
                aria-label="Adjust mode"
              >
                <SegmentedControlItem value="copies">Create dated copies</SegmentedControlItem>
                <SegmentedControlItem value="inplace">Update in place</SegmentedControlItem>
              </SegmentedControl>
            </div>

            <div className="flex items-center gap-3">
              <Switch
                checked={useCustomStart}
                onCheckedChange={(val) => {
                  setUseCustomStart(val);
                  if (!val) setCustomStartValue("");
                }}
              />
              <Text variant="small" color="secondary">Custom start time</Text>
            </div>

            {useCustomStart && (
              <NativeDatePickerRoot
                value={customStartValue || toLocalDateTimeString(new Date())}
                onValueChange={setCustomStartValue}
                type="dateAndTime"
              >
                <NativeDatePickerTrigger>
                  <CalendarIcon className="size-4 text-tertiary" />
                  <NativeDatePickerValue placeholder="Pick a start date and time" />
                </NativeDatePickerTrigger>
              </NativeDatePickerRoot>
            )}
          </div>

          <div className="flex flex-col gap-2">
            <SectionLabel>Files ({session.scannedFiles.length})</SectionLabel>
            <ResultsTable
              files={displayFiles}
              selectedPaths={session.selectedPaths}
              onSelectionChange={(paths) => updateSession({ selectedPaths: paths })}
              sortKey={sortKey}
              sortDir={sortDir}
              onSortChange={(k, d) => { setSortKey(k); setSortDir(d); }}
              emptyTitle="No videos scanned"
              emptyDescription="Drop a folder or select files to get started."
            />
          </div>

          <div className="flex items-center gap-4 pt-2 border-t border-separator">
            <Button
              variant="accent"
              size="large"
              onClick={() => applyMutation.mutate()}
              disabled={!hasFiles || isRunning}
            >
              <PlayIcon className="size-4" />
              {isRunning ? "Applying…" : "Apply"}
            </Button>
            <DryRunToggle checked={dryRun} onCheckedChange={setDryRun} />
            {isRunning && progress && <ProgressBar progress={progress} className="flex-1" />}
            {isRunning && <CancelButton onCancel={() => void handleCancel()} />}
          </div>
        </>
      )}
    </ToolPage>
  );
}
