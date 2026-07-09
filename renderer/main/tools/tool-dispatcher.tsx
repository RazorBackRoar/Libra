import { useParams } from "@tanstack/react-router";
import { getToolById } from "./registry";
import { ToolPage } from "../../components/tool-page";
import { MediaOrganizer } from "./media-organizer";
import { OneminAdjust } from "./onemin-adjust";
import { GpsSorter } from "./gps-sorter";
import { Text } from "@electron-core/components";

function ToolPlaceholder({ toolId }: { toolId: string }) {
  const tool = getToolById(toolId);
  return (
    <ToolPage title={tool?.title ?? toolId} category={tool?.category}>
      <div className="flex flex-col items-center justify-center py-20 gap-3">
        <Text variant="large-strong" color="secondary">
          {tool?.title ?? toolId}
        </Text>
        <Text variant="regular" color="tertiary">
          This tool is not available.
        </Text>
      </div>
    </ToolPage>
  );
}

export function ToolDispatcher() {
  const { toolId } = useParams({ from: "/tool/$toolId" });

  switch (toolId) {
    case "media-organizer":
      return <MediaOrganizer />;
    case "onemin-adjust":
      return <OneminAdjust />;
    case "gps-sorter":
      return <GpsSorter />;
    default:
      return <ToolPlaceholder toolId={toolId} />;
  }
}
