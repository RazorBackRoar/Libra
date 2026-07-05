import React from "react";
import { cn } from "@glaze/core/utils";

interface SectionLabelProps {
  children: React.ReactNode;
  className?: string;
}

export function SectionLabel({ children, className }: SectionLabelProps) {
  return (
    <span className={cn("libra-section-label", className)}>
      {children}
    </span>
  );
}
