"use client";

import { HomeScreen } from "@/components/HomeScreen";
import { useRouter } from "next/navigation";

export default function HomePage() {
  const router = useRouter();

  return (
    <HomeScreen 
      onNavigateToBudget={(_, tripId) => {
        router.push(`/trips/${tripId}`);
      }} 
    />
  );
}

