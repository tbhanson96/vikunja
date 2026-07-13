<template>
	<div
		class="loader-container task-preview"
		:class="{
			'is-loading': taskService.loading || !visible,
			'is-modal': isModal,
		}"
	>
		<div
			v-if="visible"
			class="task-preview__content"
		>
			<header class="task-preview__header">
				<BaseButton
					v-if="!isModal"
					class="task-preview__back"
					@click="lastProject ? router.back() : router.push(projectRoute)"
				>
					<Icon icon="arrow-left" />
					{{ $t('task.detail.back') }}
				</BaseButton>
				<BaseButton
					v-else
					class="task-preview__close"
					:aria-label="$t('task.detail.closeTaskDetail')"
					@click="$emit('close')"
				>
					<Icon icon="times" />
				</BaseButton>

				<div class="task-preview__title-row">
					<label class="task-preview__done">
						<input
							type="checkbox"
							:checked="task.done"
							:disabled="!canWrite || taskService.loading"
							:aria-label="$t('task.detail.markAsDone', {task: task.title})"
							@change="toggleTaskDone"
						>
					</label>
					<div class="task-preview__title-block">
						<p
							v-if="taskIdentifier"
							class="task-preview__identifier"
						>
							{{ taskIdentifier }}
						</p>
						<h1 :class="{'is-done': task.done}">
							{{ task.title }}
						</h1>
					</div>
				</div>

				<div class="task-preview__actions">
					<RouterLink
						v-if="canWrite"
						class="button is-primary"
						:to="editRoute"
					>
						<Icon icon="pen" />
						{{ $t('misc.edit') }}
					</RouterLink>
				</div>
			</header>

			<nav
				v-if="project?.id"
				aria-label="Breadcrumb"
				class="task-preview__project"
			>
				<RouterLink :to="{ name: 'project.index', params: { projectId: project.id } }">
					{{ projectTitle }}
				</RouterLink>
			</nav>

			<ChecklistSummary :task="task" />

			<section
				v-if="hasMetadata"
				class="task-preview__metadata"
			>
				<div
					v-if="task.assignees.length > 0"
					class="task-preview__field"
				>
					<span>{{ $t('task.attributes.assignees') }}</span>
					<AssigneeList
						:assignees="task.assignees"
						inline
					/>
				</div>
				<div
					v-if="task.labels.length > 0"
					class="task-preview__field"
				>
					<span>{{ $t('task.attributes.labels') }}</span>
					<Labels :labels="task.labels" />
				</div>
				<div
					v-if="task.priority > priorities.UNSET"
					class="task-preview__field"
				>
					<span>{{ $t('task.attributes.priority') }}</span>
					<PriorityLabel
						:priority="task.priority"
						:done="task.done"
						show-all
					/>
				</div>
				<div
					v-if="task.dueDate"
					class="task-preview__field"
				>
					<span>{{ $t('task.attributes.dueDate') }}</span>
					<time :datetime="formatISO(task.dueDate)">
						{{ formatDisplayDate(task.dueDate) }}
					</time>
				</div>
				<div
					v-if="task.startDate"
					class="task-preview__field"
				>
					<span>{{ $t('task.attributes.startDate') }}</span>
					<time :datetime="formatISO(task.startDate)">
						{{ formatDisplayDate(task.startDate) }}
					</time>
				</div>
				<div
					v-if="task.endDate"
					class="task-preview__field"
				>
					<span>{{ $t('task.attributes.endDate') }}</span>
					<time :datetime="formatISO(task.endDate)">
						{{ formatDisplayDate(task.endDate) }}
					</time>
				</div>
				<div
					v-if="task.percentDone > 0"
					class="task-preview__field"
				>
					<span>{{ $t('task.attributes.percentDone') }}</span>
					<span>{{ task.percentDone * 100 }}%</span>
				</div>
			</section>

			<Description
				:model-value="task"
				:attachment-upload="noopUpload"
				:can-write="false"
			/>

			<footer class="task-preview__footer">
				<CreatedUpdated :task="task" />
				<div class="task-preview__counts">
					<span v-if="task.attachments.length > 0">
						<Icon icon="paperclip" />
						{{ task.attachments.length }}
					</span>
					<span v-if="commentCount > 0">
						<Icon icon="comments" />
						{{ commentCount }}
					</span>
				</div>
			</footer>
		</div>
	</div>
</template>

<script setup lang="ts">
import {computed, nextTick, ref, shallowReactive, watch} from 'vue'
import {useRouter, useRoute, type RouteLocation, onBeforeRouteLeave} from 'vue-router'
import {useI18n} from 'vue-i18n'

import BaseButton from '@/components/base/BaseButton.vue'
import AssigneeList from '@/components/tasks/partials/AssigneeList.vue'
import ChecklistSummary from '@/components/tasks/partials/ChecklistSummary.vue'
import CreatedUpdated from '@/components/tasks/partials/CreatedUpdated.vue'
import Description from '@/components/tasks/partials/Description.vue'
import Labels from '@/components/tasks/partials/Labels.vue'
import PriorityLabel from '@/components/tasks/partials/PriorityLabel.vue'

import TaskService from '@/services/task'
import TaskModel, {getTaskIdentifier} from '@/models/task'
import type {ITask} from '@/modelTypes/ITask'
import type {IProject} from '@/modelTypes/IProject'

import {PRIORITIES as priorities} from '@/constants/priorities'
import {PERMISSIONS} from '@/constants/permissions'
import {formatDisplayDate, formatISO} from '@/helpers/time/formatDate'
import {getProjectTitle} from '@/helpers/getProjectTitle'
import {playPopSound} from '@/helpers/playPop'
import {useTitle} from '@/composables/useTitle'
import {useBaseStore} from '@/stores/base'
import {useProjectStore} from '@/stores/projects'
import {useTaskStore} from '@/stores/tasks'
import {success} from '@/message'

const props = defineProps<{
	taskId: ITask['id'],
	backdropView?: RouteLocation['fullPath'],
}>()

defineEmits<{
	'close': [],
}>()

const router = useRouter()
const route = useRoute()
const {t} = useI18n({useScope: 'global'})

const baseStore = useBaseStore()
const projectStore = useProjectStore()
const taskStore = useTaskStore()

const task = ref<ITask>(new TaskModel())
const taskService = shallowReactive(new TaskService())
const visible = ref(false)
const taskNotFound = ref(false)

const project = computed(() => projectStore.projects[task.value.projectId])
const projectTitle = computed(() => project.value ? getProjectTitle(project.value as IProject) : '')
const taskIdentifier = computed(() => getTaskIdentifier(task.value))
const isModal = computed(() => Boolean(props.backdropView))
const canWrite = computed(() => task.value.maxPermission !== null && task.value.maxPermission > PERMISSIONS.READ)
const commentCount = computed(() => task.value.commentCount ?? task.value.comments?.length ?? 0)
const hasMetadata = computed(() => (
	task.value.assignees.length > 0 ||
	task.value.labels.length > 0 ||
	task.value.priority > priorities.UNSET ||
	Boolean(task.value.dueDate) ||
	Boolean(task.value.startDate) ||
	Boolean(task.value.endDate) ||
	task.value.percentDone > 0
))

useTitle(computed(() => task.value.title))

const lastProject = computed(() => {
	const backRoute = router.options.history.state?.back
	if (!backRoute || typeof backRoute !== 'string') {
		return null
	}

	const projectMatch = backRoute.match(/\/projects\/(-?\d+)/)
	if (!projectMatch || !projectMatch[1]) {
		return null
	}

	const id = parseInt(projectMatch[1])

	return projectStore.projects[id] ?? null
})

const projectRoute = computed(() => ({
	name: 'project.index',
	params: {projectId: task.value.projectId},
	hash: route.hash,
}))

const editRoute = computed(() => ({
	name: 'task.edit',
	params: {id: task.value.id},
	state: props.backdropView ? {backdropView: props.backdropView} : undefined,
}))

onBeforeRouteLeave(async () => {
	if (taskNotFound.value) {
		return
	}

	const projectToRestore = (lastProject.value ?? project.value) as IProject | undefined
	if (projectToRestore) {
		await baseStore.handleSetCurrentProjectIfNotSet(projectToRestore)
	}
})

watch(
	() => props.taskId,
	async (id) => {
		if (id === undefined) {
			return
		}

		visible.value = false

		try {
			const loaded = await taskService.get(new TaskModel({id}), {expand: ['reactions', 'comments', 'is_unread', 'buckets']})
			task.value = loaded

			if (task.value.isUnread) {
				await taskStore.markTaskAsRead(task.value.id)
				task.value.isUnread = false
			}

			if (lastProject.value) {
				await baseStore.handleSetCurrentProjectIfNotSet(lastProject.value as IProject)
			}
		} catch (e: unknown) {
			if (typeof e === 'object' && e !== null && 'response' in e && (e.response as {status?: number})?.status === 404) {
				taskNotFound.value = true
				router.replace({name: 'not-found'})
				return
			}

			throw e
		} finally {
			await nextTick()
			visible.value = true
		}
	},
	{immediate: true},
)

async function toggleTaskDone(event: Event) {
	if (!canWrite.value || !(event.target instanceof HTMLInputElement)) {
		return
	}

	const updated = await taskStore.update({
		...task.value,
		done: event.target.checked,
	})

	task.value = updated

	if (updated.done) {
		playPopSound()
	}

	success({message: updated.done ? t('task.doneSuccess') : t('task.undoneSuccess')})
}

async function noopUpload() {
	return ''
}
</script>

<style lang="scss" scoped>
.task-preview {
	inline-size: min(100%, 52rem);
	margin: 0 auto;

	&.is-modal {
		inline-size: min(100vw - 2rem, 42rem);
		margin: 0;
	}
}

.task-preview__content {
	background: var(--site-background);
	border-radius: $radius;
	padding: 1.5rem;
}

.task-preview__header {
	display: grid;
	gap: 1rem;
}

.task-preview__back,
.task-preview__close {
	justify-self: start;
	display: inline-flex;
	align-items: center;
	gap: .5rem;
}

.task-preview__title-row {
	display: grid;
	grid-template-columns: auto 1fr;
	gap: .75rem;
	align-items: start;
}

.task-preview__done {
	padding-block-start: .35rem;
}

.task-preview__title-block h1 {
	font-size: 1.75rem;
	line-height: 1.2;
	margin: 0;
	overflow-wrap: anywhere;

	&.is-done {
		color: var(--grey-500);
		text-decoration: line-through;
	}
}

.task-preview__identifier {
	color: var(--grey-500);
	font-size: .85rem;
	margin-block-end: .25rem;
}

.task-preview__actions {
	display: flex;
	gap: .75rem;
	flex-wrap: wrap;
}

.task-preview__project {
	margin-block-start: 1rem;
	color: var(--grey-600);
}

.task-preview__metadata {
	display: grid;
	grid-template-columns: repeat(auto-fit, minmax(12rem, 1fr));
	gap: 1rem;
	margin-block: 1.5rem;
}

.task-preview__field {
	display: grid;
	gap: .35rem;

	> span:first-child {
		color: var(--grey-500);
		font-size: .8rem;
		font-weight: 600;
		text-transform: uppercase;
	}
}

.task-preview__footer {
	display: flex;
	justify-content: space-between;
	gap: 1rem;
	align-items: center;
	margin-block-start: 1.5rem;
	color: var(--grey-500);
	font-size: .85rem;
}

.task-preview__counts {
	display: inline-flex;
	gap: .75rem;
	align-items: center;

	span {
		display: inline-flex;
		gap: .25rem;
		align-items: center;
	}
}

@media screen and (max-width: $tablet) {
	.task-preview,
	.task-preview.is-modal {
		inline-size: 100%;
	}

	.task-preview__content {
		padding: 1rem;
	}

	.task-preview__footer {
		align-items: flex-start;
		flex-direction: column;
	}
}
</style>
