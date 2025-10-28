<template>
  <div class="w-full max-w-md mx-auto p-6 rounded-2xl border shadow-sm bg-white">
    <div class="text-xl font-semibold mb-4">Token prüfen</div>

    <form @submit.prevent="onSubmit" class="space-y-4">
      <div>
        <label class="text-sm block mb-2">Token eingeben</label>
        <input
          v-model.trim="token"
          type="text"
          class="w-full border rounded-lg p-3 text-sm focus:outline-none focus:ring-2"
          autocomplete="one-time-code"
          placeholder="Dein Token"
        />
      </div>

      <button
        type="submit"
        class="w-full px-4 py-2 rounded-lg bg-gray-900 text-white shadow disabled:opacity-50"
        :disabled="submitting || token.length === 0"
      >
        {{ submitting ? 'Prüfe…' : 'Validieren' }}
      </button>

      <p v-if="errorMsg" class="text-sm text-red-700 text-center">{{ errorMsg }}</p>
    </form>
  </div>
</template>

<script setup>
import { ref } from 'vue'

const token = ref('')
const submitting = ref(false)
const errorMsg = ref('')

const emit = defineEmits(['valid'])

const hostFromRuntime = window.RUNTIME_CONFIG?.SIMULATION_HOST
const host = hostFromRuntime || '127.0.0.1'
const backend = `http://${host}:5055`
console.log("Using backend backend:", backend)

async function validateToken(t) {
  const resp = await fetch(`${backend}/ride/hack_dealer/verify/${encodeURIComponent(t)}`, {
    method: 'POST',
  })
  if (!resp.ok) throw new Error('Netzwerkfehler')
  const data = await resp.json()
  if (data.message === "success") {
    return true
  } else {
    errorMsg.value = data.message 
  }
}

async function onSubmit() {
  errorMsg.value = ''
  submitting.value = true
  try {
    const ok = await validateToken(token.value)
    if (ok === true) {
      emit('valid', token.value)   // <— Token nach oben schicken
    } else {
      errorMsg.value = 'Token ist ungültig'
    }
  } catch {
    errorMsg.value = 'Validierung fehlgeschlagen'
  } finally {
    submitting.value = false
  }
}
</script>
