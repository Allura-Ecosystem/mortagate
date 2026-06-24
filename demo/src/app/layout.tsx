import type { Metadata } from "next";
import { Inter, Outfit } from "next/font/google";
import "./globals.css";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  weight: ["400", "500", "600"],
});

const outfit = Outfit({
  variable: "--font-outfit",
  subsets: ["latin"],
  weight: ["600", "700"],
});

export const metadata: Metadata = {
  title: "Veridact — Every decision has a receipt",
  description: "Mortgage audit intelligence by Allura. Compliance-grade policy evaluation with immutable audit trails.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${inter.variable} ${outfit.variable} h-full`}>
      <body className="min-h-full flex flex-col bg-veridact-bg text-veridact-fg font-[family-name:var(--font-inter)]">
        {children}
      </body>
    </html>
  );
}
