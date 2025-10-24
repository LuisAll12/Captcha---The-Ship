<script lang="ts" setup>
import { ref, onMounted, onBeforeUnmount } from "vue";

const siteKey = import.meta.env.VITE_RECAPTCHA_SITE_KEY as string; // set in .env
const verificationUrl = "/recaptcha/verify"; // Backend Endpoint

const widgetId = ref<number | null>(null);
const solving = ref(false);
const error = ref<string | null>(null);
const oneTimeToken = ref<string | null>(null);

declare global {
  interface Window {
    grecaptcha: any;
  }
}

function renderRecaptcha() {
  if (!window.grecaptcha) {
    error.value = "reCAPTCHA script not loaded.";
    return;
  }
  widgetId.value = window.grecaptcha.render("recaptcha-container", {
    sitekey: siteKey,
    size: "normal",
    callback: async (token: string) => {
      // token ist g-recaptcha-response
      solving.value = true;
      error.value = null;
      try {
        const res = await fetch(verificationUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ token }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || "Verification failed");
        // Backend liefert dein einmaliges Token zurück
        oneTimeToken.value = data.one_time_token;
      } catch (err: any) {
        error.value = err.message || String(err);
        // reset widget falls nötig
        if (window.grecaptcha && typeof widgetId.value === "number") {
          window.grecaptcha.reset(widgetId.value);
        }
      } finally {
        solving.value = false;
      }
    },
    "expired-callback": () => {
      error.value = "reCAPTCHA expired, bitte neu lösen.";
    },
  });
}

function loadScript() {
  return new Promise<void>((resolve, reject) => {
    if (document.getElementById("recaptcha-script")) return resolve();
    const el = document.createElement("script");
    el.id = "recaptcha-script";
    el.src = "https://www.google.com/recaptcha/api.js?render=explicit";
    el.async = true;
    el.defer = true;
    el.onload = () => resolve();
    el.onerror = () => reject(new Error("reCAPTCHA script failed to load"));
    document.head.appendChild(el);
  });
}

onMounted(async () => {
  try {
    await loadScript();
    // kleines Delay, bis window.grecaptcha verfügbar ist
    const waitUntil = (ms: number) => new Promise(r => setTimeout(r, ms));
    let tries = 0;
    while (!window.grecaptcha && tries++ < 10) await waitUntil(150);
    if (!window.grecaptcha) throw new Error("GreCaptcha not available");
    renderRecaptcha();
  } catch (e: any) {
    error.value = e.message || String(e);
  }
});

onBeforeUnmount(() => {
  // Optional cleanup: reset widget
  if (window.grecaptcha && typeof widgetId.value === "number") {
    window.grecaptcha.reset(widgetId.value);
  }
});
</script>

<template>
  <div>
    <div id="recaptcha-container" style="display:inline-block"></div>
    <div v-if="solving">Verifiziere…</div>
    <div v-if="error" style="color: red">{{ error }}</div>

    <div v-if="oneTimeToken" style="margin-top: 1rem;">
      <label>Einmal-Token (nur einmal verwendbar):</label>
      <input type="text" :value="oneTimeToken" readonly style="width: 100%" />
      <p>Kopiere das Token und gib es auf der Hack-Seite ein. Es verfällt in wenigen Minuten.</p>
    </div>
  </div>
</template>

<style scoped>
/* optional styles */
</style>
