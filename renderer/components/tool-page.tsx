import React from "react";
import { useNavigate } from "@tanstack/react-router";
import { ScrollArea, Toolbar, ToolbarContent, ToolbarTitle, ToolbarActions, ToolbarBackButton } from "@glaze/core/components";
import { cn } from "@glaze/core/utils";
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
          <ToolbarBackButton label="Home" onClick={handleBack} />
          <ToolbarContent>
            <ToolbarTitle>{title}</ToolbarTitle>
          </ToolbarContent>
          {(actions || category) && (
            <ToolbarActions>
              {category && <SectionLabel>{category}</SectionLabel>}
              {actions}
            </ToolbarActions>
          )}
        </Toolbar>
      }
    >
      <div className={cn("px-6 py-4 flex flex-col gap-6 pb-10", className)}>
        {children}
      </div>
    </ScrollArea>
  );
}
