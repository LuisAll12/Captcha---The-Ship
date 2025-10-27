<template>
  <div class="min-h-screen grid place-items-center bg-gray-100 p-6">
    <TokenGate v-if="stage === 'token'" @valid="stage = 'captcha'" />
    <AnnoyCaptcha v-else @success="onCaptchaSuccess" />
  </div>
</template>

<script setup>
import { ref } from 'vue'
import TokenGate from './components/TokenGate.vue'
import AnnoyCaptcha from './components/AnnoyCaptcha.vue'

const stage = ref('token')

function onCaptchaSuccess() {
  alert('Validiert')
}
</script>