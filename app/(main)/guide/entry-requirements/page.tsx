"use client";

import { EntryRequirements } from "@/components/EntryRequirements";
import { useRouter } from "next/navigation";

export default function EntryRequirementsPage() {
  const router = useRouter();

  return (
    <EntryRequirements onBack={() => router.back()} />
  );
}

