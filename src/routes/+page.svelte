<script lang="ts">
	/* eslint-disable @typescript-eslint/no-explicit-any */
	/* eslint-disable svelte/prefer-svelte-reactivity, svelte/no-navigation-without-resolve */
	import { onMount } from 'svelte';
	import { pb } from '$lib/pocketbase';
	import type { Event } from '$lib/types';
	// @ts-expect-error Calendar library types not available
	import { Calendar, DayGrid, List } from '@event-calendar/core';
	import '@event-calendar/core/index.css';
	import { Datepicker } from 'flowbite-svelte';
	import { _ } from 'svelte-i18n';
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { parseUTCDate, dateToHelsinkiDateString } from '$lib/date-utils';
	import { user } from '$lib/auth';
	import { page } from '$app/stores';
	import { browser } from '$app/environment';

	let events: Event[] = [];
	let calendarWrapper: HTMLElement;
	let selectedDate = $state(new Date());
	let calendarOptions = $state({
		view: 'dayGridMonth',
		events: [] as any[],
		date: selectedDate,
		locale: 'fi',
		firstDay: 1,
		buttonText: {
			listMonth: $_('list'),
			dayGridMonth: $_('calendar'),
			today: $_('today'),
			prev: $_('prev'),
			next: $_('next_button')
		},
		headerToolbar: { start: 'title', center: '', end: 'today prev,next' },
		eventClassNames: (info: any) => {
			const classes = [];
			if (info.event.allDay) {
				classes.push('event-allday');
			} else {
				classes.push('event-regular');
			}
			if (info.event.id !== 'selected-day') {
				classes.push('event-clickable');
			}
			return classes;
		},
		eventDidMount: (info: unknown) => {
			if ((info as any).event.extendedProps.description) {
				(info as any).el.title = (info as any).event.extendedProps.description;
			}
			// Make events accessible with keyboard navigation
			if ((info as any).event.id !== 'selected-day') {
				(info as any).el.addEventListener('keydown', (e: KeyboardEvent) => {
					if (e.key === 'Enter' || e.key === ' ') {
						e.preventDefault();
						(info as any).el.click();
					}
				});
			}
		},
		eventClick: (info: unknown) => {
			if ((info as any).event.id === 'selected-day') return;
			goto(resolve(`/events/${(info as any).event.id}`));
		},
		dateClick: (info: unknown) => {
			selectedDate = (info as any).date;
		}
	});

	if (browser) {
		const searchParams = new URLSearchParams(window.location.search);
		const dateParam = searchParams.get('date');
		if (dateParam) {
			const paramDate = new Date(`${dateParam}T00:00:00`);
			if (!Number.isNaN(paramDate.getTime())) {
				selectedDate = paramDate;
			}
		}
	}

	onMount(async () => {
		events = await pb.collection('events').getFullList({
			sort: 'start_date',
			filter: 'state = "published"'
		});
		updateCalendarEvents();
		// Focus the Next button after calendar is rendered
		setTimeout(() => {
			const nextBtn = calendarWrapper?.querySelector('.ec-next') as HTMLElement;
			nextBtn?.focus();
		}, 100);
	});

	$effect(() => {
		const dateParam = $page.url.searchParams.get('date');
		if (!dateParam) return;

		const paramDate = new Date(`${dateParam}T00:00:00`);
		if (!Number.isNaN(paramDate.getTime()) && paramDate.getTime() !== selectedDate.getTime()) {
			selectedDate = paramDate;
		}
		// Clear the date from querystring after consuming it
		const newUrl = new URL($page.url);
		newUrl.searchParams.delete('date');
		// @ts-ignore
		goto(resolve(newUrl.pathname + newUrl.search, { replaceState: true }));
	});

	function updateCalendarEvents() {
		calendarOptions.events = [
			...events.map((event, index) => ({
				id: event.id,
				title: event.location ? `${event.title} / ${event.location}` : event.title,
				start: parseUTCDate(event.start_date),
				end: (() => {
					const baseEnd = event.end_date
						? parseUTCDate(event.end_date)
						: parseUTCDate(event.start_date);
					if (event.all_day) {
						const adjusted = new Date(baseEnd);
						adjusted.setDate(adjusted.getDate() + 1);
						return adjusted;
					}
					return baseEnd;
				})(),
				allDay: event.all_day,
				display: event.all_day ? 'block' : 'auto',
				extendedProps: {
					description: event.description || '',
					order: index + 1
				}
			})),
			{
				id: 'selected-day',
				start: dateToHelsinkiDateString(selectedDate),
				end: dateToHelsinkiDateString(selectedDate),
				display: 'background',
				backgroundColor: '#e0f7fa',
				borderColor: '#00bcd4'
			}
		];
	}

	$effect(() => {
		calendarOptions.date = selectedDate;
		updateCalendarEvents();
	});
</script>

<svelte:head>
	<title>{$_('event_calendar')}</title>
	<meta name="description" content={$_('event_calendar_description')} />
</svelte:head>

{#if $user}
	<div class="mb-4 flex items-end gap-4">
		<div class="flex-1">
			<label for="datepicker" class="invisible block text-sm font-medium text-gray-700"
				>{$_('select_date')}</label
			>
			{#key selectedDate.getTime()}
				<Datepicker
					id="datepicker"
					bind:value={selectedDate}
					defaultDate={selectedDate}
					locale="fi"
					firstDayOfWeek={1}
				/>
			{/key}
		</div>
		<button
			class="flex h-12 w-12 flex-shrink-0 cursor-pointer items-center justify-center rounded-full border-none bg-primary-500 text-xl font-bold text-white transition-colors duration-200 hover:bg-primary-600"
			onclick={() => goto(resolve(`/events?date=${dateToHelsinkiDateString(selectedDate)}`) as any)}
			title="Add new event"
			>+
		</button>
	</div>
{:else}
	<p>
		{$_('non_member_prefix')}<a
			style="text-decoration: underline; color: blue;"
			href="mailto:palikkaharrastajatry@outlook.com?subject=Uusi%20tapahtuma%20Palikkakalenteriin&body=Tapahtuman%20nimi%3A%0D%0A%0D%0ATarkempi%20kuvaus%3A%0D%0A%0D%0APaikkakunta%3A%0D%0A%0D%0AAlkaa%3A%0D%0A%0D%0AP%C3%A4%C3%A4ttyy%3A%0D%0A%0D%0AKotisivut%3A%0D%0A%0D%0A"
			>{$_('send_event_email')}</a
		>.
	</p>
	<div class="mb-4">
		<label for="datepicker" class="invisible block text-sm font-medium text-gray-700"
			>{$_('select_date')}</label
		>
		{#key selectedDate.getTime()}
			<Datepicker
				id="datepicker"
				bind:value={selectedDate}
				defaultDate={selectedDate}
				locale="fi"
				firstDayOfWeek={1}
			/>
		{/key}
	</div>
{/if}

<div bind:this={calendarWrapper}>
	<Calendar plugins={[List, DayGrid]} options={calendarOptions} />
</div>
