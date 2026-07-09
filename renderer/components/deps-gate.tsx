import React, { useEffect, useState } from "react";
import { useQuery, useMutation } from "@tanstack/react-query";
import { Dialog, Button, Text, toast } from "@electron-core/components";
import { DownloadIcon, FolderOpenIcon } from "lucide-react";
import type { DepsCheckResult } from "../main/types";

async function checkDeps(): Promise<DepsCheckResult> {
  console.log("[DepsGate:check]");
  return window.electronAPI.app.ipc.invoke("deps:check", {}) as Promise<DepsCheckResult>;
}

async function installDeps(): Promise<{ success: boolean; error?: string }> {
  console.log("[DepsGate:install]");
  return window.electronAPI.app.ipc.invoke("deps:install", {}) as Promise<{ success: boolean; error?: string }>;
}

interface DepsGateProps {
  children: React.ReactNode;
}

export function DepsGate({ children }: DepsGateProps) {
  const [dialogOpen, setDialogOpen] = useState(false);

  const depsQuery = useQuery({
    queryKey: ["deps:check"],
    queryFn: checkDeps,
    retry: 1,
  });

  const installMutation = useMutation({
    mutationFn: installDeps,
    onSuccess: async (result) => {
      if (result.success) {
        console.log("[DepsGate:install:success]");
        toast.success("ffmpeg installed", { description: "Homebrew installation complete." });
        setDialogOpen(false);
        void depsQuery.refetch();
      } else {
        console.log("[DepsGate:install:fail]", { error: result.error });
        toast.error("Installation failed", { description: result.error ?? "Unknown error" });
      }
    },
    onError: (err) => {
      console.log("[DepsGate:install:error]", { err });
      toast.error("Installation failed", { description: String(err) });
    },
  });

  useEffect(() => {
    if (depsQuery.data) {
      const missing = !depsQuery.data.ffmpeg || !depsQuery.data.ffprobe;
      if (missing) {
        console.log("[DepsGate:missing]", depsQuery.data);
        setDialogOpen(true);
      }
    }
  }, [depsQuery.data]);

  const handleOpenSettings = async () => {
    console.log("[DepsGate:openSettings]");
    setDialogOpen(false);
    await window.electronAPI.app.ipc.invoke("window:openSettings", {});
  };

  return (
    <>
      {children}

      <Dialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        title="ffmpeg Not Found"
        description="L!bra requires ffmpeg and ffprobe to scan and process videos. Install them with Homebrew (recommended) or set custom paths in Settings."
        size="small"
        showOverlay
      >
        <div className="flex flex-col gap-3 pt-1">
          <Button
            variant="accent"
            size="large"
            className="w-full justify-center"
            onClick={() => {
              console.log("[DepsGate:brewInstall]");
              installMutation.mutate();
            }}
            disabled={installMutation.isPending}
          >
            <DownloadIcon className="size-4" />
            {installMutation.isPending ? "Installing with Homebrew…" : "Install with Homebrew"}
          </Button>

          <Button
            variant="filled"
            size="medium"
            className="w-full justify-center"
            onClick={() => void handleOpenSettings()}
          >
            <FolderOpenIcon className="size-4" />
            Set Paths Manually in Settings
          </Button>

          {!depsQuery.data?.ffmpeg && (
            <Text variant="small" color="tertiary">
              Missing: ffmpeg
            </Text>
          )}
          {!depsQuery.data?.ffprobe && (
            <Text variant="small" color="tertiary">
              Missing: ffprobe
            </Text>
          )}
        </div>
      </Dialog>
    </>
  );
}
