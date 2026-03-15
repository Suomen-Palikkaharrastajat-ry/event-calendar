import fs from 'fs';
import path from 'path';
import PocketBase from 'pocketbase';

export const pocketBaseUrl = 'https://data.palikkaharrastajat.fi';

const dayAbbr = ['su', 'ma', 'ti', 'ke', 'to', 'pe', 'la'];

export function toHelsinkiDate(utcString) {
	const date = toUtcDate(utcString);
	return new Date(date.toLocaleString('en-US', { timeZone: 'Europe/Helsinki' }));
}

export function toUtcDate(utcString) {
	return new Date(utcString.endsWith('Z') ? utcString : utcString + 'Z');
}

export function createPocketBaseClient() {
	return new PocketBase(pocketBaseUrl);
}

export async function fetchPublishedEvents(pb) {
	const yesterday = new Date();
	yesterday.setDate(yesterday.getDate() - 1);
	const yesterdayIso = yesterday.toISOString().split('T')[0] + ' 00:00:00';
	return pb.collection('events').getFullList({
		sort: 'start_date',
		filter: `state = "published" && (end_date > "${yesterdayIso}" || start_date > "${yesterdayIso}")`
	});
}

export function formatDateInHelsinki(utcString, allDay = false) {
	const helsinkiDate = toHelsinkiDate(utcString);
	const day = String(helsinkiDate.getDate());
	const month = String(helsinkiDate.getMonth() + 1);
	const dateStr = `${day}.${month}.`;
	if (allDay) {
		return dateStr;
	}
	const hours = String(helsinkiDate.getHours()).padStart(2, '0');
	const minutes = String(helsinkiDate.getMinutes()).padStart(2, '0');
	const timeStr = `${hours}.${minutes}`;
	return `${dateStr} ${timeStr}`;
}

export function formatEventDisplayDate(event) {
	const startFormatted = formatDateInHelsinki(event.start_date, event.all_day);
	let dateStr = startFormatted;
	if (event.end_date) {
		const endFormatted = formatDateInHelsinki(event.end_date, event.all_day);
		if (startFormatted !== endFormatted) {
			if (event.all_day) {
				const startParts = startFormatted.split('.');
				const endParts = endFormatted.split('.');
				if (startParts[1] === endParts[1]) {
					dateStr = `${startParts[0]}.–${endParts[0]}.${startParts[1]}.`;
				} else {
					dateStr += `–${endFormatted}`;
				}
			} else {
				const startDatePart = startFormatted.split(' ')[0];
				const endDatePart = endFormatted.split(' ')[0];
				if (startDatePart === endDatePart) {
					const endTime = endFormatted.split(' ')[1];
					dateStr += `–${endTime}`;
				} else {
					dateStr += `–${endFormatted}`;
				}
			}
		}
	}
	if (event.all_day) {
		const startUtc = toUtcDate(event.start_date);
		const startHelsinki = toHelsinkiDate(event.start_date);
		let prefix = '';
		if (event.end_date && event.end_date !== event.start_date) {
			const endUtc = toUtcDate(event.end_date);
			const endHelsinki = toHelsinkiDate(event.end_date);
			const duration = Math.ceil((endUtc - startUtc) / (24 * 60 * 60 * 1000)) + 1;
			if (duration < 8) {
				prefix = `${dayAbbr[startHelsinki.getDay()]}–${dayAbbr[endHelsinki.getDay()]} `;
			}
		} else {
			prefix = `${dayAbbr[startHelsinki.getDay()]} `;
		}
		return prefix + dateStr;
	}
	const startDatePart = startFormatted.split(' ')[0];
	const endDatePart = event.end_date
		? formatDateInHelsinki(event.end_date, false).split(' ')[0]
		: null;
	const isSingleDay = !event.end_date || startDatePart === endDatePart;
	if (isSingleDay) {
		const startHelsinki = toHelsinkiDate(event.start_date);
		const parts = dateStr.split(' ');
		if (parts.length === 2) {
			return `${dayAbbr[startHelsinki.getDay()]} ${parts[0]} klo ${parts[1]}`;
		}
	}
	return dateStr;
}

export function writeStaticFile(relativePath, content) {
	const staticPath = path.join('static', relativePath);
	fs.mkdirSync(path.dirname(staticPath), { recursive: true });
	fs.writeFileSync(staticPath, content);
	if (!fs.existsSync('build')) {
		return;
	}
	const buildPath = path.join('build', relativePath);
	fs.mkdirSync(path.dirname(buildPath), { recursive: true });
	fs.writeFileSync(buildPath, content);
}
