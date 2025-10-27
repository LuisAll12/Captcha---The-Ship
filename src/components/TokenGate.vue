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

async function validateToken(t) {
    const resp = await fetch(`${import.meta.env.VITE_Backend_URL}/hack/validate-token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token: t }),
    })
    if (!resp.ok) {
        throw new Error('Netzwerkfehler')
    }
    const data = await resp.json()
    return data.valid === true
}

async function onSubmit() {
  errorMsg.value = ''
  submitting.value = true
  try {
    const ok = await validateToken(token.value)
    if (ok === true) {
      emit('valid')
    } else {
      errorMsg.value = 'Token ist ungültig'
    }
  } catch {
    errorMsg.value = 'Validierung fehlgeschlagen'
  } finally {
    submitting.value = false
  }
}

const emit = defineEmits(['valid'])
</script>