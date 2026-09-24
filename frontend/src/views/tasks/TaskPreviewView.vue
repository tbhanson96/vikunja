<template>
	<div
		class="loader-container task-preview"
		:class="{'is-loading': query.isLoading.value || updateTask.isPending.value, 'is-modal': isModal}"
	>
		<div
			v-if="task"
			class="task-preview__content"
		>
			<header class="task-preview__header">
				<BaseButton
					v-if="!isModal"
					class="task-preview__back"
					@click="router.back()"
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
							:disabled="!canWrite || updateTask.isPending.value"
							:aria-label="$t('task.detail.markAsDone', {task: task.title})"
							@change="toggleTaskDone"
						>
					</label>
					<div class="task-preview__title-block">
						<p class="task-preview__identifier">
							{{ getTaskIdentifier(task) }}
						</p>
						<h1 :class="{'is-done': task.done}">
							{{ task.title }}
						</h1>
					</div>
				</div>

				<RouterLink
					v-if="canWrite"
					class="button is-primary task-preview__edit"
					:to="editRoute"
				>
					<Icon icon="pen" />
					{{ $t('project.list.editTask') }}
				</RouterLink>
			</header>

			<nav
				v-if="project?.id"
				aria-label="Breadcrumb"
				class="task-preview__project"
			>
				<RouterLink :to="{name: 'project.index', params: {projectId: project.id}}">
					{{ getProjectTitle(project) }}
				</RouterLink>
			</nav>

			<ChecklistSummary :task="task" />

			<section
				v-if="hasMetadata"
				class="task-preview__metadata"
			>
				<div
					v-if="task.assignees?.length"
					class="task-preview__field"
				>
					<span>{{ $t('task.attributes.assignees') }}</span>
					<AssigneeList
						:assignees="task.assignees"
						inline
					/>
				</div>
				<div
					v-if="task.labels?.length"
					class="task-preview__field"
				>
					<span>{{ $t('task.attributes.labels') }}</span>
					<Labels :labels="task.labels" />
				</div>
				<div
					v-if="(task.priority ?? 0) > PRIORITIES.UNSET"
					class="task-preview__field"
				>
					<span>{{ $t('task.attributes.priority') }}</span>
					<PriorityLabel
						:priority="task.priority ?? 0"
						:done="task.done"
						show-all
					/>
				</div>
				<div
					v-if="task.due_date"
					class="task-preview__field"
				>
					<span>{{ $t('task.attributes.dueDate') }}</span>
					<time :datetime="formatISO(task.due_date)">{{ formatDisplayDate(task.due_date) }}</time>
				</div>
				<div
					v-if="task.start_date"
					class="task-preview__field"
				>
					<span>{{ $t('task.attributes.startDate') }}</span>
					<time :datetime="formatISO(task.start_date)">{{ formatDisplayDate(task.start_date) }}</time>
				</div>
				<div
					v-if="task.end_date"
					class="task-preview__field"
				>
					<span>{{ $t('task.attributes.endDate') }}</span>
					<time :datetime="formatISO(task.end_date)">{{ formatDisplayDate(task.end_date) }}</time>
				</div>
				<div
					v-if="task.percent_done"
					class="task-preview__field"
				>
					<span>{{ $t('task.attributes.percentDone') }}</span>
					<span>{{ task.percent_done * 100 }}%</span>
				</div>
			</section>

			<Description
				:model-value="task"
				:can-write="false"
			/>

			<footer class="task-preview__footer">
				<CreatedUpdated :task="task" />
				<div class="task-preview__counts">
					<span v-if="task.attachments?.length"><Icon icon="paperclip" /> {{ task.attachments.length }}</span>
					<span v-if="commentCount"><Icon icon="comments" /> {{ commentCount }}</span>
				</div>
			</footer>
		</div>
	</div>
</template>

<script setup lang="ts">
import {computed} from 'vue'
import {useRouter, type RouteLocation} from 'vue-router'
import {useI18n} from 'vue-i18n'

import BaseButton from '@/components/base/BaseButton.vue'
import AssigneeList from '@/components/tasks/partials/AssigneeList.vue'
import ChecklistSummary from '@/components/tasks/partials/ChecklistSummary.vue'
import CreatedUpdated from '@/components/tasks/partials/CreatedUpdated.vue'
import Description from '@/components/tasks/partials/Description.vue'
import Labels from '@/components/tasks/partials/Labels.vue'
import PriorityLabel from '@/components/tasks/partials/PriorityLabel.vue'
import {PRIORITIES} from '@/constants/priorities'
import {PERMISSIONS} from '@/constants/permissions'
import {formatDisplayDate, formatISO} from '@/helpers/time/formatDate'
import {getProjectTitle} from '@/helpers/getProjectTitle'
import {getTaskIdentifier} from '@/helpers/task'
import {playPopSound} from '@/helpers/playPop'
import {useTask} from '@/composables/useTask'
import {useProjects} from '@/composables/useProjects'
import {useTitle} from '@/composables/useTitle'
import {useUpdateTaskMutation} from '@/client/queries/taskMutations'
import {success} from '@/message'

const props = defineProps<{taskId: number, backdropView?: RouteLocation['fullPath']}>()
defineEmits<{'close': []}>()

const router = useRouter()
const {t} = useI18n({useScope: 'global'})
const projects = useProjects()
const query = useTask(() => props.taskId, ['comments', 'buckets'])
const updateTask = useUpdateTaskMutation()
const task = computed(() => query.task.value)
const project = computed(() => projects.projects[task.value?.project_id ?? 0])
const isModal = computed(() => Boolean(props.backdropView))
const canWrite = computed(() => (task.value?.max_permission ?? 0) > PERMISSIONS.READ)
const commentCount = computed(() => task.value?.comment_count ?? task.value?.comments?.length ?? 0)
const hasMetadata = computed(() => Boolean(
	(task.value?.assignees?.length ?? 0) ||
	(task.value?.labels?.length ?? 0) ||
	(task.value?.priority ?? 0) > PRIORITIES.UNSET ||
	task.value?.due_date || task.value?.start_date || task.value?.end_date || task.value?.percent_done,
))
const editRoute = computed(() => ({
	name: 'task.edit',
	params: {id: props.taskId},
	state: props.backdropView ? {backdropView: props.backdropView} : undefined,
}))

useTitle(computed(() => task.value?.title ?? ''))

async function toggleTaskDone(event: Event) {
	if (!task.value || !canWrite.value || !(event.target instanceof HTMLInputElement)) return
	const updated = await updateTask.mutateAsync({...task.value, done: event.target.checked})
	if (updated.done) playPopSound()
	success({message: updated.done ? t('task.doneSuccess') : t('task.undoneSuccess')})
}
</script>

<style lang="scss" scoped>
.task-preview { inline-size: min(100%, 52rem); margin: 0 auto; }
.task-preview.is-modal { inline-size: min(100vw - 2rem, 42rem); margin: 0; }
.task-preview__content { background: var(--site-background); border-radius: $radius; padding: 1.5rem; }
.task-preview__header { display: grid; gap: 1rem; }
.task-preview__back, .task-preview__close { justify-self: start; display: inline-flex; align-items: center; gap: .5rem; }
.task-preview__title-row { display: grid; grid-template-columns: auto 1fr; gap: .75rem; align-items: start; }
.task-preview__done { padding-block-start: .35rem; }
.task-preview__title-block h1 { font-size: 1.75rem; line-height: 1.2; margin: 0; overflow-wrap: anywhere; }
.task-preview__title-block h1.is-done { color: var(--grey-500); text-decoration: line-through; }
.task-preview__identifier { color: var(--grey-500); font-size: .85rem; margin-block-end: .25rem; }
.task-preview__edit { justify-self: start; }
.task-preview__project { margin-block-start: 1rem; color: var(--grey-600); }
.task-preview__metadata { display: grid; grid-template-columns: repeat(auto-fit, minmax(12rem, 1fr)); gap: 1rem; margin-block: 1.5rem; }
.task-preview__field { display: grid; gap: .35rem; }
.task-preview__field > span:first-child { color: var(--grey-500); font-size: .8rem; font-weight: 600; text-transform: uppercase; }
.task-preview__footer { display: flex; justify-content: space-between; gap: 1rem; align-items: center; margin-block-start: 1.5rem; color: var(--grey-500); font-size: .85rem; }
.task-preview__counts { display: inline-flex; gap: .75rem; align-items: center; }
.task-preview__counts span { display: inline-flex; gap: .25rem; align-items: center; }
@media screen and (max-width: $tablet) {
	.task-preview, .task-preview.is-modal { inline-size: 100%; }
	.task-preview__content { padding: 1rem; }
	.task-preview__footer { align-items: flex-start; flex-direction: column; }
}
</style>
