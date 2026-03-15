import { Feed } from 'feed';
import ical from 'ical-generator';
import qrcode from 'qrcode';
import fs from 'fs';
import path from 'path';

import {
	createPocketBaseClient,
	fetchPublishedEvents,
	formatDateInHelsinki,
	formatEventDisplayDate,
	toHelsinkiDate,
	writeStaticFile,
	pocketBaseUrl
} from './generate-utils.js';

const baseUrl = 'https://kalenteri.palikkaharrastajat.fi';

const monthNames = [
	'Tammikuu',
	'Helmikuu',
	'Maaliskuu',
	'Huhtikuu',
	'Toukokuu',
	'Kesäkuu',
	'Heinäkuu',
	'Elokuu',
	'Syyskuu',
	'Lokakuu',
	'Marraskuu',
	'Joulukuu'
];

function groupEventsByMonth(events) {
	const groups = new Map();
	events.forEach((event) => {
		const helsinkiDate = toHelsinkiDate(event.start_date);
		const year = helsinkiDate.getFullYear();
		const month = helsinkiDate.getMonth();
		const key = `${year}-${month}`;
		if (!groups.has(key)) {
			groups.set(key, { year, month, events: [] });
		}
		groups.get(key).events.push(event);
	});
	return groups;
}

async function generateEmbed(events) {
	const nowIso = new Date().toISOString();
	const groups = groupEventsByMonth(events);

	let html = `<!DOCTYPE html>
<html lang="fi">
<head>
<meta charset="UTF-8">
<title>Palikkakalenteri</title>
<meta name="build-date" content="${nowIso}">
	<style>
:root {
	--color-brand-primary: #000000; /*#38419d*/
	--color-brand-accent: #000000; /*#52d3d8*/
}
body { font-family: Arial, sans-serif; margin: 20px; }
.month { page-break-inside: avoid; break-inside: avoid; }
.month-header { font-size: 1.5em; font-weight: bold; color: var(--color-brand-primary); margin: 3ex 0 1.5ex 0; border-bottom: 2px solid var(--color-brand-accent); padding-bottom: 5px; }
.event { display: flex; margin-top: 0.5ex; margin-bottom: 20px; border-left: 3px solid var(--color-brand-accent); padding-left: 15px; }
.event { page-break-inside: avoid; break-inside: avoid; }
.date-column { flex: 0 0 200px; font-weight: bold; color: var(--color-brand-primary); }
.details-column { flex: 1; }
.details-column h2 { margin-top: -0.5ex; margin-bottom: 0; }
.details-column p { margin: 1ex 0 1.5ex 0; hyphens: auto; }
.qrcode { display: none; }
@media print {
.qrcode { display: flex; }
.readmore { display: none; }
}
</style>
</head>
<body>
<h1>Palikkakalenteri</h1>
<div class="events">
`;

	for (const group of groups.values()) {
		html += `<div class="month">`;
		html += `<div class="month-header">${monthNames[group.month]} ${group.year}</div>`;
		for (const event of group.events) {
			const dateStr = formatEventDisplayDate(event);
			let qrCodeDataUri = '';
			// Generate QR code for all events since they all have ICS files now
			qrCodeDataUri = await qrcode.toDataURL(`${baseUrl}/events/${event.id}.html`, {
				errorCorrectionLevel: 'M',
				width: 100,
				margin: 1
			});

			// Generate data URI for event-specific ICS
			const individualCalendar = ical({
				title: 'Palikkakalenteri',
				description: 'Suomen Palikkayhteisö ry:n Palikkakalenteri',
				timezone: 'Europe/Helsinki'
			});

			const startDate = toHelsinkiDate(event.start_date);
			let endDate = event.end_date
				? toHelsinkiDate(event.end_date)
				: new Date(startDate.getTime() + (event.all_day ? 24 * 60 * 60 * 1000 : 60 * 60 * 1000));

			if (event.all_day) {
				endDate = new Date(endDate.getTime() + 24 * 60 * 60 * 1000);
			}
			const description = event.description || event.title;
			const eventUrl =
				event.url || `https://kalenteri.palikkaharrastajat.fi/#/events/${event.id}`;

			const eventData = {
				id: `${baseUrl}/#/events/${event.id}`,
				start: startDate,
				end: endDate,
				summary:
					event.all_day && event.location
						? `${event.title} | ${event.location.split(',')[0].trim()}`
						: event.title,
				description,
				url: eventUrl,
				timezone: 'Europe/Helsinki'
			};

			// Set location data
			if (event.location) {
				const loc = { title: event.location };
				if (event.point && event.point.lat !== 0 && event.point.lon !== 0) {
					loc.geo = { lat: event.point.lat, lon: event.point.lon };
				}
				eventData.location = loc;
			}

			if (event.all_day) {
				eventData.allDay = true;
			}

			individualCalendar.createEvent(eventData);

			const icsContent = individualCalendar.toString();
			const base64Ics = Buffer.from(icsContent, 'utf8').toString('base64');
			const icsDataUri = `data:text/calendar;charset=utf-8;base64,${base64Ics}`;

			const titleContent = event.url
				? `<a href="${event.url}" title="Lisätietoja" target="_blank" style="text-decoration: none; color: black;">${event.title}${event.location ? ` <span style="font-weight: normal;">| ${event.location}</span>` : ''}</a>`
				: `${event.title}${event.location ? ` <span style="font-weight: normal;">| ${event.location}</span>` : ''}`;
			html += `<div class="event">
<div class="date-column">${dateStr}</div>
<div class="details-column">
<h2>${titleContent}</h2>
				${qrCodeDataUri ? `<a href="${baseUrl}/events/${event.id}.html" class="qrcode" title="Lisää kalenteriin" target="_blank" style="color: black; text-decoration: none; float: right; margin-left: 10px; flex-direction: column; align-items: center;"><div style="position: relative; width: 100px; height: 100px;"><img src="${qrCodeDataUri}" alt="QR-koodi kalenteriin" style="width: 100px; height: 100px;"/><img src="/calendar-icon.svg" alt="" style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 24px; height: 24px; background-color: white; padding: 2px; border-radius: 2px;"/></div></a>` : ''}
<p>${event.description || ''}</p>
<p class="readmore"><a href="${icsDataUri}" target="_blank">Lisää kalenteriin</a>${event.url ? ` | <a href="${event.url}" target="_blank">Lue lisää&hellip;</a>` : ''}</p>
</div>
</div>
`;
		}
		html += `</div>`;
	}

	html += `</div>
</body>
</html>`;

	writeStaticFile('kalenteri.html', html);
	console.log('Generated kalenteri.html with', events.length, 'events');
}

async function downloadEventImages(events) {
	const imageUrls = new Map();
	for (const event of events) {
		if (!event.image) {
			continue;
		}
		try {
			const imageUrl = `${pocketBaseUrl}/api/files/events/${event.id}/${event.image}`;
			const response = await fetch(imageUrl);
			if (!response.ok) {
				console.warn(`Failed to download image for event ${event.id}: ${response.status}`);
				continue;
			}
			const buffer = Buffer.from(await response.arrayBuffer());
			const relativePath = `images/${event.id}_${event.image}`;
			writeStaticFile(relativePath, buffer);
			imageUrls.set(event.id, `/images/${event.id}_${event.image}`);
		} catch (error) {
			console.warn(`Failed to download image for event ${event.id}:`, error.message);
		}
	}
	return imageUrls;
}

async function generateFeeds(events) {
	const imageUrls = await downloadEventImages(events);

	// Generate individual ICS files for each event
	const eventIcsDataUris = new Map();
	const eventIcsContents = new Map();
	for (const event of events) {
		const individualCalendar = ical({
			title: 'Palikkakalenteri',
			description: 'Suomen Palikkayhteisö ry:n Palikkakalenteri',
			timezone: 'Europe/Helsinki'
		});

		const startDate = toHelsinkiDate(event.start_date);
		let endDate = event.end_date
			? toHelsinkiDate(event.end_date)
			: new Date(startDate.getTime() + (event.all_day ? 24 * 60 * 60 * 1000 : 60 * 60 * 1000));

		if (event.all_day) {
			endDate = new Date(endDate.getTime() + 24 * 60 * 60 * 1000);
		}
		const description = event.description || event.title;
		const eventUrl = event.url;

		const eventData = {
			id: `${baseUrl}/#/events/${event.id}`,
			start: startDate,
			end: endDate,
			summary: event.title,
			description,
			...(eventUrl && { url: eventUrl }),
			timezone: 'Europe/Helsinki'
		};

		// Set location data
		if (event.location) {
			const loc = { title: event.location };
			if (event.point && event.point.lat !== 0 && event.point.lon !== 0) {
				loc.geo = { lat: event.point.lat, lon: event.point.lon };
			}
			eventData.location = loc;
		}

		if (event.all_day) {
			eventData.allDay = true;
		}

		individualCalendar.createEvent(eventData);

		const icsContent = individualCalendar.toString();
		writeStaticFile(`events/${event.id}.ics`, icsContent);

		eventIcsContents.set(event.id, icsContent);

		// Create data URI for enclosure
		const base64Ics = Buffer.from(icsContent, 'utf8').toString('base64');
		const dataUri = `data:text/calendar;charset=utf-8;base64,${base64Ics}`;
		eventIcsDataUris.set(event.id, dataUri);

		// Generate HTML file for the event
		const eventHtml = `<!DOCTYPE html>
<html lang="fi">
<head>
<meta charset="UTF-8">
<title>${event.title} - Palikkakalenteri</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body { font-family: Arial, sans-serif; margin: 20px; text-align: center; }
h1 { color: #333; }
p { margin: 20px 0; }
a { display: inline-block; padding: 12px 24px; background-color: #007bff; color: white; text-decoration: none; border-radius: 4px; }
a:hover { background-color: #0056b3; }
</style>
</head>
<body>
<h1>${event.title}</h1>
<p>${event.location ? `${event.location}<br>` : ''}${formatEventDisplayDate(event)}</p>
<p>${event.description || ''}</p>
<p><a href="${event.id}.ics">Lisää kalenteriin</a></p>
</body>
</html>`;
		writeStaticFile(`events/${event.id}.html`, eventHtml);
	}

	const feed = new Feed({
		title: 'Palikkakalenteri',
		description: 'Suomen Palikkayhteisö ry:n Palikkakalenteri',
		id: 'https://kalenteri.palikkaharrastajat.fi/',
		link: 'https://kalenteri.palikkaharrastajat.fi/',
		language: 'fi',
		image: 'https://kalenteri.palikkaharrastajat.fi/logo.png',
		favicon: 'https://kalenteri.palikkaharrastajat.fi/favicon.ico',
		copyright: 'Suomen Palikkayhteisö ry',
		updated: new Date(),
		generator: 'Emmet',
		feedLinks: {
			rss: 'https://kalenteri.palikkaharrastajat.fi/kalenteri.rss',
			atom: 'https://kalenteri.palikkaharrastajat.fi/kalenteri.atom'
		},
		author: {
			name: 'Suomen Palikkayhteisö ry',
			email: 'palikkaharrastajatry@outlook.com',
			link: 'https://palikkaharrastajat.fi/'
		}
	});

	events.forEach((event) => {
		const dateStr = formatEventDisplayDate(event);
		const description = event.description || event.title;
		const content = `${description}\n\n${dateStr}`;
		const eventUrl = event.url;

		const feedItem = {
			title:
				`${event.all_day ? dateStr : formatDateInHelsinki(event.start_date, true)} ${event.title}` +
				(event.location ? ` | ${event.location}` : ''),
			id: `${baseUrl}/#/events/${event.id}`,
			...(eventUrl && { link: eventUrl }),
			description: content,
			date: new Date(event.updated),
			published: new Date(event.created),
			author: [
				{
					name: 'Suomen Palikkayhteisö ry'
				}
			]
		};

		const imageUrl = imageUrls.get(event.id);
		if (imageUrl) {
			feedItem.image = `https://kalenteri.palikkaharrastajat.fi${imageUrl}`;
		}

		// Add ICS enclosure
		const icsDataUri = eventIcsDataUris.get(event.id);
		if (icsDataUri) {
			const icsFilePath = path.join('static', `events/${event.id}.ics`);
			const length = fs.existsSync(icsFilePath) ? fs.statSync(icsFilePath).size : 0;
			feedItem.enclosure = {
				url: `${baseUrl}/events/${event.id}.ics`,
				type: 'text/calendar',
				length
			};
		}

		feed.addItem(feedItem);
	});

	const rss = feed.rss2();
	writeStaticFile('kalenteri.rss', rss);
	let atom = feed.atom1();
	// Postprocess Atom feed to fix incorrect enclosure type for ICS files
	atom = atom.replace(/type="image\/ics"/g, 'type="text/calendar"');
	writeStaticFile('kalenteri.atom', atom);
	const jsonfeed = feed.json1();
	writeStaticFile('kalenteri.json', jsonfeed);

	const geojson = {
		type: 'FeatureCollection',
		features: events
			.filter((event) => event.point && event.point.lat !== 0 && event.point.lon !== 0)
			.map((event) => ({
				type: 'Feature',
				geometry: {
					type: 'Point',
					coordinates: [event.point.lon, event.point.lat]
				},
				properties: {
					title: event.title,
					description: event.description || event.title,
					start: event.start_date,
					end: event.end_date,
					all_day: event.all_day,
					location: event.location,
					...(event.url && { url: event.url }),
					ics: eventIcsContents.get(event.id),
					id: event.id
				}
			}))
	};
	writeStaticFile('kalenteri.geo.json', JSON.stringify(geojson, null, 2));

	const calendar = ical({
		title: 'Palikkakalenteri',
		description: 'Suomen Palikkayhteisö ry:n Palikkakalenteri',
		timezone: 'Europe/Helsinki'
	});

	for (const event of events) {
		const startDate = toHelsinkiDate(event.start_date);
		let endDate = event.end_date
			? toHelsinkiDate(event.end_date)
			: new Date(startDate.getTime() + (event.all_day ? 24 * 60 * 60 * 1000 : 60 * 60 * 1000));

		if (event.all_day) {
			endDate = new Date(endDate.getTime() + 24 * 60 * 60 * 1000);
		}
		const description = event.description || event.title;
		const eventUrl = event.url;

		const eventData = {
			id: `${baseUrl}/#/events/${event.id}`,
			start: startDate,
			end: endDate,
			summary:
				event.all_day && event.location
					? `${event.title} | ${event.location.split(',')[0].trim()}`
					: event.title,
			description,
			...(eventUrl && { url: eventUrl }),
			timezone: 'Europe/Helsinki'
		};

		// Set location data
		if (event.location) {
			const loc = { title: event.location };
			if (event.point && event.point.lat !== 0 && event.point.lon !== 0) {
				loc.geo = { lat: event.point.lat, lon: event.point.lon };
			}
			eventData.location = loc;
		}

		if (event.all_day) {
			eventData.allDay = true;
		}

		calendar.createEvent(eventData);
	}

	const ics = calendar.toString();
	writeStaticFile('kalenteri.ics', ics);

	console.log(
		'Generated kalenteri.rss, kalenteri.atom, kalenteri.json, kalenteri.geo.json, kalenteri.ics and individual event ICS files'
	);
}

async function generateStatics() {
	const pb = createPocketBaseClient();
	const events = await fetchPublishedEvents(pb);
	await generateEmbed(events);
	await generateFeeds(events);
	console.log('Completed static generation for', events.length, 'events');
}

generateStatics().catch((error) => {
	console.error('Failed to generate static outputs:', error);
	process.exit(1);
});
