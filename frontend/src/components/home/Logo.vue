<script setup lang="ts">
import {computed} from 'vue'
import {useColorScheme} from '@/composables/useColorScheme'
import tasksBrand from '@/assets/tasks-brand.png'

const {isDark} = useColorScheme()

const CustomLogo = computed(() => {
	const lightLogo = window.CUSTOM_LOGO_URL
	const darkLogo = window.CUSTOM_LOGO_URL_DARK

	if (!lightLogo && !darkLogo) return ''
	if (!darkLogo) return lightLogo
	if (!lightLogo) return darkLogo

	return isDark.value ? darkLogo : lightLogo
})
</script>

<template>
	<div>
		<img
			v-if="!CustomLogo"
			:src="tasksBrand"
			alt="Tasks"
			class="logo"
		>
		<img
			v-show="CustomLogo"
			:src="CustomLogo"
			alt="Tasks"
			class="logo"
		>
	</div>
</template>

<style lang="scss" scoped>
.logo {
	color: var(--logo-text-color);
	max-inline-size: 168px;
	max-block-size: 48px;
}
</style>
