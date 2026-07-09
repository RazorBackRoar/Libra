import { ScrollArea, Toolbar, ToolbarActions, ToolbarBackButton, ToolbarContent } from "@electron-core/components";
import { cn } from "@electron-core/utils";
import { useNavigate } from "@tanstack/react-router";
import { ChevronLeft } from "lucide-react";
import React from "react";
import { SectionLabel } from "./section-label";

interface ToolPageProps {
  title: string;
  category?: string;
  /** Optional right-side action buttons rendered in the toolbar */
  actions?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
}

export function ToolPage({ title, category, actions, children, className }: ToolPageProps) {
  const navigate = useNavigate();

  const handleBack = () => {
    console.log("[ToolPage:back]", { title });
    void navigate({ to: "/" });
  };

  return (
    <ScrollArea
      className="h-full"
      toolbar={
        <Toolbar>
          <ToolbarBackButton aria-label="Back" onClick={handleBack}>
            <ChevronLeft className="size-5" />
          </ToolbarBackButton>
          {/* No toolbar title — each tool page shows its own centered gold title */}
          <ToolbarContent />
          {(actions || category) && (
            <ToolbarActions>
              {category && <SectionLabel>{category}</SectionLabel>}
              {actions}
            </ToolbarActions>
          )}
        </Toolbar>
      }
    >
      <div className={cn("px-6 py-2 flex flex-col gap-4 pb-4", className)}>
        {children}
      </div>
    </ScrollArea>
  );
}
