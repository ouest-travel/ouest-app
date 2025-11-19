import { useState, useEffect } from "react";

const PWA_FULLSCREEN_SELECTOR = "(display-mode: fullscreen)";
const PWA_STANDALONE_SELECTOR = "(display-mode: standalone)";

let pwaFullscreenQuery: MediaQueryList;
let pwaStandaloneQuery: MediaQueryList;

if (typeof window !== "undefined") {
  pwaFullscreenQuery = window.matchMedia(PWA_FULLSCREEN_SELECTOR);
  pwaStandaloneQuery = window.matchMedia(PWA_STANDALONE_SELECTOR);

  // Register handler with all of the media queries.
  pwaFullscreenQuery.addEventListener("change", queryChangeHandler);
  pwaStandaloneQuery.addEventListener("change", queryChangeHandler);
}

// Store isPwa value as a global singleton for easy and efficient access.
let isPwa: boolean = false;

function updateIsPwa() {
  if (!pwaFullscreenQuery || !pwaStandaloneQuery) return;
  else if (pwaFullscreenQuery.matches) isPwa = true;
  else if (pwaStandaloneQuery.matches) isPwa = true;
  else isPwa = false;
}

updateIsPwa();

// Store all active setStates in a Set so that we can call them when
// state changes, and efficiently add and remove setters.
const stateSetters = new Set<(a: boolean) => void>();

function queryChangeHandler(_ev: MediaQueryListEvent) {
  if (!pwaFullscreenQuery || !pwaStandaloneQuery) return;
  else if (pwaFullscreenQuery.matches) isPwa = true;
  else if (pwaStandaloneQuery.matches) isPwa = true;
  else isPwa = false;
  stateSetters.forEach((setter) => setter(isPwa));
}

export const useIsPwa = (): boolean => {
  const setBreakPoint = useState(isPwa)[1];
  useEffect(() => {
    stateSetters.add(setBreakPoint);
    return () => {
      stateSetters.delete(setBreakPoint);
    };
  }, [setBreakPoint]);

  return isPwa;
};
