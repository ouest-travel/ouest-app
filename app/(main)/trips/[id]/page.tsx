"use client";

import { BudgetOverviewScreen } from "@/components/BudgetOverviewScreen";
import { useRouter, useParams } from "next/navigation";
import { useTrips } from "@/hooks/useTrips";

export default function TripBudgetPage() {
  const router = useRouter();
  const params = useParams();
  const tripId = params.id as string;
  const { trips } = useTrips();
  
  // Find the trip by ID
  const trip = trips.find(t => t.id.toString() === tripId);
  const tripName = trip?.destination || "Trip";

  return (
    <BudgetOverviewScreen 
      onBack={() => router.push("/")}
      onViewChat={() => router.push(`/trips/${tripId}/chat`)}
      tripName={tripName}
      tripId={tripId}
    />
  );
}

