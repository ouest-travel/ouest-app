import type { Metadata, Viewport } from "next";
import "@/index.css";
import { ThemeProvider } from "@/components/ThemeProvider";
import { DemoModeProvider } from "@/contexts/DemoModeContext";
import { AuthProvider } from "@/contexts/AuthContext";
import { Toaster } from "@/components/ui/sonner";

export const metadata: Metadata = {
  title: "Ouest - Travel Companion",
  description: "Your ultimate travel planning companion",
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "Ouest",
  },
  formatDetection: {
    telephone: false,
  },
  icons: {
    icon: "/icon-192x192.png",
    apple: "/icon-192x192.png",
  },
};

export const viewport: Viewport = {
  themeColor: "#6366f1",
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <link rel="apple-touch-icon" href="/icon-192x192.png" />
      </head>
      <body>
        <ThemeProvider>
          <DemoModeProvider>
            <AuthProvider>
              <Toaster richColors position="top-center" />
              {children}
            </AuthProvider>
          </DemoModeProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}

