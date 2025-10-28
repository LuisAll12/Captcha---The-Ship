<template>
  <div class="min-h-screen grid place-items-center bg-gray-100 p-6">
    <TokenGate
      v-if="stage === 'token'"
      @valid="onTokenValid"
    />
    <AnnoyCaptcha
      v-else
      @success="onCaptchaSuccess"
      @failure="onCaptchaFailure"
    />
  </div>
</template>

<script setup>
import { ref } from 'vue'
import TokenGate from './components/TokenGate.vue'
import AnnoyCaptcha from './components/AnnoyCaptcha.vue'

const stage = ref('token')
const token = ref('')
const loading = ref(false)
const error = ref('')

const hostFromRuntime = window.RUNTIME_CONFIG?.SIMULATION_HOST
const host = hostFromRuntime || '127.0.0.1'
const backend = `http://${host}:5055`
console.log("Using backend backend:", backend)

async function setHacker(t) {
  const resp = await fetch(`${backend}/ride/hack_dealer/make_hacker/${encodeURIComponent(t)}`, {
    method: 'POST',
  })
  if (!resp.ok) throw new Error('Netzwerkfehler')
  const data = await resp.json()
  if (data.message === "success") {
    return true
  } else {
    return false
  }
}

// Token vom TokenGate empfangen, im Parent speichern und zur Captcha Stage wechseln
function onTokenValid(t) {
  token.value = t
  stage.value = 'captcha'
  error.value = ''
}

// Captcha erfolgreich gelöst, jetzt setHacker mit gespeicherten Token aufrufen
async function onCaptchaSuccess() {
  if (!token.value) {
    error.value = 'Kein Token vorhanden'
    return
  }
  loading.value = true
  error.value = ''
  try {
    const ok = await setHacker(token.value)
    if (ok) {
      // Erfolgspfad: weiterleiten, UI updaten oder Session setzen
      console.log('make_hacker erfolgreich')
      // Beispiel: stage.value = 'done' oder Router push
    } else {
      error.value = 'Backend lehnte die Anfrage ab'
      // optional: zurück zur Token Stage
      stage.value = 'token'
    }
  } catch (e) {
    console.error('setHacker Fehler', e)
    error.value = 'Netzwerk oder Serverfehler'
    stage.value = 'token'
  } finally {
    loading.value = false
  }
}

function onCaptchaFailure() {
  error.value = 'Captcha nicht bestanden'
  // optional: stage.value = 'token' um Token neu einzugeben
}
</script>
