import { useEffect, useState } from "react";
import {
  ScrollArea,
  Toolbar,
  ToolbarContent,
  ToolbarTitle,
  Field,
  FieldGroup,
  FieldSet,
  Input,
  Switch,
  Button,
  Text,
  toast,
} from "@electron-core/components";
import type { Settings } from "../main/types";

const DEFAULT_EXTENSIONS = [
  "mp4", "mov", "m4v", "avi", "mkv", "webm", "mpg", "mpeg", "wmv", "flv", "3gp", "m2ts", "mts",
];

async function getSettings(): Promise<Settings> {
  return window.electronAPI.app.ipc.invoke("settings:get", {}) as Promise<Settings>;
}

async function setSettings(patch: Partial<Settings>): Promise<Settings> {
  return window.electronAPI.app.ipc.invoke("settings:set", { patch }) as Promise<Settings>;
}

export function SettingsView() {
  const [settings, setLocalSettings] = useState<Settings | null>(null);
  const [ffmpegPath, setFfmpegPath] = useState("");
  const [ffprobePath, setFfprobePath] = useState("");
  const [extensionsRaw, setExtensionsRaw] = useState("");
  const [dryRunDefault, setDryRunDefault] = useState(false);
  const [outputFolder, setOutputFolder] = useState("");
  const [isSaving, setIsSaving] = useState(false);

  // Close settings window on Escape
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key !== "Escape") return;
      if (event.defaultPrevented) return;
      const el = document.activeElement;
      if (
        el instanceof HTMLInputElement ||
        el instanceof HTMLTextAreaElement ||
        el instanceof HTMLSelectElement ||
        (el instanceof HTMLElement && el.isContentEditable)
      ) return;
      if (document.querySelector("[data-radix-popper-content-wrapper]")) return;
      event.preventDefault();
      void window.electronAPI.app.ipc.invoke("window:closeSettings", {});
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, []);

  useEffect(() => {
    console.log("[SettingsView:load]");
    void (async () => {
      try {
        const s = await getSettings();
        setLocalSettings(s);
        setFfmpegPath(s.ffmpegPath ?? "");
        setFfprobePath(s.ffprobePath ?? "");
        setExtensionsRaw((s.videoExtensions ?? DEFAULT_EXTENSIONS).join(", "));
        setDryRunDefault(s.dryRunDefault ?? false);
        setOutputFolder(s.outputFolder ?? "");
      } catch (err) {
        toast.error("Failed to load settings", { description: String(err) });
      }
    })();
  }, []);

  const handleChooseFolder = async () => {
    const res = await window.electronAPI.dialog.showOpenDialog({
      properties: ["openDirectory", "createDirectory"],
      title: "Choose output folder",
    });
    if (res.canceled || res.filePaths.length === 0) return;
    setOutputFolder(res.filePaths[0]);
  };

  const handleSave = async () => {
    setIsSaving(true);
    console.log("[SettingsView:save]", { ffmpegPath, ffprobePath, dryRunDefault });
    try {
      const extensions = extensionsRaw
        .split(/[,\s]+/)
        .map((e) => e.trim().toLowerCase())
        .filter(Boolean);
      const updated = await setSettings({
        ffmpegPath: ffmpegPath.trim() || null,
        ffprobePath: ffprobePath.trim() || null,
        videoExtensions: extensions,
        dryRunDefault,
        outputFolder: outputFolder.trim(),
      });
      setLocalSettings(updated);
      toast.success("Settings saved");
    } catch (err) {
      toast.error("Failed to save settings", { description: String(err) });
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <ScrollArea
      toolbar={
        <Toolbar>
          <ToolbarContent>
            <ToolbarTitle>Settings</ToolbarTitle>
          </ToolbarContent>
        </Toolbar>
      }
    >
      <div className="px-4 flex flex-col gap-8 mb-8">
        {/* ffmpeg paths */}
        <FieldSet title="ffmpeg Paths">
          <FieldGroup>
            <Field label="ffmpeg" description="Leave blank to auto-detect from Homebrew or PATH.">
              <Input
                placeholder="/opt/homebrew/bin/ffmpeg"
                value={ffmpegPath}
                onChange={(e) => setFfmpegPath(e.target.value)}
                disabled={settings === null}
              />
            </Field>
            <Field label="ffprobe" description="Leave blank to auto-detect from Homebrew or PATH.">
              <Input
                placeholder="/opt/homebrew/bin/ffprobe"
                value={ffprobePath}
                onChange={(e) => setFfprobePath(e.target.value)}
                disabled={settings === null}
              />
            </Field>
          </FieldGroup>
        </FieldSet>

        {/* Video extensions */}
        <FieldSet title="Video Extensions">
          <FieldGroup>
            <Field
              label="Extensions"
              description="Comma-separated list of video file extensions to scan."
            >
              <Input
                placeholder="mp4, mov, m4v, mkv…"
                value={extensionsRaw}
                onChange={(e) => setExtensionsRaw(e.target.value)}
                disabled={settings === null}
              />
            </Field>
          </FieldGroup>
        </FieldSet>

        {/* Output folder */}
        <FieldSet title="Output Folder">
          <FieldGroup>
            <Field
              label="Sorted files go to"
              description="Media Organizer moves sorted videos here. Defaults to Desktop / L!bra Organized."
            >
              <Input
                placeholder="~/Desktop/L!bra Organized"
                value={outputFolder}
                onChange={(e) => setOutputFolder(e.target.value)}
                disabled={settings === null}
              />
            </Field>
            <Field>
              <Button
                variant="filled"
                size="small"
                onClick={() => void handleChooseFolder()}
                disabled={settings === null}
              >
                Choose Folder…
              </Button>
            </Field>
          </FieldGroup>
        </FieldSet>

        {/* Behavior */}
        <FieldSet title="Behavior">
          <FieldGroup>
            <Field label="Dry Run by Default" description="Preview operations without making changes.">
              <Switch
                checked={dryRunDefault}
                onCheckedChange={(val) => {
                  console.log("[SettingsView:dryRunDefault]", { val });
                  setDryRunDefault(val);
                }}
                disabled={settings === null}
              />
            </Field>
          </FieldGroup>
        </FieldSet>

        {/* Save button */}
        <div>
          <Button
            variant="accent"
            size="medium"
            onClick={() => void handleSave()}
            disabled={isSaving || settings === null}
          >
            {isSaving ? "Saving…" : "Save Settings"}
          </Button>
        </div>

        {settings === null && (
          <Text variant="small" color="tertiary">
            Loading settings…
          </Text>
        )}
      </div>
    </ScrollArea>
  );
}
