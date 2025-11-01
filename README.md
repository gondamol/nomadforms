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

## 📦 Installation

_Coming soon - project is in active development_

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
