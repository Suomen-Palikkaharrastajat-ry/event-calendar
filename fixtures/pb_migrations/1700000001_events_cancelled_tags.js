/// <reference path="../pb_data/types.d.ts" />
// Fields the app reads and writes that the initial schema lacks
// (production has them: `cancelled` since 708ed0b, `tags` as a JSON array).
migrate((app) => {
  const events = app.findCollectionByNameOrId("events")
  events.fields.add(new BoolField({ name: "cancelled" }))
  events.fields.add(new JSONField({ name: "tags", maxSize: 0 }))
  app.save(events)
}, (app) => {
  const events = app.findCollectionByNameOrId("events")
  events.fields.removeByName("cancelled")
  events.fields.removeByName("tags")
  app.save(events)
})
