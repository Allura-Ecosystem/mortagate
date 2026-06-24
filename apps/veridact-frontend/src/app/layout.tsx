import type { Metadata } from "next";
import { Outfit, Inter } from "next/font/google";
import "./globals.css";
import { Sidebar } from "@/components/Sidebar";

const outfit = Outfit({
  variable: "--font-outfit",
  subsets: ["latin"],
  weight: ["500", "600", "700"],
});

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Veridact — Mortgage Audit Replay & QC",
  description: "Veridact by Allura. Replay mortgage approvals, catch invalid exemptions, and seal an immutable audit receipt.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${outfit.variable} ${inter.variable} h-full antialiased`}
    >
      {/* suppressHydrationWarning: browser extensions (e.g. Grammarly) inject
          attributes onto <body> before React hydrates. This silences that
          known false positive without hiding real mismatches deeper in the tree. */}
      <body suppressHydrationWarning className="min-h-full bg-canvas text-ink">
        {/* Single column on phones/tablets; sidebar + content from lg up. */}
        <div className="grid min-h-screen grid-cols-1 lg:grid-cols-[260px_1fr]">
          <Sidebar />
          <div className="min-w-0">{children}</div>
        </div>
      </body>
    </html>
  );
}
