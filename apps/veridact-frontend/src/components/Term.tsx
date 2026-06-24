"use client";

import { Fragment, useId, useState } from "react";
import { GLOSSARY, glossFor } from "@/lib/glossary";

// An inline term that explains itself. Works three ways so no one is left out:
//  - mouse: native title tooltip on hover (and the popover on click)
//  - keyboard: focus the control, Enter/Space toggles the definition
//  - touch (phones/tablets, which have NO hover): tap to reveal the definition
// A dotted underline marks it as a defined term. The definition text lives in
// the glossary — this component never invents wording.
export function Term({
  children,
  define,
}: {
  children: string;
  // Override the dictionary lookup (e.g. when the visible text differs).
  define?: string;
}) {
  const gloss = define ?? glossFor(children);
  const [open, setOpen] = useState(false);
  const id = useId();

  if (!gloss) return <>{children}</>;

  return (
    <span className="relative inline-block">
      <button
        type="button"
        aria-expanded={open}
        aria-describedby={open ? id : undefined}
        title={gloss}
        onClick={() => setOpen((o) => !o)}
        onBlur={() => setOpen(false)}
        className="cursor-help underline decoration-dotted decoration-muted/60 underline-offset-2 outline-none focus-visible:ring-2 focus-visible:ring-primary"
      >
        {children}
      </button>
      {open ? (
        <span
          id={id}
          role="tooltip"
          className="absolute bottom-full left-0 z-30 mb-1.5 w-max max-w-[260px] rounded-[10px] bg-ink px-3 py-2 text-left text-[12px] font-normal leading-snug text-white shadow-lg"
        >
          {gloss}
        </span>
      ) : null}
    </span>
  );
}

// Multi-word terms first so "Max LTV" etc. still match the single token.
const TERM_KEYS = Object.keys(GLOSSARY).sort((a, b) => b.length - a.length);
const TERM_RE = new RegExp(`\\b(${TERM_KEYS.join("|")})\\b`, "g");

// Scans a plain string and auto-glosses any known glossary terms inside it,
// so "DTI threshold" or "Max LTV 85%" explain themselves without hand-wrapping.
export function GlossedText({ children }: { children: string }) {
  const parts = children.split(TERM_RE);
  return (
    <>
      {parts.map((part, i) =>
        glossFor(part) ? (
          <Term key={i}>{part}</Term>
        ) : (
          <Fragment key={i}>{part}</Fragment>
        ),
      )}
    </>
  );
}
