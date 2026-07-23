# NomadForms

> Open-source, offline-capable survey platform for field research in Low and Middle Income Countries

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Status: Development](https://img.shields.io/badge/Status-Development-orange.svg)](https://github.com/gondamol/nomadforms)

## 🌍 Vision

Create a survey platform that rivals REDCap and SurveyCTO while being:
- **Open Source**: Free forever, MIT licensed
- **Offline-First**: Works 7+ days without internet
- **Mobile-Ready**: Optimized for tablets and phones
- **LMIC-Friendly**: Low bandwidth, budget devices, multi-language

## 🎯 Key Features (Planned)

### For Field Workers
- 📱 Mobile app (Progressive Web App)
- 🔌 Offline data collection (7+ days)
- 📸 Camera, GPS, QR code integration
- 🌐 Multi-language interface

### For Researchers
- 🎨 Visual survey builder (no coding required)
- 📊 Export to Stata, SPSS, R, Excel, CSV (with labels)
- 📝 Import REDCap codebooks
- 🔄 Skip logic and calculated fields

### For Organizations
- 🏠 Self-hostable
- 🔒 Secure (encryption, audit trails)
- 💾 PostgreSQL backend (Supabase supported)
- 🆓 Cost-effective (<$30/month or free)

## 🏗️ Architecture

Built on [surveydown](https://surveydown.org) foundation:

```
Visual Builder (React) → Generates Code (Quarto + R)
                              ↓
                    Shiny App + PWA (offline)
                              ↓
              IndexedDB (local) + PostgreSQL (cloud)
                              ↓
                    Rich Exports (Stata, SPSS, R)
```

## 🚀 Current Status

**Phase**: Active Development 🔨

- [x] Architecture design
- [x] Technical specifications
- [ ] Core survey engine (in progress)
- [ ] Visual builder
- [ ] Offline capabilities
- [ ] Mobile optimization

## 🛠️ Tech Stack

**Backend**: R, Quarto, Shiny, PostgreSQL  
**Frontend**: React, TypeScript  
**Mobile**: Progressive Web App (PWA)  
**Database**: PostgreSQL (Supabase or self-hosted)

## 📦 Quick Start (one command)

Requires Docker. Brings up PostgreSQL + the API and runs migrations
automatically.

```bash
git clone https://github.com/gondamol/nomadforms.git
cd nomadforms
docker compose up --build

# optional: create a demo survey to collect against
./database/seed.sh
```

Then open:

- **Mobile collect app:** http://localhost:8000/app/
- **From a phone on the same Wi-Fi:** `http://<your-computer-ip>:8000/app/`
- **API docs (Swagger):** http://localhost:8000/__docs__/

For production, copy `.env.example` to `.env`, set a strong `DB_PASSWORD`,
set `API_KEY` to require auth on writes, and set `CORS_ORIGIN`.

**See** `FINAL_REPORT.md` for exactly what works, `DECISIONS.md` for the
architecture rationale, and `TESTING.md` for mobile testing.

### Current Features

✅ **Working now** (verified end-to-end):
- Mobile PWA data collection: offline-first, auto-save, resume draft, GPS,
  14 question types, idempotent sync
- REST API: surveys, submit, batch sync, list (search/filter/paginate),
  analytics, approve/reject/delete/restore with audit log
- Export: CSV and JSON over HTTP
- PostgreSQL with a single canonical data model (`submissions` + `answers` view)
- One-command Docker deployment, OpenAPI docs, CI (R tests + API e2e)

⏸️ **Not yet built** (see `FINAL_REPORT.md` for the full list):
- Visual (drag-and-drop) survey builder — surveys are authored via the API
- User accounts and role enforcement
- Charts/maps dashboard UI; Stata/SPSS/Excel/PDF export over HTTP
- Photo/video/audio/signature capture in the collect page

## 🤝 Contributing

We welcome contributions! This project is in early development.

Interested in:
- **Beta Testing**: Try early versions
- **Development**: R/Shiny, React/TypeScript, PostgreSQL
- **Documentation**: Translations, tutorials
- **Funding**: Support development

Contact: [your-email@example.com]

## 📖 Documentation

_Documentation will be added as features are implemented_

## 🎓 Based On

Built on [surveydown](https://github.com/surveydown-dev/surveydown) by Pingfan Hu, Bogdan Bunea, and John Paul Helveston.

> Hu P, Bunea B, Helveston J (2025). "surveydown: An open-source, markdown-based platform for programmable and reproducible surveys." PLOS One, 20(8). doi:10.1371/journal.pone.0331002

## 📄 License

MIT License - see LICENSE file for details

## 🔗 Links

- **GitHub**: https://github.com/gondamol/nomadforms
- **Surveydown**: https://surveydown.org

---

**Status**: 🔨 Active Development  
**Next Milestone**: Core survey engine  
**Target Launch**: Q4 2026

---

_Mobile-first surveys for researchers on the move_ 📱🌍
