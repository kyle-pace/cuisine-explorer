// Amplitude analytics, set up the same private way as kylepace.net:
// autocapture, no IP address, an ID kept in localStorage (no cookies), off for
// Global Privacy Control, Do Not Track or the opt-out on /privacy/, and only on
// the live domain. Session Replay records 5% of sessions with everything
// masked, and its code only loads for those sessions.
//
// This is the only file that talks to Amplitude, so switching tools later
// means changing this file.

import * as amplitude from '@amplitude/analytics-browser';

// The kylepace.dev Amplitude project's browser API key (project 902556). Browser keys
// are public by design (every page sends it), so it can live in the code; a build
// variable overrides it.
const API_KEY: string =
  import.meta.env.PUBLIC_AMPLITUDE_API_KEY || '15494c5b9d8a36939245949ac59554ee';

const LIVE_HOSTS = ['kylepace.dev'];
const REPLAY_RATE = 0.05;
const OPT_OUT_KEY = 'kp-analytics-opt-out';
const REPLAY_KEY = 'kp-replay';

export function isOptedOut(): boolean {
  try {
    return localStorage.getItem(OPT_OUT_KEY) === '1';
  } catch {
    return false;
  }
}

export function setOptOut(optOut: boolean) {
  try {
    if (optOut) localStorage.setItem(OPT_OUT_KEY, '1');
    else localStorage.removeItem(OPT_OUT_KEY);
  } catch {
    // Storage can be unavailable (private modes); nothing to remember then.
  }
  amplitude.setOptOut(optOut);
}

function browserSaysNo(): boolean {
  const nav = navigator as Navigator & { globalPrivacyControl?: boolean };
  return nav.globalPrivacyControl === true || nav.doNotTrack === '1';
}

function inReplaySample(): boolean {
  try {
    let pick = sessionStorage.getItem(REPLAY_KEY);
    if (pick === null) {
      pick = Math.random() < REPLAY_RATE ? '1' : '0';
      sessionStorage.setItem(REPLAY_KEY, pick);
    }
    return pick === '1';
  } catch {
    return false;
  }
}

export async function startAnalytics() {
  if (!API_KEY) return;
  if (!LIVE_HOSTS.includes(location.hostname)) return;
  if (browserSaysNo() || isOptedOut()) return;

  if (inReplaySample()) {
    const { sessionReplayPlugin } = await import('@amplitude/plugin-session-replay-browser');
    amplitude.add(
      sessionReplayPlugin({
        sampleRate: 1,
        privacyConfig: { defaultMaskLevel: 'conservative' },
      }),
    );
  }

  amplitude.init(API_KEY, {
    autocapture: true,
    identityStorage: 'localStorage',
    trackingOptions: { ipAddress: false },
  });
}

/** Custom events, in Title Case like the other apps ("Clicked Resume"). */
export function track(event: string, properties?: Record<string, unknown>) {
  amplitude.track(event, properties);
}
