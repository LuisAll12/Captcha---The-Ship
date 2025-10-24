<script lang="ts" setup>
import { ref, onMounted, onBeforeUnmount } from "vue";

const siteKey = import.meta.env.VITE_RECAPTCHA_SITE_KEY as string;
const verifyUrl = "/recaptcha/verify";

const widgetId = ref<number | null>(null);
const oneTimeToken = ref<string | null>(null);
const error = ref<string | null>(null);
const loading = ref(false);

declare global {
  interface Window {
    __recaptchaOnloadCallback?: () => void;
    grecaptcha?: any;
  }
}

function ensureScript(): Promise<void> {
  return new Promise((resolve, reject) => {
    // wenn bereits geladen und render verfügbar -> sofort
    if (window.grecaptcha && typeof window.grecaptcha.render === "function") {
      return resolve();
    }

    // Wenn bereits ein Script existiert, warte bis grecaptcha verfügbar (polling)
    const existing = document.getElementById("recaptcha-script");
    if (existing) {
      const start = Date.now();
      const wait = () => {
        if (window.grecaptcha && typeof window.grecaptcha.render === "function") return resolve();
        if (Date.now() - start > 10000) return reject(new Error("reCAPTCHA did not initialize in time"));
        setTimeout(wait, 200);
      };
      return wait();
    }

    // Füge das Script mit onload callback Parameter hinzu. Google ruft window.__recaptchaOnloadCallback()
    window.__recaptchaOnloadCallback = () => {
      // zusätzliche Sicherung: grecaptcha.ready ist manchmal verfügbar
      if (window.grecaptcha && typeof window.grecaptcha.render === "function") return resolve();
      // fallback poll
      const start = Date.now();
      const wait = () => {
        if (window.grecaptcha && typeof window.grecaptcha.render === "function") return resolve();
        if (Date.now() - start > 10000) return reject(new Error("reCAPTCHA did not initialize after onload"));
        setTimeout(wait, 200);
      };
      wait();
    };

    const s = document.createElement("script");
    s.id = "recaptcha-script";
    s.src = "https://www.google.com/recaptcha/api.js?onload=__recaptchaOnloadCallback&render=explicit";
    s.async = true;
    s.defer = true;
    s.onerror = () => reject(new Error("Failed to load reCAPTCHA script"));
    document.head.appendChild(s);
  });
}

async function renderRecaptcha() {
  try {
    loading.value = true;
    await ensureScript();
    // Safety check
    if (!window.grecaptcha || typeof window.grecaptcha.render !== "function") {
      throw new Error("grecaptcha.render not available");
    }
    // render once into container
    widgetId.value = window.grecaptcha.render("recaptcha-container", {
      sitekey: siteKey,
      size: "normal",
      callback: async (token: string) => {
        // send token to backend for verification -> returns one-time token
        try {
          const res = await fetch(verifyUrl, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ token }),
          });
          const js = await res.json();
          if (!res.ok) throw new Error(js.error || "Verification failed");
          oneTimeToken.value = js.one_time_token;
        } catch (err: any) {
          error.value = err.message || String(err);
          // reset widget to allow retry
          if (window.grecaptcha && typeof widgetId.value === "number") window.grecaptcha.reset(widgetId.value);
        }
      },
      "expired-callback": () => {
        error.value = "reCAPTCHA expired. Bitte neu lösen.";
      }
    });
  } catch (err: any) {
    error.value = err.message || String(err);
  } finally {
    loading.value = false;
  }
}

onMounted(() => {
  renderRecaptcha();
});

onBeforeUnmount(() => {
  // optional cleanup
  if (window.grecaptcha && typeof widgetId.value === "number") {
    try { window.grecaptcha.reset(widgetId.value); } catch(_) {}
  }
});
</script>

<template>
  <div>
    <div id="recaptcha-container"></div>
    <div v-if="loading">lade reCAPTCHA…</div>
    <div v-if="error" style="color: red">{{ error }}</div>

    <div v-if="oneTimeToken" style="margin-top: 1rem">
      <label>Einmal-Token (nur einmal verwendbar)</label>
      <input type="text" :value="oneTimeToken" readonly style="width:100%" />
    </div>
  </div>
</template>
