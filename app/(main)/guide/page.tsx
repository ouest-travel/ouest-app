"use client";

import { GuideScreen } from "@/components/GuideScreen";
import { useRouter } from "next/navigation";

export default function GuidePage() {
  const router = useRouter();

  return (
    <GuideScreen 
      onNavigateToEntryRequirements={() => router.push("/guide/entry-requirements")}
      onNavigateToBudget={() => router.push("/")}
    />
  );
}

