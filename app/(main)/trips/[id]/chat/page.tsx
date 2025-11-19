"use client";

import { ChatDemoScreen } from "@/components/ChatDemoScreen";
import { useRouter, useParams } from "next/navigation";
import { useTrips } from "@/hooks/useTrips";

export default function TripChatPage() {
  const router = useRouter();
  const params = useParams();
  const tripId = params.id as string;
  const { trips } = useTrips();
  
  // Find the trip by ID
  const trip = trips.find(t => t.id.toString() === tripId);
  const tripName = trip?.destination || "Trip";

  return (
    <ChatDemoScreen 
      onBack={() => router.back()}
      onNavigateToBudget={() => router.push(`/trips/${tripId}`)}
      tripName={tripName}
      tripId={parseInt(tripId)}
    />
  );
}

