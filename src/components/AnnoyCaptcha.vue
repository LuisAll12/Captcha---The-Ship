<template>
  <div class="w-full max-w-xl mx-auto p-6 rounded-2xl border shadow-sm bg-white select-none">
    <div class="text-xl font-semibold mb-4">Verifizierung</div>

    <!-- Stufe 1 -->
    <div v-if="step === 1" class="space-y-3">
      <div class="text-sm opacity-80">Bitte bestätige, dass du kein Roboter bist</div>
      <div
        ref="stage1Ref"
        class="relative h-56 border rounded-lg overflow-hidden bg-gray-50"
        @mousemove="stage1MouseMove"
      >
        <label
          class="absolute flex items-center gap-2 bg-white px-3 py-2 rounded-md border shadow cursor-pointer transition-all"
          :style="{ left: checkboxPos.x + 'px', top: checkboxPos.y + 'px' }"
          @mouseenter="teleport()"
          @click.prevent="runawayClick"
        >
          <input type="checkbox" :checked="false" @click.prevent />
          <span>Ich bin kein Roboter</span>
        </label>
        <div v-if="stage1Hint" class="absolute bottom-2 right-2 text-xs opacity-60">Langsam annähern</div>
      </div>
    </div>

    <!-- Stufe 2 -->
    <div v-else-if="step === 2" class="space-y-4">
      <div class="text-sm opacity-80">Schiebe den Regler exakt auf 67.67 und halte es 3 Sekunden</div>
      <div class="px-1">
        <input
          type="range"
          min="0"
          max="100"
          step="0.01"
          v-model.number="sliderValue"
          class="w-full"
          @input="handleSlider"
        />
      </div>
      <div class="text-sm text-center">Aktuell {{ sliderValue.toFixed(2) }}</div>
      <div class="flex items-center gap-3">
        <div class="flex-1 h-2 rounded bg-gray-100 overflow-hidden">
          <div class="h-full bg-gray-700 transition-all" :style="{ width: Math.floor(holdPreciseProgress*100) + '%' }"/>
        </div>
        <div class="w-16 text-right text-xs">{{ Math.floor(holdPreciseProgress*100) }}%</div>
      </div>
      <div v-if="preciseLocked" class="text-xs text-center text-green-700">Präzision bestätigt</div>
    </div>

    <!-- Stufe 3 -->
    <div v-else-if="step === 3" class="space-y-3">
      <div class="text-sm opacity-80">Tippe den vorgegebenen Satz. Mindestleistung 80 Wörter pro Minute</div>
      <div class="p-3 rounded-lg bg-gray-50 border text-sm leading-relaxed">
        {{ targetText }}
      </div>
      <textarea
        v-model="typedText"
        class="w-full border rounded-lg p-3 text-sm focus:outline-none focus:ring-2"
        rows="3"
        @input="onType"
        :maxlength="targetText.length"
        placeholder="Gib den Satz exakt ein"
      />
      <div class="flex items-center justify-between text-sm">
        <div>Genauigkeit {{ accuracyPercent }} Prozent</div>
        <div>WPM {{ currentWPM }}</div>
      </div>
      <div class="flex items-center gap-3">
        <div class="flex-1 h-2 rounded bg-gray-100 overflow-hidden">
          <div class="h-full bg-gray-700 transition-all" :style="{ width: Math.min(100, accuracyPercent) + '%' }"/>
        </div>
        <div class="w-16 text-right text-xs">{{ correctChars }}/{{ targetText.length }}</div>
      </div>
      <div v-if="typeFailMsg" class="text-xs text-red-700 text-center">{{ typeFailMsg }}</div>
    </div>

    <!-- Stufe 4 -->
    <div v-else-if="step === 4" class="space-y-3">
      <div class="text-sm opacity-80">
        Wimmelbild Aufgabe. Finde und klicke alle
        <span class="font-semibold">{{ targetEmoji }}</span>
      </div>
      <div class="text-xs opacity-60">Gefunden {{ foundTargets }} von {{ totalTargets }}</div>
      <div class="grid gap-1" :style="{ gridTemplateColumns: 'repeat(' + gridCols + ', minmax(0, 1fr))' }">
        <button
          v-for="cell in cells"
          :key="cell.id"
          class="aspect-square flex items-center justify-center text-xl border rounded active:scale-95 transition"
          :class="cellClass(cell)"
          @click="onCellClick(cell)"
        >
          {{ cell.emoji }}
        </button>
      </div>
      <div v-if="wimmelHint" class="text-xs opacity-60 text-center">Falscher Klick mischt das Grid</div>
    </div>

    <!-- Abschluss -->
    <div v-else class="space-y-4">
      <div class="text-green-700 font-medium">Erfolgreich verifiziert</div>
      <button class="px-4 py-2 rounded-lg bg-green-600 text-white shadow" @click="$emit('success')">Weiter</button>
    </div>

    <div class="mt-6">
      <div class="h-1 rounded bg-gray-100 overflow-hidden">
        <div class="h-full bg-gray-900 transition-all" :style="{ width: progressPercent + '%' }"/>
      </div>
      <div class="text-xs text-right mt-1 opacity-60">{{ uiStep }}/4</div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue'

const step = ref(1)

/* Stufe 1 */
const stage1Ref = ref(null)
const checkboxPos = ref({ x: 24, y: 24 })
const stage1Hint = ref(false)
let area = { w: 0, h: 0 }
const boxSize = { w: 220, h: 40 }
const clamp = (v, min, max) => Math.min(max, Math.max(min, v))

function measureArea() {
  const rect = stage1Ref.value?.getBoundingClientRect?.()
  if (rect) area = { w: rect.width, h: rect.height }
}

const rndPos = () => {
  measureArea()
  const x = Math.random() * Math.max(1, area.w - boxSize.w)
  const y = Math.random() * Math.max(1, area.h - boxSize.h)
  return { x, y }
}
function teleport() { checkboxPos.value = rndPos() }

function stage1MouseMove(e) {
  measureArea()
  const rect = stage1Ref.value.getBoundingClientRect()
  const cursor = { x: e.clientX - rect.left, y: e.clientY - rect.top }
  const dx = cursor.x - (checkboxPos.value.x + boxSize.w / 2)
  const dy = cursor.y - (checkboxPos.value.y + boxSize.h / 2)
  const dist = Math.hypot(dx, dy)
  const safe = 140
  if (dist < safe) {
    const f = (safe - dist) / safe
    const nx = clamp(checkboxPos.value.x - dx * 0.65 * f + (Math.random() - 0.5) * 40, 0, area.w - boxSize.w)
    const ny = clamp(checkboxPos.value.y - dy * 0.65 * f + (Math.random() - 0.5) * 40, 0, area.h - boxSize.h)
    checkboxPos.value = { x: nx, y: ny }
    stage1Hint.value = true
  }
}
let clickJumps = 0
let jumpInterval = null
function runawayClick() {
  if (jumpInterval) return
  measureArea()
  clickJumps = 0
  jumpInterval = setInterval(() => {
    teleport()
    clickJumps++
    if (clickJumps >= 10) {
      clearInterval(jumpInterval)
      jumpInterval = null
      setTimeout(() => step.value = 2, 300)
    }
  }, 120)
}

/* Stufe 2 */
const sliderValue = ref(0)
const targetVal = 67.67
const tol = 0.02
const preciseLocked = ref(false)
const holdPreciseProgress = ref(0)
let preciseTimer = null
function withinTol() { return Math.abs(sliderValue.value - targetVal) <= tol }
function handleSlider() {
  if (!preciseLocked.value) {
    if (withinTol()) {
      startPreciseHold()
    } else {
      stopPreciseHold()
      if (Math.abs(sliderValue.value - targetVal) <= 1.5) {
        const nudge = (Math.random() < 0.5 ? -1 : 1) * (0.07 + Math.random() * 0.12)
        sliderValue.value = clamp(sliderValue.value + nudge, 0, 100)
      }
    }
  }
}
function startPreciseHold() {
  if (preciseTimer) return
  const start = Date.now()
  preciseTimer = setInterval(() => {
    if (!withinTol()) { stopPreciseHold(); return }
    const elapsed = Date.now() - start
    holdPreciseProgress.value = Math.min(1, elapsed / 3000)
    if (holdPreciseProgress.value >= 1) {
      stopPreciseHold()
      preciseLocked.value = true
      setTimeout(() => step.value = 3, 400)
    }
  }, 16)
}
function stopPreciseHold() {
  clearInterval(preciseTimer)
  preciseTimer = null
  holdPreciseProgress.value = 0
}

/* Stufe 3 */
const sentences = [
  'Schnelle Systeme skalieren sauber nur mit stabilen Schnittstellen.',
  'Seriöse Software liefert Mehrwert wenn sie echte Probleme löst.',
  'Gute Architektur verhindert Chaos bevor es sichtbar wird.',
  'Datenqualität entscheidet über Präzision und Vertrauen.',
  'Automatisierte Tests sparen Kosten und Zeit im Betrieb.'
]
const targetText = ref('')
const typedText = ref('')
const typeStart = ref(null)
const typeFailMsg = ref('')
const correctChars = ref(0)
const accuracyPercent = computed(() => Math.floor((correctChars.value / Math.max(1, targetText.value.length)) * 100))
const currentWPM = computed(() => {
  if (!typeStart.value) return 0
  const minutes = (Date.now() - typeStart.value) / 60000
  const words = targetText.value.trim().split(/\s+/).length
  return Math.max(0, Math.floor(words / Math.max(0.0001, minutes)))
})
function pickSentence() {
  targetText.value = sentences[Math.floor(Math.random() * sentences.length)]
  typedText.value = ''
  typeStart.value = null
  correctChars.value = 0
  typeFailMsg.value = ''
}
function onType() {
  if (!typeStart.value && typedText.value.length > 0) typeStart.value = Date.now()
  const expect = targetText.value
  const given = typedText.value
  let i = 0
  while (i < given.length && i < expect.length && given[i] === expect[i]) i++
  if (i < given.length) typedText.value = given.slice(0, i)
  correctChars.value = i
  if (i === expect.length) {
    const wpm = currentWPM.value
    if (wpm >= 80) {
      setTimeout(() => step.value = 4, 300)
    } else {
      typeFailMsg.value = `Zu langsam. Erreicht ${wpm} WPM. Gefordert 80. Neuer Satz geladen`
      setTimeout(() => pickSentence(), 900)
    }
  }
}
watch(step, (s) => { if (s === 3) pickSentence() })

/* Stufe 4 */
const gridCols = 14
const gridRows = 14
const emojiPool = ['🍎','🍌','🍇','🍓','🍒','🍍','🥝','🥑','🍋','🍉','🫐','🥥','🍑','🍈','🌽','🥕','🧀','🍔','🍟','🍕','🥨','🥐','🍪','🍩','🧁','🍰','🍫','🍿','🍗','🥓','🍤','🍣','🍙','🍜','🍦','🥤','☕️','🍵','🥡','🥟','🥗','🍭','🎈','🎲','🎯','🧩','⚽️','🏀','🏈','🥎']
const cells = ref([])
const targetEmoji = ref('🎯')
const totalTargets = ref(0)
const foundTargets = ref(0)
const wimmelHint = ref(false)

function initGrid() {
  targetEmoji.value = emojiPool[Math.floor(Math.random() * emojiPool.length)]
  const poolWithoutTarget = emojiPool.filter(e => e !== targetEmoji.value)
  const total = gridCols * gridRows
  const tCount = Math.floor(6 + Math.random() * 4)
  totalTargets.value = tCount
  foundTargets.value = 0
  const ids = Array.from({ length: total }, (_, i) => i)
  const targetSlots = new Set()
  while (targetSlots.size < tCount) targetSlots.add(ids[Math.floor(Math.random() * ids.length)])
  cells.value = ids.map(id => {
    const isTarget = targetSlots.has(id)
    return {
      id,
      emoji: isTarget ? targetEmoji.value : poolWithoutTarget[Math.floor(Math.random() * poolWithoutTarget.length)],
      isTarget,
      clicked: false
    }
  })
}

function shuffleGrid() {
  cells.value = cells.value
    .map(c => ({ ...c, sort: Math.random() }))
    .sort((a, b) => a.sort - b.sort)
    .map(({ sort, ...c }) => c)
}

function onCellClick(cell) {
  if (cell.clicked) return
  if (cell.isTarget) {
    cell.clicked = true
    foundTargets.value++
    if (foundTargets.value >= totalTargets.value) {
      setTimeout(() => step.value = 5, 400)
    }
  } else {
    wimmelHint.value = true
    shuffleGrid()
  }
}

function cellClass(cell) {
  if (cell.isTarget && cell.clicked) return 'bg-green-100 border-green-400'
  if (!cell.isTarget && wimmelHint.value) return 'bg-red-50 border-red-300'
  return 'bg-gray-50'
}

watch(step, (s) => { if (s === 4) initGrid() })

/* Abschluss und Common */
onMounted(() => {
  measureArea()
  checkboxPos.value = { x: 24, y: 24 }
  window.addEventListener('resize', measureArea)
})
onBeforeUnmount(() => {
  clearInterval(jumpInterval)
  clearInterval(preciseTimer)
  window.removeEventListener('resize', measureArea)
})

const uiStep = computed(() => Math.min(step.value, 4))
const progressPercent = computed(() => (uiStep.value - 1) * 25)
</script>

<style scoped>
.grid { grid-auto-rows: 1fr; }
</style>