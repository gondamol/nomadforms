#!/usr/bin/env bash
# Seed a demo survey so the app has something to collect against on first run.
# Usage: API=http://localhost:8000 ./database/seed.sh
set -euo pipefail
API="${API:-http://localhost:8000}"

echo "Seeding demo survey to $API ..."
curl -sf -X POST "$API/api/surveys" \
  -H 'Content-Type: application/json' \
  ${API_KEY:+-H "X-API-Key: $API_KEY"} \
  -d '{
    "title": "Household Nutrition — Turkana Pilot",
    "description": "Demo survey for NomadForms field collection",
    "questions": [
      { "id": "intro", "type": "note", "label": "Thank you for participating. This takes about 5 minutes." },
      { "id": "hh_head", "type": "text", "label": "Household head name", "required": true },
      { "id": "county", "type": "select", "label": "County", "required": true,
        "options": ["Turkana", "Marsabit", "Samburu", "Wajir"] },
      { "id": "children_u5", "type": "integer", "label": "Number of children under 5", "required": true },
      { "id": "water_source", "type": "radio", "label": "Main water source",
        "options": ["Piped", "Borehole", "River", "Vendor"] },
      { "id": "services", "type": "multi_select", "label": "Services accessed this month",
        "options": ["Health clinic", "Food aid", "Cash transfer", "None"] },
      { "id": "consent", "type": "yes_no", "label": "Consent to follow-up visit?", "required": true },
      { "id": "gps", "type": "gps", "label": "Household GPS location" },
      { "id": "notes", "type": "textarea", "label": "Enumerator notes" }
    ]
  }' | grep -o '"survey_id":"[^"]*"' | cut -d'"' -f4 | \
  xargs -I{} echo "Created survey {} — open ${API}/app/collect.html?survey={}"
