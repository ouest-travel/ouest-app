"use client";

import { SignUpScreen } from "@/components/auth/SignUpScreen";
import { useRouter } from "next/navigation";

export default function SignUpPage() {
  const router = useRouter();

  return (
    <SignUpScreen onSwitchToLogin={() => router.push("/login")} />
  );
}

