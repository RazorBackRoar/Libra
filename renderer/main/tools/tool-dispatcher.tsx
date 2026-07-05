import { useParams } from "@tanstack/react-router";
import { getToolById } from "./registry";
import { ToolPage } from "../../components/tool-page";
import { MainOrganizer } from "./main-organizer";
import { ProvidRenamer } from "./provid-renamer";
import { VidRes } from "./vidres";
import { ProMax } from "./promax";
import { MaxVid } from "./maxvid";
import { KeepName } from "./keepname";
import { ReencodeDetector } from "./reencode-detector";
import { OneminAdjust } from "./onemin-adjust";
import { SlomoCreator } from "./slomo-creator";
import { DuplicateFinder } from "./duplicate-finder";
import { GpsSorter } from "./gps-sorter";
import { CodecChecker } from "./codec-checker";
import { Text } from "@glaze/core/components";

function ToolPlaceholder({ toolId }: { toolId: string }) {
  const tool = getToolById(toolId);
  return (
    <ToolPage title={tool?.title ?? toolId} category={tool?.category}>
      <div className="flex flex-col items-center justify-center py-20 gap-3">
        <Text variant="large-strong" color="secondary">
          {tool?.title ?? toolId}
        </Text>
        <Text variant="regular" color="tertiary">
          This tool is not yet available.
        </Text>
      </div>
    </ToolPage>
  );
}

export function ToolDispatcher() {
  const { toolId } = useParams({ from: "/tool/$toolId" });

  switch (toolId) {
    case "main-organizer":
      return <MainOrganizer />;
    case "provid-renamer":
      return <ProvidRenamer />;
    case "vidres":
      return <VidRes />;
    case "promax":
      return <ProMax />;
    case "maxvid":
      return <MaxVid />;
    case "keepname":
      return <KeepName />;
    case "reencode-detector":
      return <ReencodeDetector />;
    case "onemin-adjust":
      return <OneminAdjust />;
    case "slomo-creator":
      return <SlomoCreator />;
    case "duplicate-finder":
      return <DuplicateFinder />;
    case "gps-sorter":
      return <GpsSorter />;
    case "codec-checker":
      return <CodecChecker />;
    default:
      return <ToolPlaceholder toolId={toolId} />;
  }
}
