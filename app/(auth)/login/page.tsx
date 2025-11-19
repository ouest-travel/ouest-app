"use client";

import { LoginScreen } from "@/components/auth/LoginScreen";
import { useRouter } from "next/navigation";

export default function LoginPage() {
  const router = useRouter();

  return (
    <LoginScreen onSwitchToSignUp={() => router.push("/signup")} />
  );
}

