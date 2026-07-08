// Cookieless Real User Monitoring for the copilot-opentelemetry promo site.
//
// Uses the @webmaxru/cookieless-insights *beacon* (navigator.sendBeacon, with a
// fetch keepalive fallback) — no cookies, no local/session storage, no persistent
// identifier — so the site needs NO consent/GDPR banner. Telemetry goes to our own
// Azure Application Insights, never to a third party.
//
// The connection string is a PUBLIC client key, injected at BUILD time from the
// APPINSIGHTS_CONNECTION_STRING env var (a repo variable in CI). It is never
// committed as source; see build.mjs.

import {
  init,
  trackEvent,
  trackChangeDebounced,
  flush,
} from '@webmaxru/cookieless-insights';

// ── Kill switch ──────────────────────────────────────────────────────────────
// Flip this ONE line to false to disable ALL telemetry (build + ship to turn off).
const ANALYTICS_ENABLED = true;

// Injected by esbuild `define` at build time; empty string when unset (inert).
const CONNECTION_STRING =
  typeof __APPINSIGHTS_CONNECTION_STRING__ !== 'undefined'
    ? __APPINSIGHTS_CONNECTION_STRING__
    : '';

if (ANALYTICS_ENABLED && CONNECTION_STRING) {
  init({
    connectionString: CONNECTION_STRING,
    cloudRole: 'copilot-opentelemetry-site', // -> ai.cloud.role, distinguishes this site
    enabled: ANALYTICS_ENABLED, // one-line kill switch, also honored by the beacon
    // The beacon (sendBeacon) is the default transport — nothing else to configure.
  });
  // autoPageView defaults to true, so the page view was already sent by init().

  const host = location.host;
  const sectionsSeen = new Set();
  const startedAt = Date.now();
  let maxScrollPct = 0;

  // "Opened via shared link": UTM/ref params or an external referrer.
  try {
    const p = new URLSearchParams(location.search);
    const utm = {};
    for (const k of ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term']) {
      const v = p.get(k);
      if (v) utm[k] = v;
    }
    const ref = p.get('ref') || undefined;
    let referrerHost = '';
    try { referrerHost = document.referrer ? new URL(document.referrer).host : ''; } catch (_) {}
    const external = referrerHost && referrerHost !== host;
    if (Object.keys(utm).length || ref || external) {
      trackEvent('opened_via_shared_link', {
        ...utm,
        ref,
        referrer_host: external ? referrerHost : undefined,
        hash: location.hash || undefined,
      });
    }
  } catch (_) {}

  // Meaningful clicks — CTAs, in-page nav, and outbound links — via one delegated
  // listener (capture phase so it runs before same-tab navigation).
  document.addEventListener(
    'click',
    (e) => {
      const a = e.target && e.target.closest ? e.target.closest('a[href]') : null;
      if (!a) return;
      const href = a.getAttribute('href') || '';
      const label = (a.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 80);
      const sec = a.closest('section[id], header[id], nav');
      const section = sec ? sec.id || sec.tagName.toLowerCase() : undefined;

      if (href.startsWith('#')) {
        trackEvent('nav_click', { target: href, label, section });
        return;
      }
      let dest;
      try { dest = new URL(href, location.href); } catch (_) { return; }
      const outbound = dest.host !== host;
      const isCta = a.classList.contains('btn') || a.classList.contains('nav-cta');
      if (isCta) {
        trackEvent('cta_click', { label, href: dest.href, host: dest.host, outbound, section });
      } else if (outbound) {
        trackEvent('outbound_click', { label, href: dest.href, host: dest.host, section });
      }
    },
    { capture: true }
  );

  // Section reads (a proxy for scroll depth). DEBOUNCED via trackChangeDebounced so
  // scroll jitter / rapid re-entry collapses into a single event per section —
  // the same pattern you'd use for a slider or a search box.
  if ('IntersectionObserver' in window) {
    const io = new IntersectionObserver(
      (entries) => {
        for (const en of entries) {
          if (en.isIntersecting && en.target.id) {
            sectionsSeen.add(en.target.id);
            trackChangeDebounced('section_view', en.target.id, 500);
          }
        }
      },
      { threshold: 0.5 }
    );
    document.querySelectorAll('section[id], header[id]').forEach((s) => io.observe(s));
  }

  addEventListener(
    'scroll',
    () => {
      const doc = document.documentElement;
      const denom = doc.scrollHeight - doc.clientHeight || 1;
      const pct = Math.min(100, Math.round((doc.scrollTop / denom) * 100));
      if (pct > maxScrollPct) maxScrollPct = pct;
    },
    { passive: true }
  );

  // Engagement summary on the way out. The beacon flushes on hide/pagehide, so
  // enqueue this first, then flush so it rides the same sendBeacon.
  let sent = false;
  const sendEngagement = () => {
    if (sent) return;
    sent = true;
    trackEvent(
      'engagement',
      { max_scroll_pct: maxScrollPct, sections_seen: sectionsSeen.size },
      { dwell_ms: Date.now() - startedAt }
    );
    flush();
  };
  addEventListener('pagehide', sendEngagement);
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') sendEngagement();
  });
}
