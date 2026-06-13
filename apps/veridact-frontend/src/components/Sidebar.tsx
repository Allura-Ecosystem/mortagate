"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { CURRENT_USER, CURRENT_ROLE } from "@/lib/roles";
import { DemoBadge } from "./DemoBadge";

type NavItem = { label: string; href: string; match: string };

// All seven designed destinations resolve to a real page — no dead links.
const NAV: NavItem[] = [
  { label: "Audit Queue", href: "/audit-queue", match: "/audit-queue" },
  { label: "Case Review", href: "/cases/case-001", match: "/cases" },
  { label: "Findings", href: "/findings", match: "/findings" },
  { label: "Receipts", href: "/receipts", match: "/receipts" },
  { label: "Analytics", href: "/analytics", match: "/analytics" },
  { label: "Policy Versions", href: "/policy", match: "/policy" },
  { label: "Admin", href: "/admin", match: "/admin" },
];

function Wordmark({ compact = false }: { compact?: boolean }) {
  return (
    <Link href="/audit-queue" className="block">
      <div className="flex items-center gap-3">
        <span className="flex h-9 w-9 items-center justify-center rounded-[10px] bg-white ring-1 ring-line">
          {/* Real Allura "AL" lettermark — the brand app icon, exported from the
              "Allura — Brand Identity" Figma file. Replaces the old placeholder shield. */}
          <Image
            src="/allura-mark.png"
            alt="Allura"
            width={28}
            height={21}
            className="h-[22px] w-auto"
            priority
          />
        </span>
        {!compact ? (
          <span>
            <span className="font-display block text-[22px] font-bold leading-none text-ink">
              Veridact
            </span>
            <span className="text-[11px] font-medium uppercase tracking-wide text-muted">
              by Allura
            </span>
          </span>
        ) : (
          <span className="font-display text-[18px] font-bold leading-none text-ink">Veridact</span>
        )}
      </div>
    </Link>
  );
}

export function Sidebar() {
  const pathname = usePathname();

  return (
    <>
      {/* Mobile / tablet: compact top bar with a horizontally scrollable nav.
          No JS drawer needed — the nav scrolls and stays keyboard reachable. */}
      <header className="border-b border-line bg-surface-rail px-4 py-3 lg:hidden">
        <div className="flex items-center justify-between gap-3">
          <span className="flex items-center gap-2">
            <Wordmark compact />
            <DemoBadge />
          </span>
          <span className="flex items-center gap-2">
            <span className="flex h-7 w-7 items-center justify-center rounded-full bg-brand-blue text-[11px] font-semibold text-white">
              {CURRENT_USER.replace(/[^A-Z]/g, "").slice(0, 2)}
            </span>
            <span className="text-[11px] text-muted">{CURRENT_ROLE}</span>
          </span>
        </div>
        <nav className="mt-3 -mx-1 flex gap-1 overflow-x-auto px-1 pb-1">
          {NAV.map((item) => {
            const active = pathname.startsWith(item.match);
            return (
              <Link
                key={item.label}
                href={item.href}
                aria-current={active ? "page" : undefined}
                className={[
                  "whitespace-nowrap rounded-full px-3 py-1.5 text-[13px] font-medium transition-colors",
                  active ? "bg-primary text-white" : "bg-white/60 text-ink/80 hover:bg-peach hover:text-ink",
                ].join(" ")}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>
      </header>

      {/* Desktop: full vertical sidebar. */}
      <aside className="hidden h-full flex-col justify-between border-r border-line bg-surface-rail px-5 py-6 lg:flex">
      <div>
        <div className="flex items-center justify-between gap-2">
          <Wordmark />
          <DemoBadge />
        </div>

        {/* Nav */}
        <nav className="mt-8 space-y-1">
          {NAV.map((item) => {
            const active = pathname.startsWith(item.match);
            return (
              <Link
                key={item.label}
                href={item.href}
                aria-current={active ? "page" : undefined}
                className={[
                  "block rounded-[10px] px-3 py-2.5 text-sm font-medium transition-colors",
                  active
                    ? "bg-primary text-white"
                    : "text-ink/80 hover:bg-peach hover:text-ink",
                ].join(" ")}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>
      </div>

      {/* Governance footer + signed-in user */}
      <div className="space-y-4">
        <div className="rounded-[14px] border border-line bg-white/60 p-4">
          <p className="text-[12px] font-semibold text-ink">Allura governance</p>
          <p className="mt-1 text-[12px] leading-snug text-muted">
            Every audit action creates a receipt.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <span className="flex h-8 w-8 items-center justify-center rounded-full bg-brand-blue text-[12px] font-semibold text-white">
            {CURRENT_USER.replace(/[^A-Z]/g, "").slice(0, 2)}
          </span>
          <span className="leading-tight">
            <span className="block text-[13px] font-medium text-ink">{CURRENT_USER}</span>
            <span className="block text-[11px] text-muted">{CURRENT_ROLE}</span>
          </span>
        </div>
      </div>
      </aside>
    </>
  );
}
